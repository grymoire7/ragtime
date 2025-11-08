class FixVecChunksDimensions < ActiveRecord::Migration[8.0]
  def up
    # Ensure sqlite-vec extension is loaded
    load_sqlite_vec_extension

    # Drop existing vec_chunks virtual table if it exists
    # Wrap in begin/rescue since table might not exist
    begin
      execute "DROP TABLE IF EXISTS vec_chunks;"
    rescue ActiveRecord::StatementInvalid => e
      # Table doesn't exist or extension not loaded, continue
      Rails.logger.info "Could not drop vec_chunks (may not exist): #{e.message}"
    end

    # Recreate with 1536 dimensions to match OpenAI text-embedding-3-small (production)
    # This standardizes dimensions across all environments
    # Note: Development Ollama embeddings (512 dims) will need to be padded to 1536
    execute <<-SQL
      CREATE VIRTUAL TABLE vec_chunks USING vec0(
        chunk_id INTEGER PRIMARY KEY,
        embedding FLOAT[1536]
      );
    SQL
  end

  def down
    # Ensure sqlite-vec extension is loaded
    load_sqlite_vec_extension

    # Drop the 1536-dim table
    begin
      execute "DROP TABLE IF EXISTS vec_chunks;"
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.info "Could not drop vec_chunks (may not exist): #{e.message}"
    end

    # Recreate with original 512 dimensions
    execute <<-SQL
      CREATE VIRTUAL TABLE vec_chunks USING vec0(
        chunk_id INTEGER PRIMARY KEY,
        embedding FLOAT[512]
      );
    SQL
  end

  private

  def load_sqlite_vec_extension
    # Load sqlite-vec extension for this migration
    require "sqlite_vec"

    conn = ActiveRecord::Base.connection.raw_connection
    conn.enable_load_extension(true)

    # Try different extensions based on platform
    base_path = SqliteVec.loadable_path
    extensions = ['.dylib', '.so', '']

    loaded = false
    extensions.each do |ext|
      begin
        conn.load_extension(base_path + ext)
        loaded = true
        break
      rescue SQLite3::SQLException
        next
      end
    end

    conn.enable_load_extension(false)

    unless loaded
      raise "Could not load sqlite-vec extension from #{base_path}"
    end
  rescue => e
    Rails.logger.warn "Failed to load sqlite-vec extension: #{e.message}"
    raise "sqlite-vec extension required for this migration"
  end
end
