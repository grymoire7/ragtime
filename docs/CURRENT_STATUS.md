# Ragtime - Current Status (2025-11-09)

## ✅ Working Features

### 1. Authentication
- ✅ Login with password works correctly
- ✅ Session management functional  
- ✅ Routes properly protected

### 2. Document Upload & Processing
- ✅ Document upload via API works
- ✅ Text extraction successful (PDF, TXT, DOCX)
- ✅ Chunking creates proper segments
- ✅ Embeddings generated (1536 dimensions via OpenAI text-embedding-3-small)
- ✅ vec_chunks virtual table populated correctly

### 3. Vector Search  
- ✅ ChunkRetriever finds relevant chunks
- ✅ L2 distance threshold adjusted to 1.2 (was 0.75 - too strict)
- ✅ Semantic search returns appropriate results
- ✅ Example: Query "What is Ragtime?" finds document with distance ~1.08

### 4. RAG Answer Generation
- ✅ AnswerGenerator produces accurate answers
- ✅ Citations ARE generated correctly (verified in Message ID 2)
- ✅ Metadata structure includes citations array with document info

### 5. API Endpoints
- ✅ Chat creation works
- ✅ Message posting accepts user questions
- ✅ Messages queued for background processing
- ✅ Frontend polling retrieves messages

## ⚠️ Current Issue: ChatResponseJob Broadcast Failure

### Symptom
ChatResponseJob completes message creation but fails during Turbo Streams broadcast, causing job to error out.

### Root Cause
**SolidCable database schema issue:**
```
ArgumentError (No unique index found for id)
  at solid_cable-3.0.12/app/models/solid_cable/message.rb:15
  in SolidCable::Message.broadcast
```

The `solid_cable_messages` table is missing a unique index on the `id` column, causing ActiveRecord's `insert_all` operation to fail.

### Technical Details
- Error occurs at `ChatResponseJob` lines 27-28
- Job sequence:
  1. ✅ Generate RAG answer with citations
  2. ✅ Create user message in database
  3. ✅ Create assistant message with metadata
  4. ❌ Broadcast user message (fails here)
  5. ❌ Broadcast assistant message (never reached)

### Impact
- **Messages ARE created successfully** before broadcast fails
- **Citations ARE stored** when chunks are found (see Message ID 2)
- **Frontend still works** via polling (doesn't use ActionCable)
- **Job logs show errors** but don't affect user experience
- **Turbo Streams (HTML interface) broken** - only affects traditional Rails views

### Why Citations Sometimes Missing
- Message ID 2: Has citations (asked about Ragtime, document exists)
- Message ID 4: No citations (asked about topic not well-covered in docs)
- **This is expected behavior** - citations are empty when no relevant chunks found

### Evidence
Successful message with citations:
```ruby
Message.find(2).metadata
# => {"citations" => [{
#      "chunk_id" => 1, 
#      "document_id" => 1,
#      "document_title" => "ragtime_final_test.txt",
#      "relevance" => 0.49,
#      "position" => 0
#    }]}
```

Error logs:
```
[ChatResponseJob] Error performing ... in 2758.45ms:
  ArgumentError (No unique index found for id)
  at solid_cable-3.0.12/app/models/solid_cable/message.rb:15
```

## Recent Fixes (git: 7af4c81)

### 1. Vector Search Threshold (`app/services/rag/chunk_retriever.rb`)
**Problem:** Default threshold of 0.75 was too strict for L2 distance  
**Fix:** Adjusted DEFAULT_DISTANCE_THRESHOLD from 0.75 → 1.2  
**Impact:** Semantic search now properly retrieves relevant chunks

### 2. Build Script Enhancement (`script/build-local`)
**Problem:** No way to force clean Docker rebuilds  
**Fix:** Added `--no-cache` flag support  
**Usage:** `./script/build-local --no-cache`

### 3. vec_chunks Virtual Table Corruption
**Problem:** Shadow tables existed but main table didn't (migration failed)  
**Fix:** Manual cleanup script to drop all shadow tables and recreate  
**Prevention:** Documented in episodic memory

## Architecture Notes

### Why Vue.js Frontend Still Works
- Frontend uses **HTTP polling** to fetch messages
- Does NOT use ActionCable/Turbo Streams for real-time updates
- ChatResponseJob broadcast failure doesn't affect Vue.js UI
- Broadcast is for traditional Rails HTML views (not in use)

### Potential Solutions for Broadcast Issue

#### Option 1: Fix SolidCable Schema (Proper Fix)
- Run SolidCable migrations properly
- Ensure solid_cable_messages table has primary key/unique index
- Keeps Turbo Streams working for HTML views

#### Option 2: Remove Broadcast Calls (Pragmatic Fix)  
- Remove lines 27-28 from ChatResponseJob
- System works fine without broadcasts (Vue.js doesn't use them)
- Simplifies architecture
- **Recommended** if not using Rails HTML views

## Next Steps

1. **Immediate:** Remove broadcast calls from ChatResponseJob (lines 27-28)
   - System fully functional without them for Vue.js frontend
   - Eliminates error noise in logs

2. **Optional:** Fix SolidCable schema if HTML views are needed
   - Check `db/cable_schema.rb` or SolidCable migrations
   - Ensure proper primary key on solid_cable_messages

3. **Testing:** Verify citations appear in Vue.js frontend after removing broadcasts

## Test Data Available

Documents uploaded:
1. `ragtime_final_test.txt` - About Ragtime system
2. `JayLockridgeResume.pdf` - Jay's resume

Test queries that work:
- "What is Ragtime?" → Returns answer with citations
- "Is Jay a software engineer?" → Returns answer from resume
