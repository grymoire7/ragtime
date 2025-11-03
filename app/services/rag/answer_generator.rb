module Rag
  class AnswerGenerator
    # Generate an answer to a question using RAG
    # @param question [String] the user's question
    # @param options [Hash] optional parameters
    # @option options [Integer] :limit number of chunks to retrieve (default: 3)
    # @option options [Float] :distance_threshold maximum distance for relevant chunks (default: 0.7 from ChunkRetriever)
    # @option options [Array<Integer>] :document_ids filter to specific documents
    # @option options [DateTime] :created_after filter to documents created after this date
    # @option options [String] :model the LLM model to use (default: claude-3-5-haiku-latest)
    # @return [Hash] with keys :answer, :citations, :model
    def self.generate(question, options = {})
      new.generate(question, options)
    end

    def generate(question, options = {})
      # Extract options with defaults
      # Use 3 chunks by default for more focused answers
      limit = options.fetch(:limit, 3)
      # Use ChunkRetriever's default threshold (0.7) for better quality
      # Only override if explicitly provided
      distance_threshold = options[:distance_threshold]
      document_ids = options[:document_ids]
      created_after = options[:created_after]

      # Use environment-specific model if not specified
      chat_config = Rails.application.config.x.ruby_llm[Rails.env.to_sym][:chat]
      model = options.fetch(:model, chat_config[:model])

      # Step 1: Retrieve relevant chunks
      retrieval_options = {
        limit: limit,
        document_ids: document_ids,
        created_after: created_after
      }
      # Only pass distance_threshold if explicitly provided, otherwise use ChunkRetriever's default
      retrieval_options[:distance_threshold] = distance_threshold if distance_threshold.present?

      chunks_data = ChunkRetriever.retrieve(question, **retrieval_options)

      # Step 2: If no chunks found, return default message without calling LLM
      if chunks_data.empty?
        return {
          answer: "I don't have enough information in the provided documents to answer your question.",
          citations: [],
          model: model
        }
      end

      # Step 3: Build prompt
      prompt = PromptBuilder.build(question, chunks_data)

      # Step 4: Generate answer using LLM
      answer = call_llm(prompt, model)

      # Step 5: Format citations with full metadata
      # Only include citations that were actually referenced in the answer
      all_citations = format_citations(chunks_data)
      used_citations, renumbered_answer = filter_and_renumber_citations(answer, all_citations)

      # Return structured response
      {
        answer: renumbered_answer,
        citations: used_citations,
        model: model
      }
    rescue => e
      Rails.logger.error("Failed to generate answer: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      {
        answer: "I'm sorry, I encountered an error while trying to answer your question. Please try again.",
        citations: [],
        model: model,
        error: e.message
      }
    end

    private

    def filter_and_renumber_citations(answer, all_citations)
      # Parse the answer for citation references like [1], [2], [3], etc.
      citation_numbers = answer.scan(/\[(\d+)\]/).flatten.map(&:to_i).uniq.sort

      # If no citations found in answer, return empty array and original answer
      return [[], answer] if citation_numbers.empty?

      # Filter citations to only include those actually referenced
      # Citation numbers are 1-indexed, array is 0-indexed
      used_citations = citation_numbers.filter_map do |num|
        all_citations[num - 1] if num > 0 && num <= all_citations.length
      end

      # Build a mapping from old citation numbers to new sequential numbers
      # e.g., if answer has [2] and [5], map: {2 => 1, 5 => 2}
      citation_mapping = {}
      citation_numbers.each_with_index do |old_num, new_index|
        citation_mapping[old_num] = new_index + 1
      end

      # Renumber citations in the answer text
      renumbered_answer = answer.gsub(/\[(\d+)\]/) do |match|
        old_num = $1.to_i
        new_num = citation_mapping[old_num]
        new_num ? "[#{new_num}]" : match
      end

      [used_citations, renumbered_answer]
    end

    def format_citations(chunks_data)
      chunks_data.map do |chunk_info|
        {
          chunk_id: chunk_info[:chunk].id,
          document_id: chunk_info[:document]&.id,
          document_title: chunk_info[:document]&.title || "Unknown Document",
          relevance: calculate_relevance(chunk_info[:distance]),
          position: chunk_info[:position]
        }
      end
    end

    def calculate_relevance(distance)
      # Convert cosine distance to a 0-1 similarity score
      # Distance of 0 = perfect match (similarity 1.0)
      # Distance of 2 = completely opposite (similarity 0.0)
      return 1.0 if distance.nil? || distance == 0
      similarity = [0, 1 - (distance / 2.0)].max
      similarity.round(2)
    end

    def call_llm(prompt, model)
      # Get provider config for the current environment
      chat_config = Rails.application.config.x.ruby_llm[Rails.env.to_sym][:chat]

      chat = RubyLLM.chat(
        model: model,
        provider: chat_config[:provider]
      )

      response = chat.ask(prompt)
      response.content
    rescue => e
      raise LLMError, "LLM request failed: #{e.message}"
    end

    class LLMError < StandardError; end
  end
end
