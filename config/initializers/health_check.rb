# Health check endpoint for container deployment
# This initializer adds a simple health check endpoint that returns "OK"

# Note: Health check endpoint is handled by Nginx at docker/nginx-production.conf:21-25
# This provides instant responses without Rails overhead for production health checks
# Rails built-in health check is available at /up if needed for deeper app monitoring

# Verify sqlite-vec extension loads correctly in production
# Skip during asset precompilation to avoid dependency issues in Docker
return if ENV['SKIP_SQLITE_VEC'] == 'true'

unless ENV['SKIP_SQLITE_VEC'] == 'true'
  begin
    # Test sqlite-vec extension availability
    require 'sqlite3'

    # Create a temporary in-memory database to test the extension
    db = SQLite3::Database.new(':memory:')

    # Try to load the vec extension using absolute path
    db.enable_load_extension(true)
    require 'sqlite_vec'
    extension_path = SqliteVec.loadable_path + '.so'
    db.load_extension(extension_path)
    db.enable_load_extension(false)

    Rails.logger.info "sqlite-vec extension loaded successfully" if defined?(Rails.logger)
  rescue LoadError => e
    Rails.logger.error "Failed to load sqlite-vec extension: #{e.message}" if defined?(Rails.logger)
    # In production, we want to fail fast if the extension isn't available
    if Rails.env.production?
      Rails.logger.error "CRITICAL: sqlite-vec extension is required in production. Exiting."
      exit 1
    end
  rescue => e
    Rails.logger.error "Error verifying sqlite-vec extension: #{e.message}" if defined?(Rails.logger)
    if Rails.env.production?
      Rails.logger.error "CRITICAL: Unable to verify sqlite-vec extension. Exiting."
      exit 1
    end
  ensure
    db&.close
  end
end