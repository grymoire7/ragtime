# Ragtime Deployment Architecture

## Overview

Single-container deployment strategy for Ragtime portfolio application on Fly.io using Docker, Nginx, and Rails with SQLite.

## Goals

- **Portfolio Showcase**: Publicly accessible demonstration of end-to-end capabilities
- **Reliability**: Consistent behavior across local development and production
- **Simplicity**: Single deployment command, minimal maintenance overhead
- **Security**: Proper secrets management and secure default configuration

## Architecture

### Container Design

**Multi-stage Docker build:**
1. **Node.js Stage**: Build Vue.js frontend assets
2. **Ruby Stage**: Install Rails gems and precompile assets
3. **Final Stage**: Combine Nginx + Rails + process manager

**Process Management:**
- Nginx serves Vue.js static files on port 80
- Rails Puma runs on Unix socket (localhost:3000 equivalent)
- Solid Queue process for background jobs
- Health check endpoint for Fly.io monitoring

### Data Storage

**Persistent Volume (Fly.io):**
- SQLite database (`db/production.sqlite3`)
- Active Storage uploads (`storage/`)
- Rails logs (`log/`)

**Local Development:**
- Volume-mounted source code for hot reloading
- Local SQLite database for testing
- Existing Rails credentials and master key

### Secrets Management

**Production:**
```bash
fly secrets set RAILS_MASTER_KEY=<encrypted_key>
# Anthropic API key accessed via Rails.credentials.anthropic[:api_key]
```

**Development:**
- Local `config/master.key` and `config/credentials.yml.enc`
- Docker Compose mounts existing files

## Deployment Components

### Docker Configuration

**Dockerfile:**
- Multi-stage build for optimized image size
- sqlite-vec native extension installation
- Asset precompilation and verification
- Health check endpoint setup

**Docker Compose:**
- `--profile production`: Test production image locally
- `--profile development`: Hot reload development environment
- Volume mounting for local development workflow

### Nginx Configuration

**Static Asset Serving:**
- Serve pre-built Vue.js files from `/var/www/public`
- Gzip compression and cache headers
- Security headers (CSP, HSTS, X-Frame-Options)

**API Proxy:**
- Proxy `/api/*` requests to Rails Unix socket
- Proper headers for Rails application
- Error handling and timeout configuration

### Rails Production Settings

**Database Configuration:**
- SQLite with sqlite-vec extension verification
- Connection pooling and timeout settings
- Persistent volume directory structure

**Background Jobs:**
- Solid Queue configuration for container environment
- Process isolation and restart policies
- Job retry and error handling

**Performance:**
- Production-level caching enabled
- Log formatting for Fly.io structured logs
- Memory and connection limits

## Deployment Workflow

### Local Testing

```bash
# Test production build locally
docker-compose up --profile production

# Development with hot reload
docker-compose up --profile development

# Access Rails console
docker-compose exec web rails c
```

### Production Deployment

```bash
# Deploy to Fly.io
fly deploy

# Set master key (only secret needed)
fly secrets set RAILS_MASTER_KEY=<key>

# Monitor deployment
fly logs
```

### Verification Steps

1. **Build Verification**: sqlite-vec extension loads correctly
2. **Health Checks**: `/health` endpoint responds properly
3. **Database**: SQLite operations work with vector search
4. **Frontend**: Vue.js application loads and functions
5. **API**: Chat and document endpoints work end-to-end

## Current Status (Phase 8 Implementation)

### Completed Components ✅
- **Dockerfile**: Multi-stage build with Nginx + Rails + sqlite-vec (0.1.6)
- **Production Procfile**: Process management for web (Nginx), rails, worker
- **Nginx Configuration**: Reverse proxy with security headers, gzip compression
- **Rails Production Config**: Unix socket, health checks, sqlite-vec verification
- **Docker Compose**: Production parity (single container) with development overrides
- **Fly.io Configuration**: ord region, persistent volumes, health checks, auto-scaling
- **Active Storage**: Configured for persistent volume (`/rails/storage`)
- **Deployment Scripts**: `script/setup-local` and `script/deploy` with error handling
- **Database Config**: Production SQLite on persistent volume with sqlite-vec extension
- **Application Validation**: All functionality tested in native development environment

### Current Blocker ⚠️
- **Cross-Platform Docker Testing**: Apple Silicon M1/M2/M3 Docker build fails due to platform mismatch
- **Issue**: Gemfile.lock has x86_64-linux variants but not aarch64-linux
- **Impact**: Cannot test complete Docker container locally on Apple Silicon
- **Solution Needed**: Docker buildx cross-platform building (linux/amd64 emulation)

### What's Been Tested ✅
- Rails application (all models, controllers, services)
- sqlite-vec extension (vector search with 9 chunk embeddings)
- API endpoints (authentication, documents, models, chats)
- Database operations and migrations
- Frontend build process (Vite + Vue.js)
- Authentication flow (login/logout/session management)

### What Needs Testing (After Docker Fix) 🔄
- Complete Docker container build and startup
- Nginx reverse proxy functionality
- Rails serving through Unix socket
- Health check endpoint in container environment
- Static asset serving through Nginx
- API endpoints through Nginx proxy
- Volume mounting and persistent data in container

### Next Steps
1. **Fix Docker buildx** for cross-platform building on Apple Silicon
2. **Test complete container** locally with cross-platform emulation
3. **Deploy to Fly.io** (production environment uses x86_64, should work)
4. **Complete Phase 8 documentation** and portfolio showcase

## Security Considerations

### Network Security
- All traffic through HTTPS (Fly.io automatic SSL)
- Nginx security headers configuration
- API endpoints properly secured

### Application Security
- Rails credentials encryption with master key
- Single secret (RAILS_MASTER_KEY) stored with Fly.io
- Environment variable isolation

### Data Protection
- Persistent volume encryption (Fly.io feature)
- Regular backup strategy for SQLite data
- Access logging and monitoring

## Monitoring & Maintenance

### Health Monitoring
- Fly.io health checks on `/health` endpoint
- Process monitoring and automatic restarts
- Log aggregation for debugging

### Performance Monitoring
- Response time tracking
- Memory usage monitoring
- Database performance metrics

### Update Process
- Zero-downtime deployments via Fly.io
- Database migrations handled automatically
- Asset versioning and cache busting

## Success Criteria

### Functional Requirements
- [ ] Document upload and processing works
- [ ] Vector search and RAG pipeline functional
- [ ] Chat interface with citations working
- [ ] Authentication gateway functional
- [ ] Responsive Vue.js frontend

### Technical Requirements
- [ ] Single Docker image runs locally and on Fly.io
- [ ] sqlite-vec extension works in production
- [ ] Persistent data survives deployments
- [ ] Health checks pass consistently
- [ ] Secrets management secure and functional

### Portfolio Requirements
- [ ] Publicly accessible URL
- [ ] Professional appearance and performance
- [ ] Reliable demonstration during interviews
- [ ] Clear documentation of architecture

## Next Steps

1. Implement Dockerfile and Docker Compose configuration
2. Configure Nginx with proper proxy settings
3. Set up Rails production configuration
4. Test locally with both profiles
5. Deploy to Fly.io and verify functionality
6. Set up monitoring and backup procedures

---

**Architecture Decision**: Single container with Nginx reverse proxy provides optimal balance of simplicity, reliability, and portfolio demonstration value while supporting both local development and production deployment workflows.