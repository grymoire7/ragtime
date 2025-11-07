# Load sqlite-vec extension for vector similarity search
# Skip during asset precompilation to avoid dependency issues in Docker
return if ENV['SKIP_SQLITE_VEC'] == 'true'

# Defer sqlite-vec loading until needed
# This allows the application to start even if there are extension issues
ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(
    Module.new do
      def configure_connection
        super
        # Load sqlite-vec extension - will be called when DB connection is established
        begin
          # Only require the gem when we actually need it
          require "sqlite_vec"

          # Enable extension loading temporarily
          @raw_connection.enable_load_extension(true)

          # Load extension using absolute path since sqlite-vec gem uses relative path
          # SqliteVec.loadable_path returns "/path/to/lib/vec0", need to add ".so"
          extension_path = SqliteVec.loadable_path + '.so'
          @raw_connection.load_extension(extension_path)

          @raw_connection.enable_load_extension(false)

          Rails.logger.info "sqlite-vec extension loaded successfully" if defined?(Rails.logger)
        rescue => e
          Rails.logger.warn "Failed to load sqlite-vec extension: #{e.message}" if defined?(Rails.logger)
          Rails.logger.warn "Vector similarity search will not be available" if defined?(Rails.logger)
          # Continue without extension - app will still work but vector search won't
        end
      end
    end
  )
end
