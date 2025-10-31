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
      return build_no_context_prompt(question) if chunks_data.empty?

      context = format_context(chunks_data)
      build_rag_prompt(question, context)
    end

    private

    def build_no_context_prompt(question)
      <<~PROMPT
        You are a helpful assistant. The user has asked a question, but no relevant documents were found to answer it.

        Question: #{question}

        Please let the user know that you don't have enough information in the provided documents to answer their question.
      PROMPT
    end

    def build_rag_prompt(question, context)
      <<~PROMPT
        You are a helpful assistant answering questions based on provided document excerpts.

        Context from documents:
        #{context}

        Question: #{question}

        Instructions:
        - Provide a clear, concise answer based ONLY on the context above
        - If the answer is not fully contained in the context, say so explicitly
        - Cite which documents you used by mentioning the document titles
        - If multiple documents provide relevant information, synthesize them in your answer
        - Be direct and factual

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
