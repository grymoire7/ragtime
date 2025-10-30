class Chunk < ApplicationRecord
  belongs_to :document

  validates :content, presence: true
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :token_count, presence: true, numericality: { greater_than: 0 }

  # Callbacks to keep the virtual table in sync
  after_create :insert_into_vec_table
  after_update :update_vec_table, if: :saved_change_to_embedding?
  after_destroy :delete_from_vec_table

  # Convert embedding array to binary format for storage
  def embedding=(vector_array)
    return super(nil) if vector_array.nil?

    # Convert array of floats to binary format (little-endian)
    binary_data = vector_array.pack("f*")
    super(binary_data)
  end

  # Convert binary embedding back to array
  def embedding
    binary_data = super
    return nil if binary_data.nil?

    # Unpack binary data to array of floats
    binary_data.unpack("f*")
  end

  # Search for similar chunks using vector similarity
  # Returns array of [chunk, distance] pairs
  def self.search_similar(query_embedding, limit: 5, distance_threshold: 1.0)
    return [] if query_embedding.nil? || query_embedding.empty?

    # Convert query embedding to binary format
    binary_query = query_embedding.pack("f*")

    # Query the virtual table for similar vectors
    # Note: Use execute instead of exec_query to avoid encoding issues with binary data
    sql = <<~SQL
      SELECT
        chunks.id,
        chunks.content,
        chunks.position,
        chunks.token_count,
        chunks.created_at,
        chunks.updated_at,
        chunks.document_id,
        vec_chunks.distance
      FROM vec_chunks
      INNER JOIN chunks ON chunks.id = vec_chunks.chunk_id
      WHERE vec_chunks.embedding MATCH ?
        AND vec_chunks.k = ?
        AND distance <= ?
      ORDER BY distance
    SQL

    # Use raw connection.execute with bind parameters
    results = connection.raw_connection.execute(sql, [binary_query, limit, distance_threshold])

    results.map do |row|
      # Manually construct chunk from row data
      chunk = new(
        id: row[0],
        content: row[1],
        position: row[2],
        token_count: row[3],
        created_at: row[4],
        updated_at: row[5],
        document_id: row[6]
      )
      chunk.instance_variable_set(:@new_record, false)
      chunk.instance_variable_set(:@previously_new_record, false)

      distance = row[7]
      [chunk, distance]
    end
  end

  private

  def insert_into_vec_table
    # Access the raw binary data from the attributes hash
    # This bypasses our custom getter that unpacks the array
    binary_embedding = @attributes['embedding']&.value
    return unless binary_embedding.present?

    # Use connection.execute with hex notation to pass binary data
    # SQLite requires binary data as BLOB, using X'...' hex notation
    hex_data = binary_embedding.unpack1('H*')
    self.class.connection.execute(
      "INSERT INTO vec_chunks (chunk_id, embedding) VALUES (#{id}, X'#{hex_data}')"
    )
  end

  def update_vec_table
    # Access the raw binary data from the attributes hash
    binary_embedding = @attributes['embedding']&.value
    return unless binary_embedding.present?

    # Use hex notation to pass binary data
    hex_data = binary_embedding.unpack1('H*')
    self.class.connection.execute(
      "UPDATE vec_chunks SET embedding = X'#{hex_data}' WHERE chunk_id = #{id}"
    )
  end

  def delete_from_vec_table
    self.class.connection.execute(
      "DELETE FROM vec_chunks WHERE chunk_id = #{id}"
    )
  end
end
