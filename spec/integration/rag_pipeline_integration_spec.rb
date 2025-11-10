require 'rails_helper'

RSpec.describe "RAG Pipeline Integration", type: :integration do
  let(:tracy_document_content) do
    <<~TEXT
      Tracy Atteberry is a senior software engineer with expertise in Ruby on Rails and JavaScript.
      He has been working at BenchPrep for 4 years, where he leads the web development team.
      Tracy specializes in building scalable web applications and has extensive experience with React and Vue.js.
      His technical skills include Ruby, Ruby on Rails, JavaScript, Vue, Python, PostgreSQL, and Docker.
      He has experience with AI development and machine learning integration.
      Before BenchPrep, Tracy worked at Groupon and Oracle in senior engineering roles.
      He graduated from University of Kansas with degrees in Mathematics and Computer Science.
    TEXT
  end

  let(:readme_document_content) do
    <<~TEXT
      # Ragtime - Document Q&A System

      Ragtime is a Retrieval-Augmented Generation (RAG) system built with Rails 8 and Vue.js.
      Users can upload documents (PDF, TXT, DOCX, MD) and ask questions about their content.

      ## Features
      - Document upload and processing
      - Vector search using sqlite-vec
      - Question answering with citations
      - Interactive document navigation

      ## Technology Stack
      - Backend: Rails 8 API
      - Database: SQLite with vector extensions
      - Frontend: Vue.js 3
      - LLM Chat: OpenAI gpt-4o-mini
      - LLM Embeddings: OpenAI text-embedding-3-small
    TEXT
  end

  let(:doomsday_document_content) do
    <<~TEXT
      The Doomsday Argument is a probabilistic argument that claims to predict the future longevity of the human species.

      According to the argument, if humanity were to exist for millions of years, then we would be exceptionally early members of the human species.
      The probability of being born at this particular point in human history would be very low.

      However, if humanity is likely to go extinct relatively soon, then we would be born at a typical time in human history.
      The argument suggests that this makes our current position more probable.

      Critics argue that the Doomsday Argument makes questionable assumptions about human population growth and survival probabilities.
    TEXT
  end

  let(:tracy_document) do
    create(:document, :completed,
      title: "Tracy Resume",
      filename: "tracy_resume.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
  end

  let(:readme_document) do
    create(:document, :completed,
      title: "Ragtime README",
      filename: "README.md",
      content_type: "text/markdown"
    )
  end

  let(:doomsday_document) do
    create(:document, :completed,
      title: "Doomsday Argument",
      filename: "doomsday.pdf",
      content_type: "application/pdf"
    )
  end

  def create_chunks_for_document(document, content)
    # Split content into reasonable chunks
    sentences = content.split(/[.!?]+/).map(&:strip).reject(&:empty?)
    chunks = []

    sentences.each_slice(2).with_index do |sentence_group, index|
      chunk_content = sentence_group.join('. ') + '.'

      # Create predictable embeddings for testing
      # Use document ID and position to create consistent vectors
      seed = document.id * 1000 + index
      embedding = Array.new(512) { |i| Math.sin(seed + i) }

      chunks << create(:chunk,
        document: document,
        content: chunk_content,
        position: index,
        token_count: chunk_content.split.length, # rough token count
        embedding: embedding
      )
    end

    chunks
  end

  describe "Complete RAG Pipeline Flow" do
    context "with test documents and chunks" do
      before do
        # Create test documents with chunks that have embeddings
        create_chunks_for_document(tracy_document, tracy_document_content)
        create_chunks_for_document(readme_document, readme_document_content)
        create_chunks_for_document(doomsday_document, doomsday_document_content)
      end

      it "processes query through complete pipeline successfully" do
        # Test the pipeline flow with a query that should work
        query = "What information is available?"

        # Step 1: ChunkRetriever should execute without errors
        retriever = Rag::ChunkRetriever.new
        chunks_data = retriever.retrieve(query, limit: 3)

        # Should return some chunks (even if not perfectly matched)
        expect(chunks_data).to be_an(Array)

        # Step 2: PromptBuilder should construct proper prompt
        prompt = Rag::PromptBuilder.build(query, chunks_data)

        expect(prompt).to include(query)
        expect(prompt).to include("Context from documents:")
        expect(prompt).to include("CRITICAL INSTRUCTIONS")
        expect(prompt).to include("Answer:")

        # Step 3: AnswerGenerator should produce response (either with info or empty context)
        result = Rag::AnswerGenerator.generate(query)

        expect(result).to be_a(Hash)
        expect(result[:answer]).to be_present
        expect(result[:answer]).not_to be_empty
        expect(result[:citations]).to be_an(Array)
        expect(result[:model]).to be_present

        # Should either have useful information or empty context
        if result[:empty_context].present?
          expect(result[:answer]).to include("don't have enough information")
          expect(result[:citations]).to be_empty
        else
          # If it found relevant chunks, should have citations
          expect(result[:citations]).not_to be_empty if chunks_data.any?
        end
      end

      it "handles queries about different document types correctly" do
        # Test with different queries to ensure the pipeline processes them
        query = "Tell me about the Doomsday argument"

        result = Rag::AnswerGenerator.generate(query)

        expect(result[:answer]).to be_present
        expect(result[:answer]).not_to be_empty
        expect(result[:citations]).to be_an(Array)
        expect(result).to have_key(:model)

        # The response should be either meaningful or empty context
        expect(result[:answer]).to respond_to(:length)
      end

      it "returns empty context for queries with no relevant information" do
        query = "What is the capital of France?"

        result = Rag::AnswerGenerator.generate(query)

        expect(result[:answer]).to include("don't have enough information")
        expect(result[:citations]).to be_empty
        expect(result[:empty_context]).to be_present
        expect(result[:empty_context][:type]).to eq(:no_relevant_chunks)
      end

      it "maintains citation relevance scores" do
        query = "Tell me about Tracy's work experience"

        result = Rag::AnswerGenerator.generate(query)

        if result[:citations].any?
          result[:citations].each do |citation|
            expect(citation[:relevance]).to be_between(0.0, 1.0)
          end
        end
      end
    end

    context "with date filtering" do
      before do
        # Create documents for date filtering tests
        create_chunks_for_document(tracy_document, tracy_document_content)
        create_chunks_for_document(readme_document, readme_document_content)
      end

      it "filters documents by creation date throughout pipeline" do
        skip "Date filtering test - requires control over document timestamps"
        # Note: This test would require creating documents with specific timestamps
        # which is complex with existing test data. This can be added later if needed.
      end

      it "returns no recent documents message when date filter excludes all documents" do
        # Use future date to exclude all existing documents
        future_date = 1.day.from_now
        query = "Does Tracy know Ruby?"

        result = Rag::AnswerGenerator.generate(query, created_after: future_date)

        expect(result[:answer]).to include("No documents found in the selected date range. Try expanding your search to include older documents.")
        expect(result[:citations]).to be_empty
        expect(result[:empty_context]).to be_present
        expect(result[:empty_context][:type]).to eq(:no_recent_documents)
      end
    end

    context "with different file formats" do
      it "processes markdown files through complete pipeline" do
        skip "Markdown test - requires control over document creation"
        # Note: We have a README.md file that we could test with
        # but we need to ensure it has the right content for testing
      end
    end

    context "error handling" do
      it "handles empty document database gracefully" do
        # Temporarily remove all documents
        original_documents = Document.all.to_a
        Document.delete_all

        query = "What is software development?"

        result = Rag::AnswerGenerator.generate(query)

        expect(result[:answer]).to include("No documents have been uploaded yet")
        expect(result[:citations]).to be_empty
        expect(result[:empty_context]).to be_present
        expect(result[:empty_context][:type]).to eq(:no_documents)

        # Restore documents
        original_documents.each(&:save!)
      end
    end

    context "performance and reliability" do
      it "handles multiple sequential queries" do
        queries = [
          "Does Tracy know Ruby?",
          "What is Ragtime?",
          "Tell me about the Doomsday document"
        ]

        # Execute queries sequentially (more reliable for integration tests)
        results = []
        queries.each do |query|
          result = Rag::AnswerGenerator.generate(query)
          results << result
        end

        # All queries should complete successfully
        expect(results.length).to eq(3)
        results.each do |result|
          expect(result).to have_key(:answer)
          expect(result).to have_key(:citations)
          expect(result[:answer]).not_to be_empty
        end
      end

      it "processes queries within reasonable time" do
        query = "Tell me about Tracy's technical skills and experience"

        start_time = Time.current
        result = Rag::AnswerGenerator.generate(query)
        end_time = Time.current

        # Should complete within reasonable time for integration test
        expect(end_time - start_time).to be < 10.seconds
        expect(result[:answer]).not_to be_empty
      end
    end
  end

  describe "Chunk Retrieval Integration" do
    before do
      # Create test documents with chunks for retrieval testing
      create_chunks_for_document(tracy_document, tracy_document_content)
      create_chunks_for_document(readme_document, readme_document_content)
    end

    it "retrieves chunks with proper structure and calculations" do
      query = "software engineering"

      retriever = Rag::ChunkRetriever.new
      chunks_data = retriever.retrieve(query, limit: 3)

      # Should return an array (may be empty with test embeddings)
      expect(chunks_data).to be_an(Array)

      # If chunks are found, verify structure
      if chunks_data.any?
        chunks_data.each do |chunk_info|
          expect(chunk_info[:distance]).to be_between(0.0, 2.0)
          expect(chunk_info[:relevance]).to be_between(0.0, 1.0)
          expect(chunk_info[:content]).to be_present
          expect(chunk_info[:document]).to be_present
          expect(chunk_info[:chunk]).to be_present
        end
      end
    end

    it "respects retrieval limits" do
      query = "software"

      retriever = Rag::ChunkRetriever.new

      # Test different limits
      [1, 3, 5].each do |limit|
        chunks_data = retriever.retrieve(query, limit: limit)
        expect(chunks_data.length).to be <= limit
      end
    end
  end
end
