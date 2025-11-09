# Ragtime Scripts

Useful scripts for development, debugging, and container management.

## Container Management

### `build-local [--no-cache]`
Build the Docker container for local testing.
```bash
script/build-local              # Normal build
script/build-local --no-cache   # Force clean rebuild
```

### `run-local`
Start the Ragtime container locally on port 8080.
```bash
script/run-local
```

### `rebuild-and-run`
Convenience script to build and run in one command.
```bash
script/rebuild-and-run
```

## Debugging & Inspection

### `runner-container 'ruby_code'`
Execute Rails code in the running container (filters sqlite-vec noise).
```bash
script/runner-container 'puts Document.count'
script/runner-container 'Document.all.each { |d| puts d.title }'
echo 'puts Model.pluck(:model_id)' | script/runner-container
```

### `logs [options] [pattern]`
View container logs with smart filtering.
```bash
script/logs                 # Last 50 lines
script/logs --errors        # Show only errors
script/logs --jobs          # Show ActiveJob activity
script/logs --follow        # Follow logs in real-time
script/logs --tail 100      # Last 100 lines
script/logs "ChatResponse"  # Grep for pattern
```

### `db-status`
Show comprehensive database status and counts.
```bash
script/db-status
```

Output includes:
- Document counts (total, completed, pending, failed)
- Chunk counts and vec_chunks sync status
- Chat and message counts
- Available models
- Configuration summary

## Maintenance

### `fix-vec-chunks`
Fix corrupted vec_chunks virtual table.

This is needed when migrations partially fail, leaving orphaned shadow tables.
Symptoms: "no such table: vec_chunks" errors during document processing.

```bash
script/fix-vec-chunks
```

The script will:
1. Drop all vec_chunks shadow tables
2. Recreate the virtual table with 1536 dimensions
3. Verify the table is ready

## Typical Workflows

### Quick Health Check
```bash
script/db-status
script/logs --errors | head -20
```

### Debug Document Processing
```bash
script/logs --jobs | grep ProcessDocumentJob
script/runner-container 'Document.last.status'
script/runner-container 'Document.last.chunks.count'
```

### Debug RAG Pipeline
```bash
script/runner-container 'Chunk.count'
script/runner-container '
  results = Rag::ChunkRetriever.retrieve("test query")
  puts "Found #{results.length} chunks"
'
```

### Fix vec_chunks Corruption
```bash
script/fix-vec-chunks
script/db-status  # Verify it's fixed
```

### Monitor Live Activity
```bash
script/logs --follow
```

## Notes

- All container scripts require the `ragtime-test` container to be running
- Use `script/run-local` to start the container if needed
- The runner-container script automatically filters out "sqlite-vec extension loaded" messages
- The db-status script checks for vec_chunks/chunks table sync issues
