# Ragtime: Document Q&A System

![Tests](https://img.shields.io/badge/tests-222%20passing-brightgreen) ![Rails 8](https://img.shields.io/badge/rails-8.0.3-red) ![Vue.js](https://img.shields.io/badge/vue.js-3.x-green) ![License](https://img.shields.io/badge/license-MIT-blue)

A document Q&A system that demonstrates modern full-stack development skills with Rails 8, Vue.js, and AI-powered search.

## ✨ Features

- **📄 Document Upload**: Drag-and-drop PDF, TXT, DOCX, and MD files
- **🤖 AI-Powered Q&A**: Ask questions and get cited answers from your documents
- **🔗 Interactive Citations**: Click citations to view source passages in context
- **📊 Document Management**: Organize and search uploaded documents
- **🔒 Session Authentication**: Professional login flow for access control
- **📱 Responsive Design**: Works seamlessly on desktop and mobile devices

## 🚀 Live demo

**[Request access to live demo](https://ragtime-demo.fly.dev)** - Production-deployed and ready for review

> **Note**: The demo requires password authentication for security. This is a
> portfolio project demonstrating production-ready development practices.

## 🛠 Tech stack

### Backend
- **Rails 8** API with modern Ruby features
- **SQLite + sqlite-vec** for vector similarity search
- **Solid Queue** for background job processing (in-process via Puma)
- **OpenAI** integration for embeddings (text-embedding-3-small) and chat (gpt-4o-mini)

### Frontend
- **Vue.js 3** with Composition API
- **Vite** for fast development and building
- **Vue Router 4** for client-side navigation

### DevOps & Deployment
- **Docker** multi-stage containerization
- **Nginx** reverse proxy in production
- **Fly.io** deployment with persistent volumes
- **222 passing tests** with comprehensive coverage

## 📸 Screenshots

### Main Interface
![Main Interface](docs/screenshots/main-interface.png)
*Ragtime's main interface - upload documents, ask questions, get cited answers*

### Interactive Citations
![Citation Demo](docs/screenshots/citation-demo.png)
*Click citations to view source passages in document context*

### Mobile Responsive
![Mobile View](docs/screenshots/mobile-view.png)
*Responsive design that works on all devices*

## ⚡ Quick Start

### One-command Docker setup
```bash
git clone https://github.com/grymoire7/ragtime.git
cd ragtime
./script/rebuild-and-run
```
Visit http://localhost:8080 to access the application.

### Manual development setup

**Prerequisites**
- Ruby 3.3+
- Node.js 18+
- Docker (for container development)

**Setup instructions**
```bash
# Clone and setup
git clone https://github.com/grymoire7/ragtime.git
cd ragtime

# Backend setup
bundle install
bin/rails db:migrate
bundle exec rake vec_chunks:init

# Frontend setup
cd frontend
npm install
npm run build

# Start servers
cd ..
bin/rails server            # Backend (http://localhost:3000)
cd frontend && npm run dev  # Frontend (http://localhost:5173)
```

**Running tests**
```bash
# Backend tests
bundle exec rspec

# Frontend tests
cd frontend && npm run test
```

## 🏗 Architecture

### System overview
```
Vue.js Frontend ←→ Rails 8 API ←→ SQLite + sqlite-vec
                    ↓
              Solid Queue Jobs
                    ↓
              OpenAI APIs
```

### Key components

**Backend services**
- `ChunkRetriever`: Vector similarity search with cosine distance
- `PromptBuilder`: RAG prompt construction with document context
- `AnswerGenerator`: LLM integration with structured citation extraction
- `TextChunker`: Intelligent document chunking (800 tokens, 200 overlap)
- `EmbeddingGenerator`: Batch processing for vector embeddings

**Document processing pipeline**
1. **Upload**: Documents stored via Active Storage
2. **Extract**: Text extraction from PDF, TXT, DOCX, MD formats
3. **Chunk**: Intelligent segmentation with overlap for context
4. **Embed**: Vector generation using OpenAI text-embedding-3-small
5. **Store**: Chunks and embeddings in SQLite with vector search

### Technical decisions

| Decision | Rationale |
|----------|-----------|
| SQLite + sqlite-vec vs PostgreSQL + pgvector | Simplified deployment, single file, appropriate for demo scale |
| Rails 8 API vs monolith | Clean separation, modern frontend stack, API-first design |
| Vue.js SPA vs Hotwire | Better UX for chat interface, modern JavaScript skills |
| Solid Queue in-process vs Sidekiq | Deployment simplicity, Rails 8 integration |
| Single container vs microservices | Faster deployment, appropriate for project scope |

## 🧪 Testing

- **222 passing specs** with comprehensive test coverage
- **Unit tests** for all models and services
- **Integration tests** for complete RAG pipeline
- **API endpoint testing** for all controller actions
- **Frontend component tests** for Vue.js components

## 📚 Portfolio highlights

- **🐳 Production container**: Multi-stage Dockerfile with cross-platform builds (ARM64 → AMD64)
- **🚀 Real deployment**: Fly.io deployment with persistent volumes and health checks
- **📈 Error handling**: Comprehensive error handling, input validation, and graceful degradation
- **🔐 Security**: Session-based authentication, API key management, input sanitization
- **📝 Documentation**: Complete API docs, architecture docs, and development guides
- **🔧 Developer tools**: Convenient scripts for local development, debugging, and deployment

## 🔧 Development tools

**Convenient scripts**
```bash
./script/build-local      # Build cross-platform Docker container
./script/run-local        # Run container with proper Rails credentials
./script/rebuild-and-run  # Build and run in one command
./script/logs             # View container logs
./script/db-status        # Check database and vector table status
```

**Container access**
- Rails API: http://localhost:8080
- Vue.js Frontend: http://localhost:8080/frontend/
- Database: SQLite with persistent volume storage

## 📖 Documentation

- **[Blog post](https://tracyatteberry.com/blog/ragtime)** - Deep dive into architecture and technical decisions
- **[Portfolio](https://tracyatteberry.com/portfolio)** - Other projects and experience
- **[About](https://tracyatteberry.com/about)** - Background and contact information

## 🤝 Contributing

This is a portfolio project demonstrating professional development practices. While contributions aren't being accepted, the codebase serves as an example of:

- Clean, maintainable Rails 8 code
- Modern Vue.js frontend architecture
- Comprehensive testing strategies
- Production deployment practices
- Professional documentation standards

## 🤖 AI acknowledgment

Some portions of this project were assisted by AI tools for code generation and
documentation. All code and content have been reviewed and refined to ensure
quality and accuracy. This project was not "vibe coded" by AI; it reflects
professional development skills and practices. Claude Code was used with both
Sonnet and GLM models. See [blog post](https://tracyatteberry.com/blog/ragtime)
for more details about my challenges and learnings while using AI with this
project.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Built with ❤️ using Rails 8, Vue.js, and modern development practices**
