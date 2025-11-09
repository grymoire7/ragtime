module Rag
  class ChunkRetriever
    # Default number of chunks to retrieve
    DEFAULT_LIMIT = 5
    # Default distance threshold for L2 (Euclidean) distance used by sqlite-vec
    # Lower values = more similar (0 = identical)
    # Threshold of 1.2 allows for reasonable semantic similarity while filtering noise
    # Adjusted from 0.75 which was too strict for L2 distance
    DEFAULT_DISTANCE_THRESHOLD = 1.2

    # Retrieve the most relevant chunks for a query
    # @param query [String] the user's question or search query
    # @param limit [Integer] maximum number of chunks to return
    # @param distance_threshold [Float] maximum distance for chunks to be considered relevant
    # @param document_ids [Array<Integer>] optional array of document IDs to filter by
    # @param created_after [DateTime] optional filter for documents created after this date
    # @return [Array<Hash>] array of hashes with :chunk, :distance, and :document keys
    def self.retrieve(query, limit: DEFAULT_LIMIT, distance_threshold: DEFAULT_DISTANCE_THRESHOLD, document_ids: nil, created_after: nil)
      new.retrieve(query, limit: limit, distance_threshold: distance_threshold, document_ids: document_ids, created_after: created_after)
    end

    def retrieve(query, limit: DEFAULT_LIMIT, distance_threshold: DEFAULT_DISTANCE_THRESHOLD, document_ids: nil, created_after: nil)
      return [] if query.blank?

      # Generate embedding for the query
      query_embedding = generate_query_embedding(query)
      return [] if query_embedding.nil?

      # Search for similar chunks
      results = Chunk.search_similar(
        query_embedding,
        limit: limit,
        distance_threshold: distance_threshold
      )

      # Filter by document IDs if specified
      results = filter_by_documents(results, document_ids) if document_ids.present?

      # Filter by document creation date if specified
      results = filter_by_date(results, created_after) if created_after.present?

      # Format results with additional metadata
      format_results(results)
    end

    private

    def generate_query_embedding(query)
      DocumentProcessing::EmbeddingGenerator.generate(query)
    rescue DocumentProcessing::EmbeddingGenerator::EmbeddingError => e
      Rails.logger.error("Failed to generate query embedding: #{e.message}")
      nil
    end

    def filter_by_documents(results, document_ids)
      results.select do |chunk, _distance|
        document_ids.include?(chunk.document_id)
      end
    end

    def filter_by_date(results, created_after)
      # Load documents for date checking
      document_ids = results.map { |chunk, _| chunk.document_id }.compact.uniq
      documents_by_id = Document.where(id: document_ids).index_by(&:id)

      results.select do |chunk, _distance|
        document = documents_by_id[chunk.document_id]
        document && document.created_at >= created_after
      end
    end

    def format_results(results)
      return [] if results.empty?

      # Load documents for the chunks
      document_ids = results.map { |chunk, _| chunk.document_id }.compact.uniq
      documents_by_id = Document.where(id: document_ids).index_by(&:id)

      # Map to result format
      results.map do |chunk, distance|
        {
          chunk: chunk,
          distance: distance,
          document: documents_by_id[chunk.document_id],
          content: chunk.content,
          position: chunk.position
        }
      end
    end
  end
end
