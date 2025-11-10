# syntax=docker/dockerfile:1
# Multi-stage Dockerfile for Ragtime (Rails 8 + Vue.js)
# Designed for production deployment on Fly.io with Nginx reverse proxy

# Stage 1: Node.js build stage for Vue.js frontend
FROM node:20-alpine AS frontend-build

# Set working directory for frontend build
WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install frontend dependencies (including dev dependencies needed for build)
RUN npm ci && npm cache clean --force

# Copy frontend source code
COPY frontend/ ./

# Build Vue.js application for production
RUN npm run build

# Stage 2: Ruby stage for Rails dependencies with sqlite-vec extension
FROM ruby:3.4.5-slim AS ruby-build

# Install system dependencies for building gems and sqlite-vec
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libyaml-dev \
    pkg-config \
    sqlite3 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# Set Rails app directory
WORKDIR /rails

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby gems including sqlite-vec
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy Rails application code
COPY . .

# Copy pre-built frontend assets from frontend stage
COPY --from=frontend-build /app/frontend/dist ./public/frontend

# Precompile Rails assets
RUN SECRET_KEY_BASE_DUMMY=1 SKIP_SQLITE_VEC=true ./bin/rails assets:precompile

# Precompile bootsnap for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Stage 3: Final production stage with Nginx + Rails + foreman
FROM ruby:3.4.5-slim AS production

# Install runtime dependencies including Nginx and sqlite-vec
# Include build tools for sqlite-vec native extension
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    libjemalloc2 \
    libsqlite3-dev \
    libvips \
    nginx \
    sqlite3 \
    procps \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true"

# Set Rails app directory
WORKDIR /rails

# Copy built gems from ruby-build stage
COPY --from=ruby-build "${BUNDLE_PATH}" "${BUNDLE_PATH}"

# Copy application code from ruby-build stage
COPY --from=ruby-build /rails /rails

# Copy pre-built frontend assets from frontend-build stage
COPY --from=frontend-build /app/frontend/dist ./public/frontend

# Create directories for runtime files
RUN mkdir -p db log tmp/pids tmp/cache tmp/sockets

# Set up persistent storage for Fly.io volume
# The volume will be mounted at /rails/storage by Fly.io
# Ensure proper directory structure exists within the storage directory
RUN mkdir -p /rails/storage

# Set up Nginx configuration
RUN rm -f /etc/nginx/sites-enabled/default && \
    rm -f /etc/nginx/conf.d/default.conf

# Copy production Nginx config
COPY docker/nginx-production.conf /etc/nginx/sites-available/ragtime

# Enable the site
RUN ln -s /etc/nginx/sites-available/ragtime /etc/nginx/sites-enabled/

# Create non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails /rails/storage /usr/local/bundle

# Install sudo and foreman for process management
# Reinstall sqlite-vec gem to ensure correct native extension
RUN apt-get update && apt-get install -y sudo && \
    gem install foreman && \
    gem uninstall sqlite-vec --force && \
    gem install sqlite-vec --platform=x86_64-linux && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure sudo for the rails user
RUN echo "rails ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy production Procfile to container
COPY Procfile.prod /rails/Procfile

# Expose port 80 for Nginx
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Configure entrypoint
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start processes with foreman
CMD ["foreman", "start", "-f", "Procfile"]