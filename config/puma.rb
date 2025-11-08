# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.

require 'fileutils'
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Environment-specific binding configuration
if ENV["RAILS_ENV"] == "production"
  # In production, use Unix socket for Nginx communication
  socket_directory = File.dirname(ENV.fetch("SOCKET_PATH", "/app/tmp/sockets/puma.sock"))

  # Ensure socket directory exists
  FileUtils.mkdir_p(socket_directory) unless Dir.exist?(socket_directory)

  # Bind to Unix socket
  bind "unix://#{ENV.fetch('SOCKET_PATH', '/app/tmp/sockets/puma.sock')}"

  # Configure workers for container environment
  # Use number of CPU cores, but cap at 4 to avoid memory issues
  # Fallback to 2 workers if Concurrent is not available
  worker_count = begin
    Concurrent.processor_count
  rescue NameError
    2 # Fallback if Concurrent is not available
  end
  workers ENV.fetch("WEB_CONCURRENCY") { [Integer(worker_count), 4].min }

  # Set worker timeout and boot timeout for container environment
  worker_timeout 30
  worker_boot_timeout 30

  # Preload app for better performance in production
  preload_app!

  # Configure worker lifecycle
  before_fork do
    require 'puma_worker_killer'
    PumaWorkerKiller.config do |config|
      config.ram = 1024 # MB
      config.frequency = 5 # seconds
      config.percent_usage = 0.98
      config.rolling_restart_frequency = 6 * 3600 # 6 hours
      config.reaper_status_logs = false # setting this to false will not log lines like:
      # PumaWorkerKiller: Consuming 54.34765625 mb with master and 2 workers.
    end
    PumaWorkerKiller.start
  end

  # Reconfigure RubyLLM in each worker after fork
  before_worker_boot do
    RubyLLM.configure do |config|
      config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] || Rails.application.credentials.dig(:anthropic_api_key)
      config.openai_api_key = ENV['OPENAI_API_KEY'] || Rails.application.credentials.dig(:openai_api_key)
    end
  end
else
  # In development, use TCP port
  port ENV.fetch("PORT", 3000)
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
