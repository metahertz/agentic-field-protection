# LLM Container with MongoDB MCP

A fully containerized local LLM setup optimized for Mac M-series chips, featuring:
- **Ollama** - LLM runtime with GPU acceleration via Vulkan-to-Metal
- **Open WebUI** - Modern web interface for LLM interaction
- **MongoDB MCP Server** - Model Context Protocol integration for MongoDB Atlas

## Architecture

This setup uses **Podman with GPU acceleration** through virtio-gpu Venus, providing ~3x better performance than CPU-only Docker containers while maintaining full containerization.

### Performance Profile (M2/M3 Mac, Llama 3.2 3B)
- **Native Metal:** 80-100 tokens/sec
- **Podman GPU:** 50-70 tokens/sec (this setup)
- **Docker CPU:** 10-15 tokens/sec

The 40% performance penalty compared to native execution is worth the benefits of containerization: easy deployment, isolation, and reproducibility.

## Prerequisites

### Required
- macOS with Apple Silicon (M1/M2/M3)
- [Podman](https://podman.io/getting-started/installation) 4.0+
- 8GB+ RAM available for containers
- 20GB+ free disk space

### Installation
```bash
brew install podman podman-compose
```

### MongoDB Atlas Account
You'll need a MongoDB Atlas connection string. Sign up for free at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas).

## Quick Start

### 1. Initial Setup

```bash
# Clone or download this repository
cd llm-container-mongodb-mcp

# Set up Podman machine with GPU support
chmod +x podman-setup.sh
./podman-setup.sh
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.template .env

# Edit .env and add your MongoDB connection string
nano .env
```

**Important:** Replace the `MONGODB_URI` value with your actual MongoDB Atlas connection string:
```bash
MONGODB_URI=mongodb+srv://your-username:your-password@your-cluster.mongodb.net/your-database
```

### 3. Start Services

```bash
# Make scripts executable
chmod +x start.sh test.sh scripts/*.sh

# Start all services (builds containers, downloads model)
./start.sh
```

This will:
- Build three containers (Ollama, Open WebUI, MCP)
- Start all services
- Download the default model (llama3.2:3b, ~2GB)

### 4. Access the Interface

Open your browser to: **http://localhost:8080**

You should see the Open WebUI interface. Start chatting with the LLM immediately!

## Usage

### Basic Chat
1. Open http://localhost:8080
2. Select your model (llama3.2:3b)
3. Start chatting

### Using MongoDB MCP Tools
Ask questions about your MongoDB database:
```
"List all databases in my MongoDB cluster"
"Show me the collections in the users database"
"Find all documents in the customers collection"
```

The MCP server will automatically execute MongoDB operations and return results.

### Downloading Additional Models

```bash
# Download a specific model
./scripts/pull-model.sh llama3.2:1b

# Or use Ollama directly
podman exec ollama ollama pull mistral:7b
```

Popular models for M-series Macs:
- `llama3.2:1b` - Smallest, fastest (1.3GB)
- `llama3.2:3b` - Recommended default (2GB)
- `phi3:3.8b` - Microsoft's efficient model (2.3GB)
- `qwen2.5:3b` - Excellent coding (2GB)

### Viewing Logs

```bash
# All services
./scripts/logs.sh

# Specific service
./scripts/logs.sh ollama
./scripts/logs.sh openwebui
./scripts/logs.sh mcp
```

### Performance Benchmarking

```bash
# Run benchmark test
./scripts/benchmark.sh
```

This will test inference speed and compare against expected performance.

### Running Tests

```bash
# Comprehensive system test
./test.sh
```

Tests include:
- Podman machine status
- Container health
- GPU acceleration
- API connectivity
- End-to-end inference

### Stopping Services

```bash
# Stop all containers
./scripts/stop.sh

# Stop Podman machine
podman machine stop
```

## Configuration

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `MONGODB_URI` | (required) | MongoDB Atlas connection string |
| `OLLAMA_MODEL` | `llama3.2:3b` | Default model to download |
| `OLLAMA_NUM_PARALLEL` | `1` | Concurrent request limit |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in memory |
| `OPENWEBUI_PORT` | `8080` | Web interface port |
| `WEBUI_AUTH` | `false` | Enable authentication |
| `MCP_PORT` | `3000` | MCP server port |
| `MCP_LOG_LEVEL` | `info` | Logging verbosity |

### MongoDB MCP Configuration (mcp-config.json)

The MCP server supports these MongoDB operations:
- `mongodb.find` - Query documents
- `mongodb.aggregate` - Aggregation pipelines
- `mongodb.insertOne` - Insert documents
- `mongodb.updateOne` - Update documents
- `mongodb.deleteOne` - Delete documents
- `mongodb.listDatabases` - List databases
- `mongodb.listCollections` - List collections
- `mongodb.createIndex` - Create indexes
- `mongodb.vectorSearch` - Vector similarity search

Edit `mcp-config.json` to enable/disable specific tools.

## Troubleshooting

### "Podman machine is not running"
```bash
podman machine start
# or
./podman-setup.sh
```

### "Ollama API is not responding"
```bash
# Check logs
./scripts/logs.sh ollama

# Restart services
./scripts/stop.sh && ./start.sh
```

### "GPU device not detected"
GPU acceleration requires specific Podman setup. If not working:
1. Verify you ran `./podman-setup.sh`
2. Check Podman version: `podman --version` (need 4.0+)
3. Fallback: System will use CPU (slower but functional)

### Slow Performance
Expected performance varies by model size:
- 1B params: 80-120 tokens/sec
- 3B params: 50-80 tokens/sec
- 7B params: 20-40 tokens/sec

If much slower:
```bash
# Run benchmark to diagnose
./scripts/benchmark.sh

# Check GPU status
podman exec ollama ls -la /dev/dri
```

### MCP MongoDB Connection Errors
1. Verify `MONGODB_URI` in `.env` is correct
2. Test connection: `mongosh "$MONGODB_URI"`
3. Check MCP logs: `./scripts/logs.sh mcp`
4. Ensure IP allowlist in MongoDB Atlas includes your IP

### Container Build Failures
```bash
# Clean up and rebuild
./scripts/stop.sh
podman system prune -af
./start.sh
```

## Architecture Details

### Container Communication
All containers run on an isolated bridge network (`llm-network`):
- Ollama: Internal only, API at `http://ollama:11434`
- Open WebUI: Exposed on port 8080, connects to Ollama
- MCP: Internal only, used by Open WebUI for MongoDB operations

### Data Persistence
Volumes are created for persistent storage:
- `ollama-data`: Model files and cache
- `openwebui-data`: UI settings and chat history

### GPU Acceleration
Podman passes through the macOS GPU via `/dev/dri` device, using:
1. **libkrun** - Lightweight VM provider
2. **virtio-gpu Venus** - Vulkan virtualization
3. **MoltenVK** - Vulkan-to-Metal translation
4. **MESA drivers** - Patched for macOS compatibility

### Security
- MongoDB URI passed via environment variable (never committed)
- Internal network isolation (only Open WebUI exposed)
- No authentication required by default (local use only)
- Consider enabling `WEBUI_AUTH=true` for multi-user setups

## Alternative Setups

### Hybrid Mode (Better Performance)
If GPU acceleration isn't working, use native Ollama:

1. Install Ollama natively:
```bash
brew install ollama
ollama serve
```

2. Update `podman-compose.yml`:
```yaml
services:
  openwebui:
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
```

3. Remove Ollama container, keep Open WebUI + MCP

### Docker Mode (Maximum Compatibility)
If Podman issues arise, convert to Docker:

1. Install Docker Desktop for Mac
2. Rename `podman-compose.yml` to `docker-compose.yml`
3. Replace `podman` commands with `docker` in scripts
4. Remove GPU device mapping (Docker doesn't support it on macOS)

Expect 5-6x slower performance (CPU-only).

## Resources

### Documentation
- [Ollama Documentation](https://github.com/ollama/ollama/tree/main/docs)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [MongoDB MCP Server](https://github.com/mongodb-js/mongodb-mcp-server)
- [Model Context Protocol](https://modelcontextprotocol.io/)

### Research & Technical Details
- [Podman GPU Acceleration on macOS](https://developers.redhat.com/articles/2025/06/05/how-we-improved-ai-inference-macos-podman-containers)
- [GPU-Accelerated Containers for M-series Macs](https://medium.com/@andreask_75652/gpu-accelerated-containers-for-m1-m2-m3-macs-237556e5fe0b)
- [Announcing MongoDB MCP Server](https://www.mongodb.com/company/blog/announcing-mongodb-mcp-server)

### Model Repositories
- [Ollama Library](https://ollama.com/library)
- [Hugging Face Models](https://huggingface.co/models)

## Contributing

Issues and pull requests welcome! This is an open-source project for educational and development purposes.

## License

MIT License - See individual component licenses for details:
- Ollama: MIT
- Open WebUI: MIT
- MongoDB MCP Server: Apache 2.0

## Acknowledgments

Built using:
- [Ollama](https://ollama.com/) by Ollama Team
- [Open WebUI](https://github.com/open-webui/open-webui) by Open WebUI Contributors
- [MongoDB MCP Server](https://github.com/mongodb-js/mongodb-mcp-server) by MongoDB
- [Podman](https://podman.io/) by Red Hat & Container Community

GPU acceleration research based on work by:
- Red Hat Podman Team
- Andreas K's GPU containerization research
- libkrun & Venus driver maintainers
