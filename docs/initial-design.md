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

**Phase 1: Foundation and document processing**
- Set up Rails 8 project with sqlite-vec
  - This required `gem install sqlite-vec` to get the native extension working locally.
    How do we handle this in deployment?
- Implement document upload (PDF, TXT, DOCX support)
- Build text extraction pipeline (pdf-reader gem, docx gem)
- Create chunking strategy (target 500-1000 tokens per chunk with overlap)
- Generate embeddings for chunks (OpenAI text-embedding-3-small)
- Store vectors in SQLite

**Phase 2: Basic RAG implementation**
- Build vector similarity search
- Implement simple retrieval (top-k chunks)
- Create prompt template for answering questions
- Build basic Rails API endpoint for Q&A
- Add conversation history tracking

**Phase 3: Vue.js frontend foundation**
- Set up Vite + Vue 3 project
- Build document upload interface with drag-and-drop
- Create document library view (list uploaded docs)
- Show processing status for documents
- Basic chat interface (no streaming yet)

**Phase 4: Improve retrieval and citations**
- Add metadata filtering (by document, date, etc.)
- Implement citation extraction (track which chunks were used)
- Show source references in answers with jump-to-document links
- Improve chunking with semantic awareness (don't split mid-sentence)

**Phase 5: Polish and error handling**
- Handle edge cases (empty documents, unsupported formats)
- Add proper error messages throughout
- Implement conversation clearing/management
- Add document deletion
- Basic authentication (Devise or simple token auth)

**Phase 6: Testing and refinement**
- Write key tests (document processing, vector search, API endpoints)
- Test with various document types and sizes
- Refine prompts for better answer quality
- Add loading states and user feedback

**Phase 7: Deployment and documentation**
- Deploy to Fly.io or Render
- Write comprehensive README with setup instructions
- Create demo video or GIF showing key features
- Add environment variable configuration

**Phase 8: Blog post and optional features**
- Write technical blog post explaining your approach
- If time allows: add ActionCable streaming
- If time allows: improve UI/UX polish
- If time allows: add document preview or PDF viewer

## Technical implementation details

**Document chunking strategy:**
```ruby
# Pseudocode - adjust for your preference
class DocumentChunker
  CHUNK_SIZE = 800 # tokens, roughly 600 words
  OVERLAP = 200    # tokens overlap between chunks
  
  def chunk(text)
    # Split on paragraphs first
    # Then combine into appropriately-sized chunks
    # Maintain overlap for context continuity
  end
end
```

**Vector search query:**
```ruby
# Using sqlite-vec
def search_similar_chunks(query_embedding, limit: 5)
  # Store embeddings as BLOB in SQLite
  # Use vec_distance_cosine for similarity
  Chunk.select(
    "*, vec_distance_cosine(embedding, ?) as distance"
  ).where(
    "distance < 0.5"  # similarity threshold
  ).order("distance").limit(limit)
end
```

**RAG prompt pattern:**
```ruby
def build_prompt(question, relevant_chunks)
  context = relevant_chunks.map(&:text).join("\n\n")
  
  <<~PROMPT
    You are answering questions based on provided documents.
    
    Context from documents:
    #{context}
    
    Question: #{question}
    
    Provide a clear answer based only on the context above.
    If the answer isn't in the context, say so.
    Cite which document sections you used.
  PROMPT
end
```

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

