# syntax=docker/dockerfile:1
# Multi-stage Dockerfile for Ragtime (Rails 8 + Vue.js)
# Designed for production deployment on Fly.io with Nginx reverse proxy

# Stage 1: Node.js build stage for Vue.js frontend
FROM node:18-alpine AS frontend-build

# Set working directory for frontend build
WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install frontend dependencies
RUN npm ci --only=production && npm cache clean --force

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
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Precompile bootsnap for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Stage 3: Final production stage with Nginx + Rails + foreman
FROM ruby:3.4.5-slim AS production

# Install runtime dependencies including Nginx and sqlite-vec
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
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
RUN mkdir -p /rails/storage && \
    chown -R rails:rails /rails/storage

# Set up Nginx configuration
RUN rm -f /etc/nginx/sites-enabled/default && \
    rm -f /etc/nginx/conf.d/default.conf

# Create Nginx config for Rails reverse proxy
RUN cat > /etc/nginx/sites-available/ragtime << 'EOF'
server {
    listen 80;
    server_name localhost;

    # Frontend static files
    location /frontend/ {
        alias /rails/public/frontend/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Rails static assets
    location / {
        root /rails/public;
        try_files $uri @rails;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    }

    # Rails application
    location @rails {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Proxy "";
        proxy_redirect off;

        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
RUN ln -s /etc/nginx/sites-available/ragtime /etc/nginx/sites-enabled/

# Create Procfile for process management
RUN cat > /rails/Procfile << 'EOF'
web: ./bin/rails server -p 3000 -e production
nginx: nginx -g 'daemon off;'
EOF

# Create foreman configuration
RUN cat > /rails/Procfile.dev << 'EOF'
web: ./bin/rails server -p 3000 -e production
nginx: nginx -g 'daemon off;'
EOF

# Create non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails

# Switch to non-root user
USER 1000:1000

# Install foreman for process management
RUN gem install foreman

# Expose port 80 for Nginx
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Configure entrypoint
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start processes with foreman
CMD ["foreman", "start", "-f", "Procfile"]