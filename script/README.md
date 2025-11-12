# Ragtime Scripts

Development, debugging, and container management scripts for Ragtime.

## **🎯 Quick Help**

**All scripts support `--help` or `-h` for detailed usage information:**
```bash
script/[script-name] --help
```

## **📋 Script Reference**

### Container Management
- **`build-local`** - Build Docker container (supports `--no-cache`)
- **`run-local`** - Start container on port 8080 (requires credentials)
- **`rebuild-and-run`** - Build and run in one command
- **`remove-container`** - Stop and remove container
- **`setup-local`** - Production Docker Compose setup with volumes

### Debugging & Inspection
- **`logs`** - View container logs with filtering (`--errors`, `--jobs`, `--follow`, `--tail N`)
- **`db-status`** - Comprehensive database status and counts
- **`runner-container`** - Execute Ruby code in container
- **`fix-vec-chunks`** - Repair sqlite-vec virtual table corruption

### Deployment
- **`deploy`** - Deploy to Fly.io (supports `--skip-health-check`, `--skip-secrets`)

---

## **🚀 Common Workflows**

### **Quick Start (Single Container)**
```bash
# First time setup
script/build-local && script/run-local

# Quick rebuild
script/rebuild-and-run

# Access at http://localhost:8080
```

### **Production-Grade Setup (Docker Compose)**
```bash
# Uses persistent volumes, different port (80)
script/setup-local
```

### **Health Check**
```bash
script/db-status          # Database overview
script/logs --errors      # Recent errors
script/logs --follow      # Live monitoring
```

### **Debug Document Processing**
```bash
# Check job activity
script/logs --jobs | grep ProcessDocumentJob

# Inspect specific document
script/runner-container 'Document.last.status'
script/runner-container 'Document.last.chunks.count'

# Check vector search
script/runner-container 'Chunk.count'
script/runner-container '
  results = Rag::ChunkRetriever.retrieve("test query")
  puts "Found #{results.length} chunks"
'
```

### **Fix Vector Table Corruption**
```bash
# Symptoms: "no such table: vec_chunks" errors
script/fix-vec-chunks
script/db-status  # Verify fix
```

### **Container Management**
```bash
# Clean restart
script/remove-container
script/build-local --no-cache  # Force rebuild
script/run-local

# Access container shell
docker exec -it ragtime-test bash
```

---

## **🔧 Advanced Workflows**

### **Multi-Script Debugging**
```bash
# Complete document processing investigation
script/logs --jobs | head -10                    # Recent jobs
script/runner-container 'Document.last.id'       # Get document ID
script/runner-container '
  doc = Document.find(123)
  puts "Status: #{doc.status}"
  puts "Chunks: #{doc.chunks.count}"
  doc.chunks.each { |c| puts "  Chunk #{c.id}: #{c.content.length} chars" }
'
```

### **Performance Analysis**
```bash
# Monitor while testing
script/logs --follow | grep -E "(Completed|Error|Performance)" &
LOGS_PID=$!

# Run your tests...
# Then stop log monitoring
kill $LOGS_PID 2>/dev/null
```

### **Development vs Production Testing**
```bash
# Local development (port 8080, single container)
script/rebuild-and-run

# Production-like (port 80, persistent volumes)
script/setup-local

# Deploy to production
script/deploy
```

### **Database Maintenance**
```bash
# Check table consistency
script/runner-container '
  puts "Chunks: #{Chunk.count}"
  puts "Vec chunks: #{ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM vec_chunks").first.values.first}"

  if Chunk.count != ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM vec_chunks").first.values.first
    puts "⚠️  Mismatch detected - run script/fix-vec-chunks"
  end
'
```

---

## **📝 Key Differences**

| Setup Type | Port | Persistence | Use Case |
|------------|------|-------------|----------|
| `script/run-local` | 8080 | Ephemeral | Quick testing |
| `script/setup-local` | 80 | Persistent volumes | Long-term development |
| `script/deploy` | N/A | Fly.io | Production deployment |

## **⚠️ Requirements**

- **All scripts:** Docker installed
- **Container scripts:** `config/credentials/production.key` must exist
- **setup-local:** Docker Compose required
- **deploy:** Fly CLI and authentication

## **🔍 Troubleshooting**

1. **Container won't start:** Check credentials file exists
2. **Vector search fails:** Run `script/fix-vec-chunks`
3. **Jobs not processing:** Check `script/logs --jobs`
4. **Database issues:** Run `script/db-status`
5. **Need help:** Run `script/[name] --help`

---

*💡 **Tip:** All scripts now provide comprehensive help via `--help` option. Use it to explore options and get detailed usage information.*

