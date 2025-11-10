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

          # Try different extensions based on platform
          # macOS uses .dylib, Linux uses .so
          base_path = SqliteVec.loadable_path
          extensions = ['.dylib', '.so', '']

          loaded = false
          extensions.each do |ext|
            begin
              @raw_connection.load_extension(base_path + ext)
              loaded = true
              break
            rescue SQLite3::SQLException
              # Try next extension
              next
            end
          end

          @raw_connection.enable_load_extension(false)

          unless loaded
            raise "Could not load sqlite-vec extension from #{base_path}"
          end

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
