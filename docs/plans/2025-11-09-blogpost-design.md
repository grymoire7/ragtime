# Blogpost Design Document

**Date**: 2025-11-09
**Project**: Ragtime - Document Q&A System
**Target Audience**: Technical Hiring Managers (Senior Software Developer position)
**Purpose**: Technical portfolio piece demonstrating senior-level engineering skills

## Design Goals

1. **Technical Depth**: Demonstrate senior-level architectural thinking
2. **Problem-Solving**: Show approach to complex technical challenges
3. **Trade-off Analysis**: Evidence of thoughtful decision-making
4. **Production Awareness**: Real-world deployment and operational concerns
5. **Communication Skills**: Clear explanation of technical concepts
6. **Leadership Qualities**: System design thinking beyond just coding

## Working Titles

- "Building a document Q&A system with Rails 8, SQLite-vec, and OpenAI" (top choice)
- "Building a RAG System from Architecture to Deployment" (second choice)

## Blogpost Structure

### 1. Introduction (Hook the Hiring Manager)

**Opening Hook**
- Start with the AI/RAG context: "Every company is trying to figure out how to integrate AI with their proprietary data..."
- Establish the problem: "But building production-ready RAG systems requires more than just calling an API"

**Project Goal Statement**
- "I built Ragtime as a portfolio piece that demonstrates senior-level software engineering skills"
- "Not just a toy project - a production-deployed system with proper architecture, testing, and operational considerations"

**Thesis Statement**
- "This post covers the architecture, design decisions, and trade-offs that show how a senior engineer approaches building modern AI-powered applications"

**Key Skills to Demonstrate Upfront**
- System architecture and design patterns
- Technology selection and trade-off analysis
- Production deployment and operations
- Code quality and testing methodologies
- AI systems integration and knowledge of vector search
  - Claude: Knowledge of AI technologies if very desirable for senior roles these days.

### 2. The Architecture: Senior-Level System Design

**High-Level Architecture Overview**
```
[BLOCK DIAGRAM PLACEHOLDER]
Vue.js Frontend ←→ Rails 8 API ←→ SQLite + sqlite-vec
                    ↓
              Solid Queue Jobs
                    ↓
              OpenAI APIs
```

**Component Deep Dive**

**Rails 8 API Backend**
- Why Rails 8 for a portfolio project (new features, modern Ruby)
- API-only design vs traditional monolith
- Controller structure: Documents, Chats, Messages, Models
- Service layer architecture for complex business logic

**Vector Storage Strategy**
- SQLite + sqlite-vec vs PostgreSQL + pgvector vs dedicated vector DBs
- Decision matrix: deployment simplicity vs scalability vs performance
- Why sqlite-vec was the right choice for this project scope
- Vector similarity implementation and challenges

**Frontend Architecture**
- Vue.js 3 + Composition API vs React vs Svelte
- SPA vs Hotwire vs Server-rendered
- State management for chat interfaces
- Real-time considerations (why polling instead of WebSockets)

### 3. Technical Challenges & Senior-Level Solutions

**Challenge 1: Document Processing Pipeline**
- Problem: Converting diverse formats (PDF, DOCX, TXT, MD) to searchable text
- Solution: Modular TextExtractor service with error handling
- Senior thinking: Extensibility for new formats, failure recovery

**Challenge 2: Intelligent Text Chunking**
- Problem: How to chunk documents for optimal RAG retrieval
- Solution: 800-token chunks with 200-token overlap, paragraph boundary preservation
- Senior thinking: Token counting accuracy, context preservation, retrieval optimization

**Challenge 3: Vector Search Implementation**
- Problem: Efficient similarity search with cosine distance
- Solution: sqlite-vec virtual tables with L2 distance tuning
- Senior thinking: Similarity thresholds, performance vs accuracy trade-offs

**Challenge 4: Background Job Architecture**
- Problem: Processing documents without blocking user experience
- Solution: Solid Queue with in-process Puma integration
- Senior thinking: Why not Sidekiq? Deployment simplicity vs scalability

**Challenge 5: Citation Extraction & Storage**
- Problem: Making AI answers verifiable and trustworthy
- Solution: Structured citation metadata with document references
- Senior thinking: User trust, information verification, conversation replay

### 4. Code Quality: Engineering Discipline

**Test-Driven Development Approach**
- 222 passing specs across unit, integration, and API tests
- RAG pipeline integration testing (ChunkRetriever → PromptBuilder → AnswerGenerator)
- Mock strategies for external APIs (OpenAI)
- Edge case handling: malformed documents, API failures, empty results

**Code Organization**
```
# Show high-level code organization here, though we can assume some knmowledge of Rails conventions
app/services/rag/chunk_retriever.rb - Clean service interface
app/services/document_processing/ - Modular pipeline
app/jobs/ - Background job patterns
spec/ - Test organization and fixtures
```

**Error Handling & Resilience**
- Graceful degradation when AI APIs are unavailable
- Input validation and sanitization
- Database transaction management
- Logging and monitoring strategy

**Performance Considerations**
- Vector search optimization (batch processing, indexing)
- Frontend performance (lazy loading, pagination)
- Background job throttling
- Memory management for document processing

### 5. Production Deployment: Operations Mindset

**Container Strategy**
- Multi-stage Dockerfile optimization
- Cross-platform builds (ARM64 → AMD64)
- Nginx reverse proxy configuration
- Asset compilation and serving

**Deployment Architecture**
```
[DEPLOYMENT DIAGRAM PLACEHOLDER]
Fly.io Platform → Docker Container → Nginx → Rails Puma → SQLite DB
     ↓              ↓                      ↓           ↓
Persistent Volumes  Health Checks   Background Jobs  Active Storage
```

**Operational Concerns**
- Database migrations and schema management
- Environment variable and secrets management
- Logging and error tracking strategy
- Backup and recovery considerations

**Monitoring & Observability**
- Health check endpoints
- Structured logging patterns
- Error alerting strategies
- Performance monitoring setup

### 6. Senior-Level Trade-off Analysis
Claude: In general, we should avoid the term "senior thinking" or
  "senior-level". We can just say "Rationale" or "Considerations".
  We want to _demonstrate_ senior-level thinking through the content,
  not call it out explicitly all the time.

**Technology Selection Matrix**

| Technology | Chosen | Rejected | Why | Senior Thinking |
|------------|--------|----------|-----|-----------------|
| Vector DB | sqlite-vec | pgvector, Pinecone | Simplicity vs scalability | Right-sized solution for project scope |
| Job Queue | Solid Queue | Sidekiq, Resque | Rails integration vs ecosystem maturity | Leverage framework features |
| Frontend | Vue.js | React, Hotwire | Modern SPA vs Rails native | Best tool for user experience |
| Deployment | Single Container | Microservices | Deployment speed vs operational complexity | Avoid over-engineering |

**Architecture Decisions**

**API-First Design**
- Why: Clean separation, mobile readiness, team scalability
- Trade-off: More complex than monolith

**SQLite for Production**
- Why: Simplified deployment, sufficient for demo scale
- Trade-off: Limited scalability vs PostgreSQL

**In-Process Background Jobs**
- Why: Solid Queue + Puma integration, deployment simplicity
- Trade-off: Less isolation than separate workers

**What I'd Do Differently at Scale**
- Move to PostgreSQL + pgvector for larger datasets
  - While SQLite can scale to moderate sizes, the sqlite-vec extension has proven to be somewhat finicky for implementation and maintenance.
- Separate background job workers for better isolation
- CDN for static assets
- Proper monitoring stack (Prometheus, Grafana)

### 7. Lessons Learned: Growth Mindset

**Technical Learnings**
- sqlite-vec limitations and workarounds
- Rails 8 new features in production
- Vector similarity tuning challenges
- Container build optimization techniques

**Process Learnings**
- Value of comprehensive test coverage
- Importance of deployment automation
- Documentation as a design tool
- Why README-driven development matters

**Leadership Insights**
- Balancing technical excellence with project scope
- Making decisions that scale with team size
- Operational thinking beyond just code
- Communication skills through documentation

### 8. Conclusion: Demonstrating Senior-Level Value

**Technical Capabilities Summary**
- System architecture and design patterns
- Modern full-stack development (Rails 8 + Vue.js)
- AI/ML integration with production considerations
- DevOps and deployment expertise
- Testing methodology and code quality

**Business Value Demonstration**
- Problem-solving approach to complex challenges
- Trade-off analysis and decision-making framework
- Production awareness and operational thinking
- Communication skills through clear documentation

**Call to Action for Hiring Managers**
- Link to live demo: [Demo URL]
  - Claude: Mention that password is required.
- GitHub repository: https://github.com/grymoire7/ragtime
- Resume and contact information: https://tracyatteberry.com/about
- Link to portfolio website: https://tracyatteberry.com/portfolio
- "This is a sample of the technical leadership and engineering excellence I would bring to your team"

## Code Snippets to Include

1. **Clean Service Interface** (ChunkRetriever)
2. **Background Job Pattern** (ProcessDocumentJob)
3. **Test Example** (RAG pipeline integration test)
4. **Error Handling Pattern** (API controller rescue blocks)
5. **Docker Optimization** (Multi-stage Dockerfile)
6. **Vue.js Composition API** (Clean component structure)

## Screenshots/Diagrams to Create

1. **Architecture Diagram**: System components and data flow
2. **RAG Pipeline Flow**: Document → Chunks → Embeddings → Query → Response
3. **Database Schema**: Tables, relationships, vector storage
4. **Deployment Architecture**: Container stack and infrastructure
5. **Test Results**: Spec output showing comprehensive coverage
6. **Production Interface**: Working demo of key features
7. **Code Quality Example**: Well-documented, clean code sample

## Success Metrics for Hiring Managers

- Understands system architecture beyond just coding
- Demonstrates thoughtful technology selection
- Shows awareness of production considerations
- Communicates technical concepts clearly
- Exhibits senior-level problem-solving approach
- Balances technical excellence with practical constraints
- Shows leadership potential through decision-making framework

## SEO and Sharing Considerations

- Keywords: "Senior Software Engineer", "RAG system", "Rails 8", "AI integration", "system architecture"
- Tweetable insights about technical decisions
- LinkedIn-friendly technical depth
- Shareable diagrams and code examples
- Mobile-responsive formatting

## Publication Strategy

- Target audience: Technical hiring managers, engineering leaders
- Platform choices: LinkedIn, technical blogs, personal/portfolio website
- Cross-posting strategy to maximize reach
- Follow-up content ideas (deeper dives on specific topics)
