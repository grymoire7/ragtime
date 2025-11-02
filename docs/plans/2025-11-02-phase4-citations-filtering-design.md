# Phase 4: Improved Retrieval and Citations - Design Document

**Date:** 2025-11-02
**Phase:** 4 of 7
**Status:** Approved - Ready for Implementation

## Overview

Phase 4 enhances the RAG system with date-based filtering and persistent citation tracking. These improvements enable users to focus on recent documents and see which sources informed each answer, improving trust and traceability.

## Requirements Gathered

### Use Cases
- **Date filtering:** Users want to query recent documents (e.g., "last 7 days", "this month")
- **Citation persistence:** Users need to see which sources were used when reviewing old conversations
- **Citation display:** Users expect inline footnote-style references with source details

### Constraints
- Portfolio project timeline (1-2 days for Phase 4)
- ~100 document scale (in-memory filtering acceptable)
- Simple implementation preferred over premature optimization

## Architectural Approach: Minimal Incremental

**Rationale:** Smallest changes, lowest risk, fits portfolio timeline. Optimize later if needed.

**Trade-offs:**
- ✅ Fast to implement (1-2 days)
- ✅ Low risk to existing functionality
- ✅ Backward compatible API
- ⚠️ Document filtering remains in-memory (acceptable at current scale)
- ⚠️ Citations stored in JSON (not normalized, but queryable if needed)

## Design Details

### 1. Date Filtering Implementation

**Component:** `ChunkRetriever` service

**Changes:**
- Add `created_after: DateTime` optional parameter to `retrieve` method
- Filter results array by `document.created_at >= created_after`
- No database schema changes needed

**API Usage:**
```ruby
# Retrieve chunks from documents created in last 7 days
ChunkRetriever.retrieve(
  query,
  created_after: 7.days.ago
)
```

**Performance:** Documents already loaded in `format_results` for title display, so checking `created_at` adds negligible overhead. For ~100 documents, in-memory filtering is faster than adding SQL complexity.

**Future optimization path:** If scaling beyond 100s of documents, can add SQL WHERE clause in `Chunk.search_similar` without changing public API.

### 2. Citation Storage in Messages

**Component:** `messages` table and `AnswerGenerator` service

**Database Changes:**
- Migration: `add_column :messages, :metadata, :json, default: {}`
- SQLite supports JSON natively (3.38+), no gem dependencies needed

**Citation Data Structure:**
```json
{
  "citations": [
    {
      "chunk_id": 123,
      "document_id": 45,
      "document_title": "Annual Report 2024",
      "relevance": 0.92,
      "position": 2
    }
  ]
}
```

**Data Flow:**
1. `AnswerGenerator.generate` returns enhanced `chunks_used` with full citation details
2. `MessagesController` stores citation data in `message.metadata["citations"]`
3. API returns metadata to frontend
4. Frontend renders citations

**Why JSON Column:**
- Schema flexibility for future metadata (model info, token counts, etc.)
- SQLite JSON functions available if querying needed later
- Simpler than normalized `citations` join table for portfolio scope

### 3. Frontend Citation Display

**Component:** Vue.js chat interface

**Display Pattern:**
```
Assistant: "Based on the quarterly report [1] and market analysis [2],
revenue increased by 15%..."

Sources:
[1] Annual Report 2024 (relevance: 92%)
[2] Market Analysis Q3 (relevance: 88%)
```

**Implementation:**
- Backend returns citations array in message metadata
- Frontend displays all sources below answer text
- Each source shows: index number, document title, relevance score
- Sources clickable (link to document detail view)

**LLM Behavior:**
- PromptBuilder already instructs LLM to cite document titles
- Frontend adds [N] markers by matching titles or showing all sources in footer
- If LLM doesn't mention a retrieved source, it still appears in "Sources:" section

**Future Enhancements (Phase 5+):**
- Jump-to-chunk functionality
- Document preview modal
- Highlight which specific chunk was used
- Inline citation tooltips

## Implementation Plan

### Backend Changes

**1. Database Migration**
```ruby
# db/migrate/TIMESTAMP_add_metadata_to_messages.rb
add_column :messages, :metadata, :json, default: {}
```

**2. ChunkRetriever Service** (`app/services/rag/chunk_retriever.rb`)
- Add `created_after` parameter to `retrieve` method
- Add `filter_by_date` private method
- Call date filter before `format_results` if `created_after` present

**3. AnswerGenerator Service** (`app/services/rag/answer_generator.rb`)
- Enhance `chunks_used` return value to include:
  - chunk_id, document_id, document_title (already present)
  - relevance (converted from distance)
  - position (chunk position in document)
- Return as `citations` key for clarity

**4. MessagesController** (`app/controllers/messages_controller.rb`)
- Store `citations` from AnswerGenerator in `message.metadata`
- Include `metadata` in API response JSON

### Frontend Changes

**5. Message Display Component**
- Parse `metadata.citations` from API response
- Render "Sources:" section below assistant messages
- Format: `[N] Document Title (relevance: XX%)`
- Add click handler for document links

### Testing

**Unit Tests:**
- ChunkRetriever with `created_after` parameter
- Date filtering edge cases (no matches, all match, boundary dates)
- Citation metadata structure

**Integration Tests:**
- Full flow: question → retrieval → answer → citation storage
- API response includes citations in metadata
- Old messages without metadata still work (backward compatibility)

**Manual Testing:**
- Upload documents with different dates
- Ask question with date filter
- Verify citations display in UI
- Review old conversation and see citations

## Success Criteria

- ✅ Users can filter to documents created after a specific date
- ✅ Citation data persists with messages in database
- ✅ Chat UI displays source documents with relevance scores
- ✅ Backward compatible (existing messages still work)
- ✅ No performance degradation for existing queries
- ✅ Tests pass and cover new functionality

## Future Considerations

**Not in scope for Phase 4, but documented for later:**

1. **SQL-level date filtering:** If scaling beyond ~100 documents, move date filter into `Chunk.search_similar` SQL query
2. **Normalized citations table:** If need to query "which messages used document X", create `message_citations` join table
3. **Chunk preview:** Show actual chunk text in citation tooltip/modal
4. **Citation accuracy:** Track which chunks LLM actually referenced vs. which were provided (requires LLM to return structured citations)
5. **Document filtering optimization:** Move to SQL JOIN when document count grows

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| In-memory filtering slow at scale | Acceptable for ~100 docs; can optimize later without API changes |
| JSON metadata hard to query | SQLite JSON functions available; can migrate to table if needed |
| Citation format unclear to users | Use familiar footnote style [1], [2] with clear labels |
| Backward compatibility | Default metadata to empty hash; handle missing gracefully |

## Approval

**Design validated:** 2025-11-02
**Approved by:** Tracy (via brainstorming session)
**Ready for implementation:** Yes
