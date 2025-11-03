require 'rails_helper'

RSpec.describe Rag::AnswerGenerator do
  let(:question) { "What is the capital of France?" }
  let(:mock_llm_response) { double("Response", content: "Paris is the capital of France [1].") }
  let(:mock_chat) { double("Chat", ask: mock_llm_response) }

  before do
    # Stub RubyLLM Client
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
  end

  describe ".generate" do
    context "when chunks are found" do
      let(:document) { build(:document, id: 1, title: "Geography Facts") }
      let(:chunk) { build(:chunk, id: 1, content: "Paris is the capital of France.", position: 0) }

      let(:chunks_data) do
        [
          {
            chunk: chunk,
            document: document,
            content: chunk.content,
            distance: 0.1,
            position: chunk.position
          }
        ]
      end

      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
        allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      end

      it "returns a hash with answer" do
        result = described_class.generate(question)

        expect(result).to be_a(Hash)
        expect(result[:answer]).to eq("Paris is the capital of France [1].")
      end

      it "includes citations in response with full metadata" do
        result = described_class.generate(question)

        expect(result[:citations]).to be_an(Array)
        expect(result[:citations].first).to include(
          chunk_id: 1,
          document_id: 1,
          document_title: "Geography Facts",
          position: 0
        )
        expect(result[:citations].first[:relevance]).to be_a(Float)
      end

      it "includes model used" do
        result = described_class.generate(question)

        # Uses test environment model from config
        expect(result[:model]).to eq("test-chat-model")
      end

      it "calls ChunkRetriever with correct parameters" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          limit: 3,
          document_ids: nil,
          created_after: nil
        )

        described_class.generate(question)
      end

      it "calls PromptBuilder with chunks" do
        expect(Rag::PromptBuilder).to receive(:build).with(question, chunks_data)

        described_class.generate(question)
      end

      it "calls LLM with the built prompt" do
        expect(RubyLLM).to receive(:chat).with(
          model: "test-chat-model",
          provider: :test
        ).and_return(mock_chat)

        expect(mock_chat).to receive(:ask).with("Mock prompt")

        described_class.generate(question)
      end
    end

    context "with custom options" do
      let(:document) { build(:document, id: 1, title: "Test Doc") }
      let(:chunk) { build(:chunk, id: 1, content: "Test content", position: 0) }
      let(:chunks_data) do
        [{
          chunk: chunk,
          document: document,
          content: chunk.content,
          distance: 0.1,
          position: chunk.position
        }]
      end

      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
        allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      end

      it "respects custom limit" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(limit: 10)
        )

        described_class.generate(question, limit: 10)
      end

      it "respects custom distance_threshold" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(distance_threshold: 0.5)
        )

        described_class.generate(question, distance_threshold: 0.5)
      end

      it "respects custom document_ids" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(document_ids: [1, 2, 3])
        )

        described_class.generate(question, document_ids: [1, 2, 3])
      end

      it "respects custom created_after" do
        created_after_date = 7.days.ago
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(created_after: created_after_date)
        )

        described_class.generate(question, created_after: created_after_date)
      end

      it "respects custom model" do
        expect(RubyLLM).to receive(:chat).with(
          hash_including(model: "claude-3-opus-latest")
        ).and_return(mock_chat)

        described_class.generate(question, model: "claude-3-opus-latest")
      end
    end

    context "when no chunks are found" do
      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return([])
      end

      it "returns default message without calling LLM" do
        result = described_class.generate(question)

        expect(result[:answer]).to eq("I don't have enough information in the provided documents to answer your question.")
      end

      it "has empty citations" do
        result = described_class.generate(question)

        expect(result[:citations]).to eq([])
      end

      it "does not call PromptBuilder" do
        expect(Rag::PromptBuilder).not_to receive(:build)

        described_class.generate(question)
      end

      it "does not call LLM" do
        expect(RubyLLM).not_to receive(:chat)

        described_class.generate(question)
      end
    end

    context "when LLM call fails" do
      let(:document) { build(:document, id: 1, title: "Test Doc") }
      let(:chunk) { build(:chunk, id: 1, content: "Test content", position: 0) }
      let(:chunks_data) do
        [{
          chunk: chunk,
          document: document,
          content: chunk.content,
          distance: 0.1,
          position: chunk.position
        }]
      end

      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
        allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
        allow(RubyLLM).to receive(:chat).and_raise(StandardError.new("API Error"))
      end

      it "returns error response" do
        result = described_class.generate(question)

        expect(result[:answer]).to include("error")
        expect(result[:error]).to be_present
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        described_class.generate(question)
      end

      it "includes error message" do
        result = described_class.generate(question)

        expect(result[:error]).to include("API Error")
      end
    end

    context "when retrieval fails" do
      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_raise(StandardError.new("Retrieval failed"))
      end

      it "returns error response" do
        result = described_class.generate(question)

        expect(result[:answer]).to include("error")
        expect(result[:error]).to be_present
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        described_class.generate(question)
      end
    end
  end

  describe "#generate" do
    let(:generator) { described_class.new }

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return([])
    end

    it "can be instantiated and called as an instance method" do
      result = generator.generate(question)

      expect(result).to be_a(Hash)
      expect(result[:answer]).to be_present
    end
  end

  describe "citations formatting" do
    let(:document1) { build(:document, id: 1, title: "Doc 1") }
    let(:document2) { build(:document, id: 2, title: "Doc 2") }
    let(:chunk1) { build(:chunk, id: 10, content: "Content 1", position: 0) }
    let(:chunk2) { build(:chunk, id: 20, content: "Content 2", position: 1) }
    let(:mock_llm_response_with_two_citations) { double("Response", content: "Answer using both sources [1][2].") }
    let(:mock_chat_with_two_citations) { double("Chat", ask: mock_llm_response_with_two_citations) }

    let(:chunks_data) do
      [
        { chunk: chunk1, document: document1, content: chunk1.content, distance: 0.1, position: 0 },
        { chunk: chunk2, document: document2, content: chunk2.content, distance: 0.2, position: 1 }
      ]
    end

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
      allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      allow(RubyLLM).to receive(:chat).and_return(mock_chat_with_two_citations)
    end

    it "includes all citations with complete metadata" do
      result = described_class.generate(question)

      expect(result[:citations].length).to eq(2)
      expect(result[:citations][0]).to include(
        chunk_id: 10,
        document_id: 1,
        document_title: "Doc 1",
        position: 0
      )
      expect(result[:citations][1]).to include(
        chunk_id: 20,
        document_id: 2,
        document_title: "Doc 2",
        position: 1
      )
    end

    it "includes relevance scores calculated from distance" do
      result = described_class.generate(question)

      # Distance 0.1 should convert to relevance ~0.95 (1 - 0.1/2)
      expect(result[:citations][0][:relevance]).to be_within(0.01).of(0.95)
      # Distance 0.2 should convert to relevance ~0.90 (1 - 0.2/2)
      expect(result[:citations][1][:relevance]).to be_within(0.01).of(0.90)
    end
  end

  describe "citation renumbering" do
    let(:document1) { build(:document, id: 1, title: "Doc 1") }
    let(:document2) { build(:document, id: 2, title: "Doc 2") }
    let(:document3) { build(:document, id: 3, title: "Doc 3") }
    let(:chunk1) { build(:chunk, id: 10, content: "Content 1", position: 0) }
    let(:chunk2) { build(:chunk, id: 20, content: "Content 2", position: 1) }
    let(:chunk3) { build(:chunk, id: 30, content: "Content 3", position: 2) }

    # LLM only cites [2] and [3], skipping [1]
    let(:mock_llm_response_sparse) { double("Response", content: "Answer from sources [2] and [3].") }
    let(:mock_chat_sparse) { double("Chat", ask: mock_llm_response_sparse) }

    let(:chunks_data) do
      [
        { chunk: chunk1, document: document1, content: chunk1.content, distance: 0.1, position: 0 },
        { chunk: chunk2, document: document2, content: chunk2.content, distance: 0.2, position: 1 },
        { chunk: chunk3, document: document3, content: chunk3.content, distance: 0.3, position: 2 }
      ]
    end

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
      allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      allow(RubyLLM).to receive(:chat).and_return(mock_chat_sparse)
    end

    it "renumbers citations sequentially when LLM skips some" do
      result = described_class.generate(question)

      # Should only include citations [2] and [3] from the original prompt
      expect(result[:citations].length).to eq(2)
      expect(result[:citations][0][:chunk_id]).to eq(20) # Original [2]
      expect(result[:citations][1][:chunk_id]).to eq(30) # Original [3]

      # Answer should be renumbered to [1] and [2]
      expect(result[:answer]).to eq("Answer from sources [1] and [2].")
    end
  end

  describe "citations with nil document" do
    let(:chunk) { build(:chunk, id: 1, content: "Content", position: 0) }
    let(:mock_llm_response_nil_doc) { double("Response", content: "Answer from unknown source [1].") }
    let(:mock_chat_nil_doc) { double("Chat", ask: mock_llm_response_nil_doc) }
    let(:chunks_data) do
      [
        { chunk: chunk, document: nil, content: chunk.content, distance: 0.1, position: 0 }
      ]
    end

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
      allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      allow(RubyLLM).to receive(:chat).and_return(mock_chat_nil_doc)
    end

    it "handles nil document gracefully" do
      result = described_class.generate(question)

      expect(result[:citations].first).to include(
        chunk_id: 1,
        document_id: nil,
        document_title: "Unknown Document",
        position: 0
      )
    end
  end
end
