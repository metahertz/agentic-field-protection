# Usage Examples

Practical examples for using the LLM container system.

## Basic LLM Chat

### Simple Conversation
1. Open http://localhost:8080
2. Select model: `llama3.2:3b`
3. Type: "Explain what containers are in simple terms"

### Code Generation
```
User: Write a Python function to calculate fibonacci numbers

LLM: Here's a clean implementation:
[code generated]
```

### Code Review
```
User: Review this code for security issues:
[paste code]

LLM: I found several concerns:
1. SQL injection vulnerability...
2. Missing input validation...
```

## MongoDB MCP Integration

### Database Exploration

**List all databases:**
```
User: Show me all databases in my MongoDB cluster
```

**List collections:**
```
User: What collections are in the 'users' database?
```

**Examine schema:**
```
User: Show me a sample document from the 'customers' collection
```

### Data Queries

**Simple find:**
```
User: Find all users where status is 'active'
```

**Aggregation:**
```
User: Count how many orders each customer has
```

**Vector search (if configured):**
```
User: Find documents similar to "machine learning tutorial"
```

### Data Modification

**Insert:**
```
User: Add a new user with email test@example.com and name "Test User"
```

**Update:**
```
User: Update user with email test@example.com to set status to 'active'
```

**Create index:**
```
User: Create an index on the 'email' field in the users collection
```

## Model Management

### Downloading Models

**Small model (fast):**
```bash
./scripts/pull-model.sh llama3.2:1b
```

**Recommended default:**
```bash
./scripts/pull-model.sh llama3.2:3b
```

**Coding-focused:**
```bash
./scripts/pull-model.sh qwen2.5:3b
```

**Larger model (slower, better quality):**
```bash
./scripts/pull-model.sh mistral:7b
```

### Switching Models

In Open WebUI:
1. Click model dropdown (top)
2. Select different model
3. Start chatting

## Performance Testing

### Quick benchmark:
```bash
./scripts/benchmark.sh
```

### Testing specific model:
```bash
# Edit .env first
OLLAMA_MODEL=phi3:3.8b

./scripts/benchmark.sh
```

### Compare models:
```bash
# Test llama3.2:3b
OLLAMA_MODEL=llama3.2:3b ./scripts/benchmark.sh > llama-3b.txt

# Test phi3:3.8b
OLLAMA_MODEL=phi3:3.8b ./scripts/benchmark.sh > phi3.txt

# Compare
diff llama-3b.txt phi3.txt
```

## Advanced Prompts

### Structured Output
```
User: Generate a JSON schema for a user profile with name, email, age, and preferences array

LLM: {
  "type": "object",
  "properties": {
    ...
  }
}
```

### Multi-step Reasoning
```
User: I have a MongoDB collection with 1M documents. I need to find duplicates based on email field and delete all but the most recent. How would you approach this?

LLM: Here's a safe approach:
1. Create aggregation pipeline to find duplicates
2. [detailed steps]
3. Test on sample first
[code examples]
```

### Context Continuation
```
User: Explain distributed databases

LLM: [explanation]

User: Now explain CAP theorem in that context

LLM: [builds on previous explanation]
```

## System Administration

### Check system health:
```bash
./scripts/health-check.sh
```

### View real-time logs:
```bash
# All services
./scripts/logs.sh

# Just Ollama
./scripts/logs.sh ollama

# Just MCP
./scripts/logs.sh mcp
```

### Restart services:
```bash
./scripts/stop.sh
./start.sh
```

### Clean restart (fresh state):
```bash
./scripts/stop.sh
podman volume prune -f
./start.sh
```

### Check resource usage:
```bash
podman stats
```

## Troubleshooting Examples

### Slow Response Times

**Diagnose:**
```bash
./scripts/benchmark.sh
```

**Check GPU:**
```bash
podman exec ollama ls -la /dev/dri
```

**Expected output:**
```
drwxr-xr-x    2 root     root           100 Jan  1 12:00 .
drwxr-xr-x    5 root     root           360 Jan  1 12:00 ..
crw-rw----    1 root     video      226,   0 Jan  1 12:00 card0
crw-rw----    1 root     video      226, 128 Jan  1 12:00 renderD128
```

If missing, GPU not available (CPU fallback mode).

### MongoDB Connection Errors

**Test connection:**
```bash
source .env
mongosh "$MONGODB_URI" --eval "db.adminCommand('ping')"
```

**Check MCP logs:**
```bash
./scripts/logs.sh mcp
```

**Common issues:**
- IP not in Atlas allowlist
- Incorrect credentials
- Network connectivity

### Model Not Loading

**Check available space:**
```bash
podman volume inspect ollama-data
df -h
```

**List downloaded models:**
```bash
curl -s http://localhost:11434/api/tags | jq
```

**Force re-download:**
```bash
podman exec ollama ollama rm llama3.2:3b
./scripts/pull-model.sh llama3.2:3b
```

## API Usage

### Direct Ollama API

**Generate (streaming):**
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Why is the sky blue?",
  "stream": true
}'
```

**Generate (non-streaming):**
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

**Chat format:**
```bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2:3b",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ]
}'
```

### MCP API Examples

**List available tools:**
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "method": "tools/list"
  }'
```

**Execute MongoDB query:**
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "method": "tools/call",
    "params": {
      "name": "mongodb.find",
      "arguments": {
        "database": "test",
        "collection": "users",
        "query": {"status": "active"}
      }
    }
  }'
```

## Integration Examples

### Python Integration
```python
import requests

def query_llm(prompt):
    response = requests.post(
        'http://localhost:11434/api/generate',
        json={
            'model': 'llama3.2:3b',
            'prompt': prompt,
            'stream': False
        }
    )
    return response.json()['response']

result = query_llm("What is machine learning?")
print(result)
```

### JavaScript Integration
```javascript
async function queryLLM(prompt) {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      model: 'llama3.2:3b',
      prompt: prompt,
      stream: false
    })
  });
  const data = await response.json();
  return data.response;
}

const result = await queryLLM("Explain APIs");
console.log(result);
```

### Bash Integration
```bash
#!/bin/bash

ask_llm() {
    local prompt="$1"
    curl -s http://localhost:11434/api/generate -d "{
        \"model\": \"llama3.2:3b\",
        \"prompt\": \"$prompt\",
        \"stream\": false
    }" | jq -r '.response'
}

# Usage
ask_llm "Write a one-line summary of Docker"
```

## Workflow Examples

### Code Review Workflow
1. User commits code
2. CI/CD triggers script
3. Script sends code to LLM via API
4. LLM reviews and returns feedback
5. Post as PR comment

### Documentation Generation
1. Point LLM at codebase
2. Ask to generate API documentation
3. Review and edit output
4. Commit to repository

### Data Analysis
1. Query MongoDB via MCP
2. Ask LLM to analyze results
3. Generate insights and visualizations
4. Export report

## Performance Optimization

### For Speed (smaller models):
```bash
./scripts/pull-model.sh llama3.2:1b
# 100+ tokens/sec
```

### For Quality (larger models):
```bash
./scripts/pull-model.sh mistral:7b
# 30-40 tokens/sec, better responses
```

### For Coding:
```bash
./scripts/pull-model.sh qwen2.5:3b
# 50-70 tokens/sec, optimized for code
```

### Adjust concurrency:
```bash
# Edit .env
OLLAMA_NUM_PARALLEL=2
OLLAMA_MAX_LOADED_MODELS=2

# Restart
./scripts/stop.sh && ./start.sh
```

## Security Best Practices

### Protect MongoDB URI:
```bash
# Never commit .env
git update-index --assume-unchanged .env

# Use restrictive permissions
chmod 600 .env
```

### Enable authentication:
```bash
# Edit .env
WEBUI_AUTH=true

# Restart
./scripts/stop.sh && ./start.sh
```

### Network isolation:
```bash
# Only expose Open WebUI, not Ollama
# Already configured in podman-compose.yml
```

### Regular updates:
```bash
# Update images monthly
podman pull ghcr.io/open-webui/open-webui:main
./scripts/stop.sh && ./start.sh
```

## Backup and Recovery

### Backup models and data:
```bash
#!/bin/bash
BACKUP_DIR="./backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup volumes
podman volume export ollama-data > "$BACKUP_DIR/ollama-data.tar"
podman volume export openwebui-data > "$BACKUP_DIR/webui-data.tar"

# Backup config
cp .env "$BACKUP_DIR/env.backup"
cp mcp-config.json "$BACKUP_DIR/"
```

### Restore from backup:
```bash
#!/bin/bash
BACKUP_DIR="./backups/20260205"

# Stop services
./scripts/stop.sh

# Restore volumes
podman volume import ollama-data < "$BACKUP_DIR/ollama-data.tar"
podman volume import openwebui-data < "$BACKUP_DIR/webui-data.tar"

# Restore config
cp "$BACKUP_DIR/env.backup" .env

# Restart
./start.sh
```

## Monitoring

### Resource usage:
```bash
# Live monitoring
watch -n 5 'podman stats --no-stream'
```

### Disk usage:
```bash
podman system df
```

### Log analysis:
```bash
# Count errors
./scripts/logs.sh ollama | grep -i error | wc -l

# Find slowest requests
./scripts/logs.sh ollama | grep "eval_duration" | sort -n
```

## Tips and Tricks

1. **Keep models small** - 3B models are the sweet spot for M-series
2. **Use streaming** - Better UX for long responses
3. **Warm up models** - First request is slower (model loading)
4. **Monitor GPU** - Check /dev/dri is available
5. **Batch questions** - More efficient than single queries
6. **Clear context** - Restart conversation for unrelated topics
7. **Use system prompts** - Guide LLM behavior in Open WebUI settings
8. **Test MongoDB queries** - Verify in Atlas first before LLM integration
