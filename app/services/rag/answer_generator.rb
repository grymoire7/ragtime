module Rag
  class AnswerGenerator
    # Generate an answer to a question using RAG
    # @param question [String] the user's question
    # @param options [Hash] optional parameters
    # @option options [Integer] :limit number of chunks to retrieve (default: 5)
    # @option options [Float] :distance_threshold maximum distance for relevant chunks
    # @option options [Array<Integer>] :document_ids filter to specific documents
    # @option options [DateTime] :created_after filter to documents created after this date
    # @option options [String] :model the LLM model to use (default: claude-3-5-haiku-latest)
    # @return [Hash] with keys :answer, :citations, :model
    def self.generate(question, options = {})
      new.generate(question, options)
    end

    def generate(question, options = {})
      # Extract options with defaults
      limit = options.fetch(:limit, 5)
      distance_threshold = options.fetch(:distance_threshold, 1.0)
      document_ids = options[:document_ids]
      created_after = options[:created_after]

      # Use environment-specific model if not specified
      chat_config = Rails.application.config.x.ruby_llm[Rails.env.to_sym][:chat]
      model = options.fetch(:model, chat_config[:model])

      # Step 1: Retrieve relevant chunks
      chunks_data = ChunkRetriever.retrieve(
        question,
        limit: limit,
        distance_threshold: distance_threshold,
        document_ids: document_ids,
        created_after: created_after
      )

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
      citations = format_citations(chunks_data)

      # Return structured response
      {
        answer: answer,
        citations: citations,
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
