# Phase 8 Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy Ragtime to Fly.io as a single Docker container with Nginx reverse proxy for portfolio showcase

**Architecture:** Multi-stage Docker build with Nginx serving Vue.js static assets and proxying API requests to Rails Puma via Unix socket, using Fly.io persistent volumes for SQLite data

**Tech Stack:** Docker, Docker Compose, Nginx, Rails 8, Fly.io, sqlite-vec, Vue.js 3

---

## Task 1: Create Dockerfile for Multi-Stage Build

**Files:**
- Create: `Dockerfile`
- Reference: `package.json`, `Gemfile`, `config/application.rb`

**Step 1: Write Dockerfile with Node.js build stage**

```dockerfile
# Stage 1: Build Vue.js frontend
FROM node:18-alpine AS frontend-build

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production

COPY frontend/ ./
RUN npm run build
```

**Step 2: Add Ruby stage for Rails dependencies**

```dockerfile
# Stage 2: Build Rails application
FROM ruby:3.2-alpine AS rails-build

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    git \
    nodejs \
    npm

# Install sqlite-vec native extension
RUN gem install sqlite-vec -v '0.1.6'

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3
```

**Step 3: Add final stage with Nginx + Rails**

```dockerfile
# Stage 3: Production image
FROM ruby:3.2-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    sqlite-dev \
    nginx \
    nodejs \
    npm \
    sqlite

# Install sqlite-vec
RUN gem install sqlite-vec -v '0.1.6'

# Create app user
RUN addgroup -g 1000 app && \
    adduser -D -s /bin/sh -u 1000 -G app app

# Set up directories
WORKDIR /app
COPY --from=rails-build /usr/local/bundle/ /usr/local/bundle/
COPY . .

# Copy frontend assets
COPY --from=frontend-build /app/frontend/dist/ /app/public/

# Set up permissions
RUN chown -R app:app /app && \
    mkdir -p /app/tmp/pids /app/tmp/sockets /app/log && \
    chown -R app:app /app/tmp /app/log

# Install process manager
RUN gem install foreman

# Copy Nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Switch to app user
USER app

# Expose port
EXPOSE 80

# Start processes
CMD ["foreman", "start", "-f", "Procfile.prod"]
```

**Step 4: Commit Dockerfile**

```bash
git add Dockerfile
git commit -m "feat: add multi-stage Dockerfile for deployment"
```

## Task 2: Create Production Procfile

**Files:**
- Create: `Procfile.prod`
- Reference: existing `Procfile.dev`

**Step 1: Write production Procfile**

```procfile
web: nginx -g 'daemon off;'
rails: bundle exec puma -C config/puma.rb
worker: bundle exec solid_queue start
```

**Step 2: Commit Procfile**

```bash
git add Procfile.prod
git commit -m "feat: add production Procfile for containerized processes"
```

## Task 3: Configure Nginx Reverse Proxy

**Files:**
- Create: `docker/nginx.conf`
- Create: `docker/` directory

**Step 1: Create docker directory and Nginx config**

```bash
mkdir -p docker
```

**Step 2: Write Nginx configuration**

```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Upstream Rails via Unix socket
    upstream rails {
        server unix:///app/tmp/sockets/puma.sock;
    }

    server {
        listen 80;
        server_name localhost;
        root /app/public;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Handle Vue.js router (SPA)
        location / {
            try_files $uri $uri/ /index.html;
        }

        # API proxy to Rails
        location /api/ {
            proxy_pass http://rails;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Request-ID $request_id;

            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Health check endpoint
        location /health {
            proxy_pass http://rails/health;
            access_log off;
        }

        # Static assets with caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header X-Content-Type-Options nosniff;
        }
    }
}
```

**Step 3: Commit Nginx configuration**

```bash
git add docker/nginx.conf
git commit -m "feat: add Nginx reverse proxy configuration"
```

## Task 4: Configure Rails for Production Container

**Files:**
- Modify: `config/environments/production.rb`
- Modify: `config/puma.rb`
- Create: `config/initializers/health_check.rb`

**Step 1: Add health check initializer**

```ruby
# config/initializers/health_check.rb
Rails.application.configure do
  # Simple health check endpoint
  config.after_initialize do
    Rails.application.routes.draw do
      get '/health', to: proc { [200, {}, ['OK']] }
    end
  end
end
```

**Step 2: Update Puma configuration for Unix socket**

```ruby
# config/puma.rb
#!/usr/bin/env puma

directory '/app'
environment 'production'

# Use Unix socket for Nginx communication
bind 'unix:///app/tmp/sockets/puma.sock'

# Process management
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Logging
stdout_redirect '/app/log/puma.stdout.log', '/app/log/puma.stderr.log', true

# Process management
plugin :tmp_restart
```

**Step 3: Update production environment settings**

```ruby
# config/environments/production.rb - add these configurations
Rails.application.configure do
  # ... existing config ...

  # Serve static files through Nginx, not Rails
  config.public_file_server.enabled = false

  # Enable caching
  config.action_controller.perform_caching = true

  # Log to stdout for container logs
  config.log_level = :info
  config.log_tags = [ :request_id ]
  config.log_to = $stdout

  # Active Storage local file system
  config.active_storage.service = :local

  # sqlite-vec extension verification
  config.after_initialize do
    begin
      ActiveRecord::Base.connection.execute("SELECT vec_version()")
      Rails.logger.info "sqlite-vec extension loaded successfully"
    rescue => e
      Rails.logger.error "sqlite-vec extension failed to load: #{e.message}"
      exit 1
    end
  end
end
```

**Step 4: Commit Rails production configuration**

```bash
git add config/initializers/health_check.rb config/puma.rb config/environments/production.rb
git commit -m "feat: configure Rails for production container deployment"
```

## Task 5: Create Docker Compose for Local Testing

**Files:**
- Create: `docker-compose.yml`
- Create: `docker-compose.override.yml`

**Step 1: Write main docker-compose.yml**

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "80:80"
    volumes:
      - ./db:/app/db
      - ./storage:/app/storage
      - ./log:/app/log
    environment:
      - RAILS_ENV=production
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
    profiles:
      - production

  development:
    build:
      context: .
      target: rails-build
    ports:
      - "3000:3000"
      - "5173:5173"
    volumes:
      - .:/app
      - /app/node_modules
      - /app/frontend/node_modules
    environment:
      - RAILS_ENV=development
    command: bundle exec foreman start -f Procfile.dev
    profiles:
      - development
```

**Step 2: Write development override file**

```yaml
# docker-compose.override.yml
version: '3.8'

services:
  development:
    volumes:
      - .:/app
      - /app/node_modules
      - /app/frontend/node_modules
      - ./db:/app/db
      - ./storage:/app/storage
    environment:
      - RAILS_ENV=development
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
```

**Step 3: Commit Docker Compose files**

```bash
git add docker-compose.yml docker-compose.override.yml
git commit -m "feat: add Docker Compose for local testing and development"
```

## Task 6: Configure Fly.io Deployment

**Files:**
- Create: `fly.toml`
- Modify: `.dockerignore`

**Step 1: Create fly.toml configuration**

```toml
app = 'ragtime-docs'

[build]
  dockerfile = 'Dockerfile'

[deploy]
  release_command = 'bin/rails db:migrate'

[env]
  RAILS_ENV = 'production'
  RAILS_LOG_TO_STDOUT = 'true'
  RAILS_SERVE_STATIC_FILES = 'false'

[http_service]
  internal_port = 80
  force_https = true
  auto_stop_machines = true
  min_machines_running = 0
  processes = ['app']

[[http_service.checks]]
  grace_period = '10s'
  interval = '30s'
  method = 'GET'
  path = '/health'
  protocol = 'http'
  timeout = '5s'
  tls_skip_verify = false

[mounts]
  source = 'ragtime_data'
  destination = '/app/data'

[[vm]]
  memory = '512mb'
  cpu_kind = 'shared'
  cpus = 1
```

**Step 2: Update .dockerignore**

```dockerignore
.git
.gitignore
README.md
Dockerfile
.dockerignore
fly.toml
docker-compose*.yml
.env
.env.*
log/*
tmp/*
storage/*
db/*.sqlite3
db/*.sqlite3-*
node_modules/*
frontend/node_modules/*
frontend/dist/*
coverage/
.byebug_history
.rspec_status
```

**Step 3: Commit Fly.io configuration**

```bash
git add fly.toml .dockerignore
git commit -m "feat: add Fly.io deployment configuration"
```

## Task 7: Update Active Storage for Persistent Volume

**Files:**
- Modify: `config/environments/production.rb`
- Create: `config/storage.yml`

**Step 1: Configure storage for persistent volume**

```yaml
# config/storage.yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# Use persistent volume on Fly.io
production:
  service: Disk
  root: <%= Rails.root.join("data/storage") %>
```

**Step 2: Update production environment to use persistent storage**

```ruby
# config/environments/production.rb - add/update
config.active_storage.service = :production
```

**Step 3: Create symlink for persistent storage in Dockerfile**

Add this line before USER app in Dockerfile:
```dockerfile
# Create symlink for persistent storage
RUN ln -sf /app/data/storage /app/storage
```

**Step 4: Commit storage configuration**

```bash
git add config/storage.yml config/environments/production.rb Dockerfile
git commit -m "feat: configure Active Storage for persistent volume"
```

## Task 8: Create Deployment Scripts

**Files:**
- Create: `scripts/deploy.sh`
- Create: `scripts/setup-local.sh`
- Create: `scripts/` directory

**Step 1: Create setup script for local testing**

```bash
#!/bin/bash
# scripts/setup-local.sh

echo "Setting up local development environment..."

# Check if RAILS_MASTER_KEY is set
if [ -z "$RAILS_MASTER_KEY" ]; then
  echo "Error: RAILS_MASTER_KEY environment variable is required"
  echo "Set it with: export RAILS_MASTER_KEY=$(cat config/master.key)"
  exit 1
fi

# Build and start production image
echo "Building Docker image..."
docker-compose build web

echo "Starting production environment..."
docker-compose up --profile production

echo "Local testing environment ready at http://localhost"
```

**Step 2: Create deployment script**

```bash
#!/bin/bash
# scripts/deploy.sh

echo "Deploying Ragtime to Fly.io..."

# Check if Fly CLI is installed
if ! command -v fly &> /dev/null; then
  echo "Error: Fly CLI is not installed"
  echo "Install it from: https://fly.io/docs/hands-on/install-flyctl/"
  exit 1
fi

# Set Rails master key
echo "Setting RAILS_MASTER_KEY..."
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)

# Deploy application
echo "Deploying application..."
fly deploy

echo "Deployment complete!"
echo "Check status with: fly status"
echo "View logs with: fly logs"
```

**Step 3: Make scripts executable**

```bash
chmod +x scripts/setup-local.sh scripts/deploy.sh
```

**Step 4: Commit deployment scripts**

```bash
git add scripts/
git commit -m "feat: add deployment and local testing scripts"
```

## Task 9: Add Production Database Configuration

**Files:**
- Modify: `config/database.yml`

**Step 1: Update database.yml for production container**

```yaml
# config/database.yml - update production section
production:
  primary:
    adapter: sqlite3
    database: <%= Rails.root.join("data/production.sqlite3") %>
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    timeout: 5000

    # sqlite-vec extension
    extensions:
      - vec
```

**Step 2: Update Dockerfile to create data directory**

Add this line before USER app in Dockerfile:
```dockerfile
# Create data directory for persistent storage
RUN mkdir -p /app/data && chown -R app:app /app/data
```

**Step 3: Commit database configuration**

```bash
git add config/database.yml Dockerfile
git commit -m "feat: configure database for persistent volume"
```

## Task 10: Test Local Production Build

**Files:**
- Test: Local Docker build and functionality

**Step 1: Test Docker build locally**

```bash
# Build the image
docker-compose build web

# Start with production profile
docker-compose up --profile production -d

# Check logs
docker-compose logs web

# Test health endpoint
curl http://localhost/health

# Test frontend loads
curl http://localhost/
```

**Step 2: Verify sqlite-vec extension works**

```bash
# Access Rails console
docker-compose exec web bundle exec rails c

# In console:
ActiveRecord::Base.connection.execute("SELECT vec_version()")
```

**Step 3: Test application functionality**

```bash
# Upload a document (using curl or browser)
# Test chat functionality
# Verify citations work
```

**Step 4: Commit any fixes and finalize**

```bash
git add .
git commit -m "feat: finalize local testing and fixes"
```

## Task 11: Deploy to Fly.io

**Files:**
- Fly.io deployment and verification

**Step 1: Install Fly.io CLI and login**

```bash
# Install Fly CLI (if not already installed)
curl -L https://fly.io/install.sh | sh

# Login to Fly.io
fly auth login
```

**Step 2: Deploy application**

```bash
# Run deployment script
./scripts/deploy.sh

# Monitor deployment
fly logs
```

**Step 3: Verify deployment**

```bash
# Check app status
fly status

# Test health endpoint
curl https://ragtime-docs.fly.dev/health

# Test application in browser
# Upload documents, test chat, verify citations
```

**Step 4: Set up monitoring (optional)**

```bash
# Set up alerts or monitoring as needed
fly volume list
fly machine list
```

**Step 5: Commit final deployment configuration**

```bash
git add .
git commit -m "feat: complete Phase 8 deployment implementation"
```

## Task 12: Documentation and README Updates

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Create: `docs/deployment.md`

**Step 1: Update project README**

```markdown
## Deployment

### Local Development with Docker

```bash
# Test production build locally
./scripts/setup-local.sh

# Development with hot reload
docker-compose up --profile development
```

### Production Deployment

```bash
# Deploy to Fly.io
./scripts/deploy.sh
```

### Live Demo

https://ragtime-docs.fly.dev

*Password-protected portfolio demonstration*
```

**Step 2: Update CLAUDE.md with Phase 8 completion**

```markdown
**Phase 8: Deployment and documentation** ✅ COMPLETE
- ✅ Single Docker container deployment on Fly.io
- ✅ Nginx reverse proxy configuration
- ✅ Persistent volume for SQLite data
- ✅ Local testing with Docker Compose
- ✅ Production deployment scripts
- ✅ Live demo at https://ragtime-docs.fly.dev
```

**Step 3: Create deployment documentation**

```markdown
# Deployment Guide

## Architecture

Single Docker container with Nginx serving Vue.js frontend and proxying API requests to Rails.

## Local Testing

See `scripts/setup-local.sh` for complete local testing workflow.

## Production Deployment

See `scripts/deploy.sh` for automated deployment to Fly.io.

## Troubleshooting

- sqlite-vec extension: Verified during container build
- Database migrations: Run automatically on deploy
- Persistent data: Stored on Fly.io volume
```

**Step 4: Commit documentation updates**

```bash
git add README.md CLAUDE.md docs/deployment.md
git commit -m "docs: complete Phase 8 deployment documentation"
```

---

**Phase 8 Implementation Complete** 🎉

**Verification Checklist:**
- [ ] Docker image builds successfully
- [ ] Local production environment works
- [ ] sqlite-vec extension verified
- [ ] Fly.io deployment successful
- [ ] All app features functional in production
- [ ] Documentation updated
- [ ] Portfolio showcase ready

**Next Phase:** Ready for Phase 9 optional enhancements or portfolio showcase presentation!