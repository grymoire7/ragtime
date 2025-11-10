# README Design Document

**Date**: 2025-11-09
**Project**: Ragtime - Document Q&A System
**Audience**: Portfolio reviewers, interviewers, hiring managers
**Purpose**: Executive summary + quick demo + technical details

## Design Goals

1. **Immediate Impact**: Capture attention within first 10 seconds
2. **Clear Value Proposition**: Show what it does and why it matters
3. **Easy Access to Demo**: Get hands-on experience quickly
4. **Technical Depth**: Demonstrate engineering competence
5. **Professional Polish**: Show attention to detail and quality

## Structure

### 0. Badges

See http://github.com/grymoire7/stormoji README.md (another portfolio site) for example.

Also add badge for "Tests (222) | passing" or similar.

### 1. Executive Summary (Above the Fold)

**Hook Line**
```
Ragtime: A production-ready document Q&A system built with Rails 8 and AI that demonstrates modern full-stack development skills.
```
Claude: This is a protfolio project, that purposefully doesn't scale. Perhaps "production-ready" is misleading?

**Value Proposition (3 bullet points)**
- Upload documents (PDF, TXT, DOCX, MD) and get instant AI-powered answers with source citations
- Built with Rails 8, Vue.js, and vector search - showcasing modern full-stack development
- Production-deployed with comprehensive tests and professional engineering practices

**Tech Stack Highlights**
- Rails 8 API backend with SQLite + sqlite-vec for vector search
- Vue.js 3 frontend with Vite and modern JavaScript
- OpenAI embeddings (text-embedding-3-small) and chat (gpt-4o-mini)
- Docker containerization with Nginx reverse proxy
- 222 passing tests with TDD approach

**Status & Demo Link**
- ✅ Production deployed and ready for review
- 🔗 [Live Demo](https://ragtime-demo.fly.dev) - Try it now
  - Claude: This requires a password. Maybe instead of "Try it now" it should say "Request access" or similar.
- 📱 Responsive design works on desktop and mobile

### 2. Quick Demo Section

*Key Features**
- 📄 **Document Upload**: Drag-and-drop PDF, TXT, DOCX, MD files
- 🤖 **AI Q&A**: Ask questions and get cited answers
- 🔗 **Interactive Citations**: Click citations to view source passages
- 📊 **Document Management**: Organize and search uploaded documents
- 🔒 **Session-based Authentication**: Professional login flow

**Screenshot Placeholder**
```
[SCREENSHOT: Main interface showing document upload, chat interface, and citation display]
Caption: Ragtime's main interface - upload documents, ask questions, get cited answers
```

**Quick Start for Interviewers**
```bash
# One-command setup (for interviewers who want to run locally)
git clone https://github.com/grymoire7/ragtime.git
cd ragtime
./script/rebuild-and-run
# Claude: This script assumes Docker. Perhaps we should have a script that simply runs the rails server and frontend?
# Visit http://localhost:8080
```

### 3. Technical Details Section

**Architecture Overview**
- Rails 8 API backend serving JSON endpoints
- Vue.js 3 SPA frontend with Vue Router
- SQLite database with sqlite-vec for vector similarity search
- Solid Queue for background job processing
- Nginx reverse proxy in production container

**Key Technical Decisions**

| Decision | Rationale | Senior-Level Thinking |
|----------|-----------|----------------------|
| SQLite + sqlite-vec vs PostgreSQL + pgvector | Simplified deployment, single file, sufficient for demo scale | Choose appropriate complexity for project scope |
| Rails 8 API vs monolith | Clean separation, modern frontend stack | API-first design for scalability |
| Vue.js SPA vs Hotwire | Better UX for chat interface, modern skills | Choose right tool for user experience |
| Solid Queue in-process vs Sidekiq | Simplified deployment, Rails 8 integration | Leverage new framework features |
| Single container vs microservices | Faster deployment, appropriate for scale | Avoid over-engineering |

Claude: When questioned, can I defend the statement that Vue.js provides a better UX for chat interfaces than Hotwire?

**Portfolio Highlights**
- 🧪 **222 Passing Tests**: Comprehensive test suite with TDD approach
- 🐳 **Production Container**: Multi-stage Dockerfile with cross-platform builds
- 🚀 **Deployed on Fly.io**: Real-world deployment with persistent volumes
- 📚 **Documentation**: Complete API docs, deployment guides, architecture docs
- 🔧 **Development Tools**: Convenient scripts for local development and debugging
- 📈 **Error Handling**: Comprehensive error handling and logging
- 🔐 **Security**: Input validation, API key management, session auth

### 4. For Developers (Optional Deep Dive)

**Development Setup**
```bash
# Prerequisites
#   - Ruby 3.3+
#   - Node.js 18+
#   - Docker (for container development)

# Setup
bundle install
bin/rails db:migrate
bundle exec rake vec_chunks:init
bin/rails server
cd frontend && npm run dev
```

Claude: We should also demonstrate how to run tests, both rspec and frontend tests.

**Key Architecture Components**
- `ChunkRetriever`: Vector similarity search with cosine distance
- `PromptBuilder`: RAG prompt construction with context
- `AnswerGenerator`: LLM integration with citation extraction
- `TextChunker`: Intelligent document chunking with overlap
- `EmbeddingGenerator`: Batch processing for vector embeddings

**Testing Strategy**
- Unit tests for all models and services
- Integration tests for RAG pipeline
- API endpoint testing
- Frontend component tests
- Cross-browser compatibility testing

## Screenshot Placeholders to Add

1. **Hero Image**: Main interface showing document upload and chat
2. **Citation Demo**: Interactive citations with document navigation
3. **Mobile View**: Responsive design on mobile device

### Maybe these are better suited for blog post?
4. **Architecture Diagram**: System components and data flow
5. **Code Sample**: Clean, well-documented code example
6. **Test Results**: Test suite output showing 222 passing specs

## Footer

- Link to blog post with more details
- Link to portfolio site (https://tracyatteberry.com/portfolio or similar)
- Link to About me page (https://tracyatteberry.com/about)

## Success Metrics

- Hiring manager understands project value within 10 seconds
- Clear path from interest to hands-on demo
- Technical depth is evident without overwhelming
- Professional quality is immediately apparent
- Easy to share with other team members

## Next Steps

1. Take screenshots of deployed application
2. Update placeholder links with actual demo URL -> https://ragtime-demo.fly.dev
3. Add repository link after making public -> https://github.com/grymoire7/ragtime (Claude: but this is the site they are viewig right now)
4. Consider adding short (2-3 min) video demo
5. Create PDF version for easy sharing in applications
   - Claude: Which applications? Do we need a PDF version of the README?
