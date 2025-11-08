module DocumentProcessing
  class EmbeddingGenerator
    # Target embedding dimension for vec_chunks virtual table
    # Standardized to 1536 to match OpenAI text-embedding-3-small (production)
    TARGET_DIMENSION = 1536

    # Generate embeddings for text using environment-specific embedding model
    # Production: OpenAI text-embedding-3-small (1536 dimensions)
    # Development: Ollama jina-embeddings (512 dimensions, padded to 1536)
    # @param text [String] the text to embed
    # @return [Array<Float>] the embedding vector (always 1536 dimensions)
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
        embedding = response.vectors

        # Pad embedding to TARGET_DIMENSION if needed (for dev Ollama embeddings)
        # OpenAI embeddings are already 1536, so this is a no-op in production
        pad_embedding(embedding)
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

    private

    # Pad or truncate embedding to TARGET_DIMENSION
    # @param embedding [Array<Float>] the embedding vector
    # @return [Array<Float>] padded/truncated embedding vector
    def pad_embedding(embedding)
      return embedding if embedding.length == TARGET_DIMENSION

      if embedding.length < TARGET_DIMENSION
        # Pad with zeros to reach target dimension
        embedding + Array.new(TARGET_DIMENSION - embedding.length, 0.0)
      else
        # Truncate if longer than target (shouldn't happen in practice)
        embedding.take(TARGET_DIMENSION)
      end
    end

    class EmbeddingError < StandardError; end
  end
end
