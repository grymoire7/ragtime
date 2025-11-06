# Initial Design Plan for Document Q&A System

## Overview

Ragtime is a portfolio project to build a document Q&A system using
Retrieval-Augmented Generation (RAG). The goal is to allow users to upload
documents (PDFs, text files, Word docs), process them into vector embeddings,
and then ask questions that are answered based on the content of those
documents.

## Core architecture

Several architectural decisions are driven by the desire to get a working system
up and running quickly, while still demonstrating solid engineering practices.

**Backend: Rails 8 API**
- SQLite for both relational data and vector search (using sqlite-vec)
- Active Storage for document uploads
- Background jobs with Solid Queue (Rails 8 default) for document processing
- Anthropic API for embeddings (voyage-3.5-lite) and chat completion (claude-3-5-haiku-latest)
- [RubyLLM](https://github.com/crmne/ruby_llm) gem for LLM integration

**Frontend: Vue.js 3 (Composition API)**
- Vite for build tooling
- File upload with progress indication
- Chat interface for Q&A
- Document library with metadata

**ActionCable decision: Skip it for now**

I'd recommend starting without ActionCable and adding it only if time permits. Here's why:

**Simple HTTP approach (start here):**
- Send question via POST request
- Show loading state while waiting for response
- Display complete answer when it arrives
- Takes 1-2 days to implement solidly

**ActionCable streaming (add if time allows):**
- Real-time token-by-token streaming of responses
- Better UX but adds complexity in error handling, reconnection logic, and testing
- Takes 3-4 additional days to implement well

Given your tight timeline, you need a working end-to-end system first. If you
finish early, streaming is a great polish feature.


## Phased breakdown

**Phase 1: Foundation and document processing** ✅ COMPLETE
- Set up Rails 8 project with sqlite-vec
  - This required `gem install sqlite-vec` to get the native extension working locally.
    How do we handle this in deployment?
- Implement document upload (PDF, TXT, DOCX support)
- Build text extraction pipeline (pdf-reader gem, docx gem)
- Create chunking strategy (target 500-1000 tokens per chunk with overlap)
  - **Note**: Implemented with semantic awareness from the start (respects paragraphs → sentences → words)
- Generate embeddings for chunks (Anthropic Voyage 3.5 Lite)
- Store vectors in SQLite

**Phase 2: Basic RAG implementation** ✅ COMPLETE
- Build vector similarity search
- Implement simple retrieval (top-k chunks)
- Create prompt template for answering questions
- Build basic Rails API endpoint for Q&A
- Add conversation history tracking

**Phase 3: Vue.js frontend foundation** ✅ COMPLETE
- Set up Vite + Vue 3 project
- Build document upload interface with drag-and-drop
- Create document library view (list uploaded docs)
- Show processing status for documents
- Basic chat interface (polling-based, no streaming)

**Phase 4: Improve retrieval and citations** ✅ COMPLETE
- ✅ Add date filtering (created_after parameter for recent documents)
- ✅ Implement citation storage (metadata JSON column on messages)
- ✅ Track which chunks were used (chunk_id, document_id, relevance, position)
- ✅ Show source references in answers (inline footnote style below messages)
- ✅ Comprehensive test coverage for new features
- ⏭️ **Deferred to Phase 5**: Jump-to-document/chunk links (IDs stored, links not yet implemented)
- ❌ **Not needed**: Chunking semantic awareness (already implemented in Phase 1)

**Phase 5: Interactive citations and document navigation** ✅ COMPLETE
- ✅ Add clickable citation links that jump to source documents
- ✅ Implement document detail view showing chunks
- ✅ Add chunk highlighting in document view
- ✅ **Add frontend UI for date filtering** (backend already implemented in Phase 4)
  - ✅ "Recent documents only" checkbox (last 7 days)
  - ✅ Pass `created_after` parameter to MessagesController
  - ✅ Update ChatInterface to show active filters
  - ✅ Vue Router integration for navigation
- ⏭️ Consider: Document preview modal from citations (deferred to Phase 9)
- ⏭️ Consider: Citation tooltips showing chunk content on hover (deferred to Phase 9)

**Phase 6: Polish and error handling** ✅ COMPLETE
- ✅ Handle edge cases (empty documents, unsupported formats)
- ✅ Add proper error messages throughout UI
- ✅ Implement conversation clearing/management
- ✅ Add document deletion functionality (completed in Phase 5)
- ✅ Improve loading states and user feedback
- ✅ Add basic authentication (session-based shared password gate)
  - Shared password stored in Rails credentials (provided to recruiters)
  - Professional login page with gradient design
  - Session-based auth with Vue router guards
  - Prevents AI API abuse while allowing recruiter access
  - Comprehensive test coverage (13 auth specs)

**Phase 7: Testing and refinement** ✅ COMPLETE
- ✅ Core regression tests implemented (222 total specs passing)
  - Document model tests for chunk ordering (guards against display bugs)
  - DocumentDetailView tests for chunk highlighting and visibility
  - ChatInterface tests for citation formatting
  - Authentication flow tests (login, logout, session management)
  - Bug fixes: auth proxy routing, login redirect, UI visibility issues
- ✅ Prompt quality validation
  - RAG prompt includes strict citation guidelines
  - Clear instructions to avoid hallucination and irrelevant citations
  - Relevance scoring displayed to users (0-1 scale)
- ✅ Manual testing and quality validation
  - Upload and test various document types (PDF, TXT, DOCX, MD)
  - Verify RAG pipeline produces accurate, cited answers
  - Test edge cases: empty documents, large documents, special characters
  - Validate citation links navigate correctly to source documents
  - Test date filtering functionality with multiple documents
  - Cross-browser validation (Chrome, Firefox, Safari)
- ✅ Integration tests for RAG pipeline (ChunkRetriever → PromptBuilder → AnswerGenerator)
  - Factory-based test documents with predictable embeddings
  - Complete end-to-end pipeline flow validation
  - Vector search, prompt building, and answer generation testing
  - Empty context handling and error scenario validation
  - 12 new integration examples with 0 failures
- 🔄 Deferred for future (see Testing Strategy section below)
  - E2E tests with Capybara or Playwright for user workflows
  - RAG quality metrics and optional VCR-based LLM regression tests
  - Performance tests for vector search at scale
  - Automated cross-browser testing

**Phase 8: Deployment and documentation**
- Deploy to Fly.io or Render
- Solve sqlite-vec native extension deployment
- Write comprehensive README with setup instructions
- Create demo video or GIF showing key features
- Document environment variable configuration
- Write technical blog post explaining architecture

**Phase 9: Optional enhancements** (if time permits)
- Replace dollar sign with piano (🎹) symbol as app icon
- ActionCable streaming for real-time responses
- Advanced UI/UX polish
- Document preview or PDF viewer
- Multi-document conversations with filtering UI
- Export conversation history
- Advanced analytics (popular questions, document usage)

## Risk mitigation

**Biggest risks to timeline:**
1. **Document parsing complexity** - Start with just PDF and TXT, add DOCX only if time permits
2. **Embedding API costs** - Use smaller batches, cache aggressively, set budget alerts
3. **Vector search performance** - Test with ~100 documents max for portfolio; acknowledge scaling considerations in docs
4. **Scope creep** - Resist adding features like multi-user support, document versioning, or advanced analytics

**Critical path items (must have):**
- Upload PDF → chunk → embed → search → answer with citations
- Clean, working demo you can show in interviews
- Deployed somewhere publicly accessible

**Nice-to-have (cut if needed):**
- Multiple document format support
- Conversation history persistence
- ActionCable streaming
- Document preview
- Advanced filtering

## Testing strategy

### Implemented tests (high value-to-effort ratio)

**Backend unit tests (41 specs passing)**
- Document model: chunk ordering, associations, validations, status transitions
- Chunk model: vector search, embeddings, position tracking
- RAG services: ChunkRetriever with date filtering, PromptBuilder formatting, AnswerGenerator citation extraction
- Document processing: TextExtractor, TextChunker, EmbeddingGenerator
- Controllers: Documents, Chats, Messages endpoints

**Frontend unit tests (20 specs passing)**
- DocumentDetailView: chunk highlighting, visibility filtering, "Show all context" toggle
- ChatInterface: citation formatting with chunk position, relevance score display, metadata checks

These tests provide rapid feedback on regressions in critical bugs we encountered:
1. Chunk ordering breaking document display
2. Wrong chunks being highlighted
3. Citation titles being indistinguishable for same-document chunks

### Deferred tests (documented for future implementation)

**Integration tests for RAG pipeline**
- Full flow: question → vector search → prompt building → LLM call → citation extraction
- Date filtering end-to-end behavior
- Citation renumbering when LLM skips citation numbers
- Error handling when no relevant chunks found

**E2E tests with Capybara or Playwright**
- Upload document → wait for processing → ask question → verify cited answer
- Navigate to document detail → verify correct chunk highlighted
- Toggle date filter → verify filtered results
- Multi-document conversations with different relevance thresholds

**RAG quality metrics (optional)**
- Precision/recall of chunk retrieval vs golden dataset
- Citation accuracy (cited chunks actually contain answer)
- LLM response quality benchmarks
- Optional: VCR-based LLM regression tests (record/replay LLM responses for deterministic testing)

**Performance tests**
- Vector search latency with 100+ documents
- Concurrent chat requests handling
- Memory usage during document processing
- Embedding generation batch optimization

**Cross-browser testing**
- Chrome, Firefox, Safari compatibility
- Mobile responsive design validation
- Citation link navigation on touch devices

### Testing philosophy for this project

Given the portfolio project timeline, we prioritized:
1. **Fast unit tests** that catch regressions in bugs we actually encountered
2. **Critical path coverage** for chunk ordering and citation display logic
3. **Defer expensive tests** until the system proves valuable in production

This approach balances quality with velocity—we have safety nets for known failure modes without gold-plating test coverage for hypothetical issues.

## My honest assessment

This is ambitious but doable in a short time if you:
- Start with the simplest version of each feature
- Don't get stuck perfecting chunking algorithms
- Use off-the-shelf components where possible (Vue component libraries)
- Deploy early (phase 5) and often

The ActionCable streaming is genuinely optional. A fast, reliable non-streaming
version is better than a buggy streaming one. You can always add it as a
"future enhancement" and discuss the tradeoff in interviews - that shows good
judgment.

