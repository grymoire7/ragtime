# Load sqlite-vec extension for vector similarity search
require "sqlite_vec"

# Load extension on every new connection
ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(
    Module.new do
      def configure_connection
        super
        # Enable extension loading temporarily
        @raw_connection.enable_load_extension(true)
        SqliteVec.load(@raw_connection)
        @raw_connection.enable_load_extension(false)
      rescue SQLite3::Exception => e
        Rails.logger.warn "Failed to load sqlite-vec extension: #{e.message}"
        Rails.logger.warn "Vector similarity search will not be available"
      end
    end
  )
end
