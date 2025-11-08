# Ragtime - Document Q&A System

## Project Overview

Ragtime is a portfolio project demonstrating a Retrieval-Augmented Generation
(RAG) system built with Rails 8 and Vue.js. Users can upload documents (PDFs,
TXT, DOCX), which are processed into vector embeddings, enabling Q&A based on
document content.

**Project Goal**: Create a working, deployable document Q&A system showcasing
solid engineering practices and modern AI integration.

## Current Status

**Completed Phases**:
- ✅ Phase 1: Foundation and document processing
- ✅ Phase 2: Basic RAG implementation
- ✅ Phase 3: Vue.js frontend foundation
- ✅ Phase 4: Improved retrieval and citations
- ✅ Phase 5: Interactive citations and document navigation
- ✅ Phase 6: Polish and error handling

**Phase 6 Achievements**:
- Session-based authentication with shared password gate
- Professional login page with Vue router guards
- Authentication bug fixes (proxy routing, login redirect flow)
- UI improvements (logout button, delete icon visibility)
- Comprehensive test coverage (222 specs passing)

**Phase 7 Completed** (Testing and refinement):
- ✅ Core regression tests implemented (222 specs passing)
- ✅ Prompt quality validation
- ✅ Manual testing with various document types (Option A approach)
- ✅ Quality validation of RAG pipeline
- ✅ Integration tests for RAG pipeline (ChunkRetriever → PromptBuilder → AnswerGenerator)
- ⏸️ Integration/E2E tests deferred (reasonable for portfolio scope)

**Phase 8 In Progress** (Deployment and documentation):
- ✅ Multi-stage Dockerfile created with Nginx reverse proxy
- ✅ Production Procfile and Rails configuration for containers
- ✅ Docker Compose with production parity (single container)
- ✅ Fly.io deployment configuration (ord region, persistent volumes)
- ✅ Active Storage configured for persistent volume
- ✅ Production database configuration for persistent volume
- ✅ sqlite-vec extension loading fixed in production containers
- ✅ Docker buildx cross-platform compatibility (ARM64 → AMD64)
- ✅ Database initialization automation in container startup
- ✅ Rails credentials integration (RAILS_MASTER_KEY)
- ✅ Convenient development scripts created
- ✅ Solid Queue working with in-process execution (Puma plugin)
- ✅ RubyLLM model registry configuration fixed for production
- ✅ OpenAI embeddings integration (text-embedding-3-small, 1536 dimensions)
- ✅ Document upload and processing working in container
- ⚠️ Chat creation endpoint has validation issue (422 error)
- 🔄 Next: Fix chat creation, then deploy to Fly.io

**Next Phases**:
- Phase 8: Complete deployment and documentation
- Phase 9: Optional enhancements

## Technology Stack

### Backend (Rails 8 API)
- **Framework**: Rails 8.0.3
- **Database**: SQLite3 (≥2.1) for relational data
- **Vector Search**: sqlite-vec (0.1.6) for vector similarity search
- **File Storage**: Active Storage for document uploads
- **Background Jobs**: Solid Queue (Rails 8 default, in-process via Puma plugin)
- **LLM Integration**: ruby_llm gem (1.9)
- **Production Embedding API**: OpenAI text-embedding-3-small (1536 dimensions)
- **Production Chat API**: OpenAI gpt-4o-mini
- **Development**: Anthropic Claude 3.5 Haiku (chat), Ollama jina-embeddings (512 dimensions)

### Document Processing
- **PDF**: pdf-reader gem
- **DOCX**: docx gem
- **Token Counting**: tiktoken_ruby for chunking

### Frontend
- Vue.js 3 with Composition API
- Vue Router 4 for client-side navigation
- Vite for build tooling
- Polling-based chat interface (no ActionCable streaming)
- Interactive citations with document navigation
- Date filtering UI for recent documents

## Architecture

### Models

**Document** (`app/models/document.rb`)
- Represents uploaded documents
- Has attached file via Active Storage
- Has many chunks
- Tracks processing status

**Chunk** (`app/models/chunk.rb`)
- Text segments from processed documents
- Stores vector embeddings as BLOBs
- Belongs to document
- Contains metadata (position, token count)
- Implements vector similarity search using sqlite-vec

**Chat** (`app/models/chat.rb`)
- Conversation container
- Has many messages
- Tracks conversation history

**Message** (`app/models/message.rb`)
- Individual chat messages
- Belongs to chat
- Stores role (user/assistant), content, and metadata

**Model** (`app/models/model.rb`)
- Available LLM models
- Tracks capabilities and parameters

**ToolCall** (`app/models/tool_call.rb`)
- Function calls made by LLM
- Tracks tool execution results

### Controllers

**DocumentsController** (`app/controllers/documents_controller.rb`)
- `GET /documents` - List all documents
- `POST /documents` - Upload new document (triggers ProcessDocumentJob)
- `GET /documents/:id` - Show document details
- `DELETE /documents/:id` - Delete document and chunks

**ChatsController** (`app/controllers/chats_controller.rb`)
- `GET /chats` - List chats
- `POST /chats` - Create new chat
- `GET /chats/:id` - Show chat with messages

**MessagesController** (`app/controllers/messages_controller.rb`)
- `POST /chats/:chat_id/messages` - Send message and get AI response

**ModelsController** (`app/controllers/models_controller.rb`)
- `GET /models` - List available models
- `POST /models/refresh` - Refresh model list

### Services

#### Document Processing (`app/services/document_processing/`)

**TextExtractor** - Extracts text from uploaded documents
- Supports PDF, TXT, DOCX formats
- Returns raw text content

**TextChunker** - Splits text into manageable chunks
- Target: 500-1000 tokens per chunk
- Maintains 200 token overlap for context continuity
- Uses tiktoken for accurate token counting
- Preserves paragraph boundaries

**EmbeddingGenerator** - Creates vector embeddings
- Production: Uses OpenAI text-embedding-3-small (1536 dimensions) via ruby_llm
- Development: Uses Ollama jina-embeddings-v2-small-en (512 dimensions)
- Processes chunks in batches
- Stores embeddings in SQLite as BLOBs

#### RAG Services (`app/services/rag/`)

**ChunkRetriever** - Finds relevant document chunks
- Uses vector similarity search (cosine distance)
- Returns top-k most relevant chunks
- Configurable similarity threshold
- **Phase 4**: Date filtering via `created_after` parameter

**PromptBuilder** - Constructs RAG prompts
- Combines retrieved chunks with user question
- Formats context for LLM
- Includes instructions for citation and grounding
- Shows relevance scores for each chunk

**AnswerGenerator** - Generates responses
- Production: Uses OpenAI gpt-4o-mini
- Development: Uses Anthropic Claude 3.5 Haiku
- Implements RAG pattern with retrieved context
- **Phase 4**: Returns structured citations with metadata
  - chunk_id, document_id, document_title
  - relevance score (0-1)
  - chunk position in document

### Background Jobs

**ProcessDocumentJob** (`app/jobs/process_document_job.rb`)
- Extracts text from uploaded document
- Chunks text into segments
- Generates embeddings for each chunk
- Updates document processing status

**ChatResponseJob** (`app/jobs/chat_response_job.rb`)
- Handles async chat message processing
- Retrieves relevant chunks via RAG
- Generates AI response with citations
- Creates message record with citation metadata
- **Phase 4**: Stores citations in message.metadata JSON field

## Database Schema

### Vector Storage
Chunks table includes:
- `embedding` (BLOB) - Vector embeddings stored as binary
- SQLite virtual table `vec_chunks` with vec0 extension for similarity search
- Production: 1536 dimensions (OpenAI text-embedding-3-small)
- Development: 512 dimensions (Ollama jina-embeddings-v2-small-en)
- Uses cosine distance for similarity matching

### Citation Storage (Phase 4)
Messages table includes:
- `metadata` (JSON) - Stores citation information with default `{}`
- Citation format: `{ citations: [{ chunk_id, document_id, document_title, relevance, position }] }`
- Enables conversation replay with source attribution
- SQLite supports JSON natively (since 3.38)

### Key Relationships
- Document → has_many Chunks
- Chat → has_many Messages
- Chunks store references back to parent Document
- Messages store citation metadata in JSON column

## Configuration

### Environment Variables Required (via Rails Credentials)
- `OPENAI_API_KEY` - For production embeddings (text-embedding-3-small) and chat (gpt-4o-mini)
- `ANTHROPIC_API_KEY` - For development chat (Claude 3.5 Haiku)
- Development embeddings use local Ollama (no API key needed)

### SQLite Extensions
- **sqlite-vec**: Requires native extension installation
  - Development: `gem install sqlite-vec`
  - Production: Deploy consideration needed
  - IMPORTANT: sqlite-vec does not support transactions; avoid wrapping vector operations in transactions.

## Development Workflow

### Setup
```bash
bundle install
bin/rails db:migrate
bin/rails db:seed  # If seed data exists
```

### Running Tests
```bash
bundle exec rspec
```

### Starting Server
```bash
bin/rails server
```

### Background Jobs
Solid Queue runs automatically in development mode.

### Docker Development Scripts

For convenient local testing with Docker containers:

**Build and Run Container:**
```bash
# Build and run in one command
./script/rebuild-and-run

# Or step by step
./script/build-local
./script/run-local
```

**Individual Scripts:**
- `script/build-local` - Builds the cross-platform Docker container
- `script/run-local` - Runs the container with proper Rails credentials
- `script/rebuild-and-run` - Combines both build and run operations

**Container Access:**
- Rails API: http://localhost:8080
- Vue.js Frontend: http://localhost:8080/frontend/
- View logs: `docker logs ragtime-test`
- Follow logs: `docker logs -f ragtime-test`
- Stop container: `docker stop ragtime-test`

## Implementation Details

### Chunking Strategy
- Target chunk size: 800 tokens (~600 words)
- Overlap: 200 tokens between chunks
- Preserves paragraph boundaries
- Maintains context continuity

### Vector Search
- Uses sqlite-vec's `vec_distance_cosine` function
- Typical query retrieves top-5 chunks
- Similarity threshold prevents low-quality matches

### RAG Prompt Pattern
1. Retrieve relevant chunks via vector search
2. Format chunks as context
3. Construct prompt with context + question
4. Instruct LLM to answer only from context
5. Request citations to source documents

## Design Decisions

### Why SQLite + sqlite-vec?
- Fast to set up, single-file database
- sqlite-vec provides native vector search
- Sufficient for portfolio/demo scale (~100 documents)
- Simplifies deployment (no separate vector DB)

### Why Skip ActionCable Initially?
- Simple HTTP approach faster to implement (1-2 days vs 3-4 days)
- Reliable non-streaming > buggy streaming
- Can add as Phase 8 enhancement if time permits
- Shows good judgment on MVP vs polish

### API Provider Strategy
- **Production**: OpenAI for both embeddings and chat
  - Consolidates API costs under single provider
  - text-embedding-3-small: cost-effective, high-quality embeddings (1536 dims)
  - gpt-4o-mini: fast, efficient chat model
- **Development**: Anthropic + Ollama
  - Claude 3.5 Haiku for high-quality chat responses
  - Ollama jina-embeddings: free local embeddings (512 dims)
- ruby_llm gem (1.9) provides unified interface across providers

### Solid Queue Configuration (Phase 8)
- Uses in-process execution via Puma plugin (`SOLID_QUEUE_IN_PUMA=1`)
- Single database for both app data and queue (simplified deployment)
- Avoids separate queue database complexity
- Migration-based table creation for reliable container initialization
- **Critical**: RubyLLM model registry must use JSON files, not database (`model_registry_class = nil`)

## Known Limitations & Future Enhancements

### Current Limitations
- No real-time streaming responses
- Limited to ~100 documents for performance
- Basic authentication not yet implemented
- Single-user focused

### Completed Enhancements (Phase 4)
- ✅ Citation extraction and storage
- ✅ Source attribution in answers
- ✅ Date-based document filtering
- ✅ Relevance scores for citations

### Planned Enhancements (Phases 5-9)
- Phase 5: Date filtering UI controls (backend ready, needs frontend)
- Phase 5: Clickable citation links to documents
- Phase 5: Document detail view with chunks
- Phase 5: Chunk highlighting in document view
- Phase 6: Document preview/viewer
- Phase 6: Conversation management (clear, delete)
- Phase 6: Basic authentication
- Phase 9: ActionCable streaming (optional)
- Phase 9: Advanced UI/UX polish (optional)

## Testing Strategy

### Current Test Coverage (Phase 7)
- ✅ Comprehensive test suite (222 specs passing)
- ✅ Document processing pipeline with edge cases
- ✅ Vector search with date filtering
- ✅ ChunkRetriever with created_after parameter
- ✅ AnswerGenerator citation metadata
- ✅ Relevance score calculation
- ✅ Authentication flow (login, logout, session management)
- ✅ Document model tests for chunk ordering
- ✅ Edge cases (nil documents, empty results, errors)

### Completed Test Expansion (Phase 7)
- ✅ API endpoint integration tests for RAG pipeline (ChunkRetriever → PromptBuilder → AnswerGenerator)
- ✅ RAG answer quality validation
- ✅ Various document formats and sizes
- ✅ Frontend component testing
- ✅ Cross-browser compatibility

## Deployment Considerations

### Target Platforms
- Fly.io or Render
- Single-region deployment

### Production Requirements
- sqlite-vec native extension availability
- Environment variable configuration
- Active Storage backend (local disk initially)
- Background job worker process

## API Usage Examples

### Upload Document
```bash
POST /documents
Content-Type: multipart/form-data

file: <document_file>
```

### Ask Question
```bash
POST /chats/:chat_id/messages
Content-Type: application/json

{
  "message": {
    "content": "What is the main topic discussed?"
  }
}
```

### List Documents
```bash
GET /documents
```

## Project Timeline Approach

Focus on getting core functionality working end-to-end before polish:
1. ✅ Document upload → chunk → embed → search works
2. ✅ Q&A with citations functional
3. ✅ Vue.js frontend built (Phase 3)
4. ✅ Citations improved and displayed (Phase 4)
5. **Next**: Interactive citations and navigation (Phase 5)
6. **Then**: Polish, testing, and deployment (Phases 6-8)

**Current Status**: Core RAG system is functional with authentication, citations, and interactive features.
  Phase 6 complete. Phase 7 complete. Phase 8 deployment in progress.

**Tests**: Comprehensive test suite (222 specs passing) covering core functionality and RAG pipeline.
  sqlite-vec limitations required careful test design. We unit test with rspec.

**Critical Path**: Working demo that's deployable and interview-ready ✅
**In Progress**: Cross-platform Docker testing and Fly.io deployment (Phase 8)
**Next**: Complete deployment and documentation (Phase 8)
**Nice-to-Have**: Streaming (Phase 9), advanced features, extensive test coverage

## Resources

- Design document: `docs/initial-design.md`
- Rails guides: https://guides.rubyonrails.org
- ruby_llm gem: https://github.com/crmne/ruby_llm
- sqlite-vec: https://github.com/asg017/sqlite-vec
- solid queue has its own database: storage/production_queue.sqlite3