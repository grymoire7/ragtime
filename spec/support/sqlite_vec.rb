# Ensure sqlite-vec extension is loaded for tests
require 'sqlite_vec'

RSpec.configure do |config|
  config.before(:suite) do
    # Patch the SQLite3 adapter to always load the extension on every connection
    module SqliteVecTestSupport
      def configure_connection
        super
        @raw_connection.enable_load_extension(true)
        SqliteVec.load(@raw_connection)
        @raw_connection.enable_load_extension(false)
      rescue => e
        Rails.logger.warn "Failed to load sqlite-vec in test: #{e.message}"
      end
    end

    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteVecTestSupport)

    # Reload the connection to apply the patch
    ActiveRecord::Base.connection.reconnect!

    # Drop and recreate the virtual table
    begin
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS vec_chunks")
    rescue => e
      # Ignore errors
    end

    # Drop supporting tables
    ["vec_chunks_info", "vec_chunks_chunks", "vec_chunks_rowids", "vec_chunks_vector_chunks00"].each do |table|
      begin
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table}")
      rescue => e
        # Ignore errors
      end
    end

    # Recreate the virtual table
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE VIRTUAL TABLE vec_chunks USING vec0(
        chunk_id INTEGER PRIMARY KEY,
        embedding FLOAT[512]
      );
    SQL
  end

  # Clean up vec_chunks after each test since virtual tables don't support transactions
  config.after(:each) do
    begin
      ActiveRecord::Base.connection.execute("DELETE FROM vec_chunks")
    rescue => e
      # Ignore errors if table doesn't exist
    end
  end
end
