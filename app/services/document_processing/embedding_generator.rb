module DocumentProcessing
  class EmbeddingGenerator
    # Generate embeddings for text using Anthropic's voyage-3.5-lite model
    # This model produces 512-dimensional embeddings
    # @param text [String] the text to embed
    # @return [Array<Float>] the embedding vector
    # @raises [EmbeddingError] if embedding generation fails
    def self.generate(text)
      new.generate(text)
    end

    # Generate embeddings for multiple texts in batch
    # @param texts [Array<String>] array of texts to embed
    # @return [Array<Array<Float>>] array of embedding vectors
    def self.generate_batch(texts)
      new.generate_batch(texts)
    end

    def initialize
      # RubyLLM should be configured in config/initializers/ruby_llm.rb
      # with Anthropic API key
    end

    def generate(text)
      return nil if text.blank?

      begin
        # Use RubyLLM to generate embedding with environment-specific model
        embedding_config = Rails.application.config.x.ruby_llm[Rails.env.to_sym][:embedding]

        response = RubyLLM.embed(
          text,
          model: embedding_config[:model],
          provider: embedding_config[:provider]
        )

        # RubyLLM returns a RubyLLM::Embedding object with .vectors method
        response.vectors
      rescue => e
        raise EmbeddingError, "Failed to generate embedding: #{e.message}"
      end
    end

    def generate_batch(texts)
      return [] if texts.empty?

      begin
        # Process in batches to avoid API limits
        batch_size = 50
        all_embeddings = []

        texts.each_slice(batch_size) do |batch|
          embeddings = batch.map { |text| generate(text) }
          all_embeddings.concat(embeddings)
        end

        all_embeddings
      rescue => e
        raise EmbeddingError, "Failed to generate batch embeddings: #{e.message}"
      end
    end

    class EmbeddingError < StandardError; end
  end
end
