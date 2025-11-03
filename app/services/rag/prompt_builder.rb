module Rag
  class PromptBuilder
    # Build a prompt for answering a question based on retrieved chunks
    # @param question [String] the user's question
    # @param chunks_data [Array<Hash>] array of hashes with :chunk, :document, :content, :distance keys
    # @return [String] the formatted prompt
    def self.build(question, chunks_data)
      new.build(question, chunks_data)
    end

    def build(question, chunks_data)
      # Note: Empty chunks_data is now handled in AnswerGenerator
      # This method assumes chunks_data is not empty
      context = format_context(chunks_data)
      build_rag_prompt(question, context)
    end

    private

    def build_rag_prompt(question, context)
      <<~PROMPT
        You are a helpful assistant answering questions based on provided document excerpts.

        Context from documents:
        #{context}

        Question: #{question}

        CRITICAL INSTRUCTIONS for answering:

        1. VERIFY BEFORE CITING: Before citing any source, verify it contains information that DIRECTLY answers the question asked. A chunk is only relevant if it addresses the specific question, not just related topics.

        2. READ CAREFULLY: Just because a chunk mentions words from the question doesn't mean it answers the question. Check if the chunk actually provides the answer.

        3. CITE ONLY WHAT YOU USE: Only include citation numbers [1], [2], etc. for chunks you actually quote or reference in your answer. If a chunk is irrelevant, skip it completely.

        4. BE STRICT: If no chunks clearly answer the question, respond with: "I don't have enough information to answer this question based on the provided documents."

        5. USE DIRECT QUOTES: When possible, quote directly from relevant chunks rather than paraphrasing.

        6. NO SPECULATION: Do not make inferences or connections that aren't explicitly stated in the chunks.

        7. BE CONCISE: Keep your answer focused on the question asked.

        Answer:
      PROMPT
    end

    def format_context(chunks_data)
      chunks_data.map.with_index do |chunk_info, index|
        chunk = chunk_info[:chunk]
        document = chunk_info[:document]
        distance = chunk_info[:distance]

        doc_title = document&.title || "Unknown Document"

        # Format: [1] Document Title (relevance: 0.XX)
        # Content here...
        header = "[#{index + 1}] #{doc_title}"
        header += " (relevance: #{format_relevance(distance)})" if distance

        <<~CHUNK.strip
          #{header}
          #{chunk.content}
        CHUNK
      end.join("\n\n---\n\n")
    end

    def format_relevance(distance)
      # Convert cosine distance to a 0-1 similarity score
      # Distance of 0 = perfect match (similarity 1.0)
      # Distance of 2 = completely opposite (similarity 0.0)
      similarity = [0, 1 - (distance / 2.0)].max
      format("%.2f", similarity)
    end
  end
end
