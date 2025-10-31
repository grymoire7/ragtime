module Rag
  class AnswerGenerator
    # Generate an answer to a question using RAG
    # @param question [String] the user's question
    # @param options [Hash] optional parameters
    # @option options [Integer] :limit number of chunks to retrieve (default: 5)
    # @option options [Float] :distance_threshold maximum distance for relevant chunks
    # @option options [Array<Integer>] :document_ids filter to specific documents
    # @option options [String] :model the LLM model to use (default: claude-3-5-haiku-latest)
    # @return [Hash] with keys :answer, :chunks_used, :model
    def self.generate(question, options = {})
      new.generate(question, options)
    end

    def generate(question, options = {})
      # Extract options with defaults
      limit = options.fetch(:limit, 5)
      distance_threshold = options.fetch(:distance_threshold, 1.0)
      document_ids = options[:document_ids]
      model = options.fetch(:model, "claude-3-5-haiku-latest")

      # Step 1: Retrieve relevant chunks
      chunks_data = ChunkRetriever.retrieve(
        question,
        limit: limit,
        distance_threshold: distance_threshold,
        document_ids: document_ids
      )

      # Step 2: Build prompt
      prompt = PromptBuilder.build(question, chunks_data)

      # Step 3: Generate answer using LLM
      answer = call_llm(prompt, model)

      # Return structured response
      {
        answer: answer,
        chunks_used: chunks_data.map { |c| { id: c[:chunk].id, document_title: c[:document]&.title } },
        model: model
      }
    rescue => e
      Rails.logger.error("Failed to generate answer: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      {
        answer: "I'm sorry, I encountered an error while trying to answer your question. Please try again.",
        chunks_used: [],
        model: model,
        error: e.message
      }
    end

    private

    def call_llm(prompt, model)
      response = RubyLLM::Client.chat(
        messages: [
          { role: "user", content: prompt }
        ],
        model: model
      )

      response.content
    rescue => e
      raise LLMError, "LLM request failed: #{e.message}"
    end

    class LLMError < StandardError; end
  end
end
