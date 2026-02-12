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
- **Podman** (recommended) or **Docker** — see below
- 8GB+ RAM available for containers
- 20GB+ free disk space

### Container Runtime

**Podman (recommended)** — GPU acceleration via Vulkan-to-Metal:
```bash
brew install podman podman-compose
```

**Docker (alternative)** — CPU-only on macOS, but works everywhere:
```bash
# Install Docker Desktop from https://docs.docker.com/get-docker/
# Or on Linux: sudo apt install docker.io docker-compose-v2
```

The startup script auto-detects which runtime is available. To force a specific runtime, set `CONTAINER_RUNTIME=podman` or `CONTAINER_RUNTIME=docker` before running scripts.

### MongoDB Atlas Account
You'll need a MongoDB Atlas connection string. Sign up for free at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas).

## Quick Start

### 1. Initial Setup

```bash
# Clone or download this repository
cd llm-container-mongodb-mcp

# If using Podman: set up Podman machine with GPU support
chmod +x podman-setup.sh
./podman-setup.sh

# If using Docker: just ensure Docker Desktop is running
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.template .env

# Edit .env for non-secret configuration (ports, model, etc.)
nano .env
```

**MongoDB Credentials** — choose one method:

```bash
# Option A (recommended): Use a secrets file
mkdir -p secrets
echo 'mongodb+srv://your-username:your-password@your-cluster.mongodb.net/your-database' > secrets/mongodb_uri
chmod 600 secrets/mongodb_uri

# Option B: Set MONGODB_URI directly in .env
# MONGODB_URI=mongodb+srv://your-username:your-password@your-cluster.mongodb.net/your-database
```

See [Secrets Management](Documentation/SECRETS.md) for more options including GitHub Actions secrets and external secrets managers.

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

### Switching Models

You can switch between LLM models at any time **without rebuilding containers**. Models are downloaded into a persistent volume and available immediately.

#### At Startup

```bash
# Start with a specific model (overrides .env)
./start.sh --model mistral:7b

# Start without pulling any model (faster startup)
./start.sh --no-pull

# Or set the default in .env
echo "OLLAMA_MODEL=phi3:3.8b" >> .env
./start.sh

# Or use an environment variable
OLLAMA_MODEL=qwen2.5:3b ./start.sh

# Or use the container runtime directly
podman exec ollama ollama pull mistral:7b   # Podman
docker exec ollama ollama pull mistral:7b   # Docker
```

#### After Services Are Running

```bash
# Download a new model (no restart needed)
./scripts/pull-model.sh llama3.2:1b

# Download multiple models at once
./scripts/pull-model.sh mistral:7b phi3:3.8b qwen2.5:3b

# List all downloaded models
./scripts/pull-model.sh --list
```

After pulling a model, select it in the Open WebUI model dropdown — no restart required.

#### Model Priority

The model used at startup is resolved in this order:
1. `--model` flag passed to `./start.sh`
2. `MODEL` environment variable
3. `OLLAMA_MODEL` in `.env`
4. Default: `llama3.2:3b`

#### Popular Models for M-series Macs

| Model | Size | Best For | Speed (M2/M3) |
|-------|------|----------|----------------|
| `llama3.2:1b` | 1.3GB | Quick responses, low memory | 80-120 tok/s |
| `llama3.2:3b` | 2GB | General use (recommended) | 50-80 tok/s |
| `phi3:3.8b` | 2.3GB | Reasoning, instruction-following | 40-60 tok/s |
| `qwen2.5:3b` | 2GB | Coding, multilingual | 50-80 tok/s |
| `mistral:7b` | 4.1GB | Strong general-purpose | 20-40 tok/s |
| `llama3.1:8b` | 4.7GB | High quality, needs 16GB RAM | 15-30 tok/s |

Browse all available models at [ollama.com/library](https://ollama.com/library).

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
- Container runtime status (Podman or Docker)
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
| `OLLAMA_MODEL_STORAGE` | `ollama-data` | Volume name or host path for model storage |
| `OPENWEBUI_DATA_STORAGE` | `openwebui-data` | Volume name or host path for UI data |
| `OPENWEBUI_PORT` | `8080` | Web interface port |
| `WEBUI_AUTH` | `false` | Enable authentication |
| `MCP_PORT` | `3000` | MCP server port |
| `MCP_LOG_LEVEL` | `info` | Logging verbosity |
| `CONTAINER_RUNTIME` | (auto-detect) | Force `podman` or `docker` |

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

### "Podman machine is not running" (Podman only)
```bash
podman machine start
# or
./podman-setup.sh
```

### "Docker is not running" (Docker only)
Start Docker Desktop, or on Linux:
```bash
sudo systemctl start docker
```

### "Ollama API is not responding"
```bash
# Check logs
./scripts/logs.sh ollama

# Restart services
./scripts/stop.sh && ./start.sh
```

### "GPU device not detected"
GPU acceleration requires Podman (not Docker) on macOS. If not working:
1. Verify you ran `./podman-setup.sh`
2. Check Podman version: `podman --version` (need 4.0+)
3. Fallback: System will use CPU (slower but functional)
4. If using Docker: GPU is not available on macOS — this is expected

### Slow Performance
Expected performance varies by model size:
- 1B params: 80-120 tokens/sec
- 3B params: 50-80 tokens/sec
- 7B params: 20-40 tokens/sec

If much slower:
```bash
# Run benchmark to diagnose
./scripts/benchmark.sh

# Check GPU status (Podman only — Docker does not have GPU on macOS)
podman exec ollama ls -la /dev/dri
```

### MCP MongoDB Connection Errors
1. Verify `MONGODB_URI` in `.env` is correct
2. Test connection: `mongosh "$MONGODB_URI"`
3. Check MCP logs: `./scripts/logs.sh mcp`
4. Ensure IP allowlist in MongoDB Atlas includes your IP

### Container Build Failures
```bash
# Clean up and rebuild (Podman)
./scripts/stop.sh
podman system prune -af
./start.sh

# Clean up and rebuild (Docker)
./scripts/stop.sh
docker system prune -af
./start.sh
```

## Architecture Details

### Container Communication
All containers run on an isolated bridge network (`llm-network`):
- Ollama: Internal only, API at `http://ollama:11434`
- Open WebUI: Exposed on port 8080, connects to Ollama
- MCP: Internal only, used by Open WebUI for MongoDB operations

### Data Persistence

Named Podman volumes persist data across container restarts and rebuilds:
- `ollama-data`: Model files and cache (~2-20GB depending on models)
- `openwebui-data`: UI settings and chat history (~100MB)

Models you download are stored in the `ollama-data` volume and survive `podman-compose down` / `podman-compose up` cycles. They are only removed if you explicitly delete the volume (e.g., `podman volume rm ollama-data` or `podman volume prune`).

#### Using a bind mount instead

To store models on a specific host directory (useful for sharing models between setups or easier backups), set `OLLAMA_MODEL_STORAGE` in `.env`:

```bash
# Use a host directory for model storage
OLLAMA_MODEL_STORAGE=/path/to/my/ollama-models

# Similarly for Open WebUI data
OPENWEBUI_DATA_STORAGE=/path/to/my/webui-data
```

The directory will be created automatically on first start. Leave these unset to use the default named volumes.

#### Volume management

```bash
# List volumes and sizes
./scripts/manage-volumes.sh list

# Backup volumes to tar archives
./scripts/manage-volumes.sh backup              # saves to ./backups/
./scripts/manage-volumes.sh backup /my/backups   # saves to custom dir

# Restore from most recent backup
./scripts/manage-volumes.sh restore

# Remove all project volumes (prompts for confirmation)
./scripts/manage-volumes.sh reset
```

### GPU Acceleration
Podman passes through the macOS GPU via `/dev/dri` device, using:
1. **libkrun** - Lightweight VM provider
2. **virtio-gpu Venus** - Vulkan virtualization
3. **MoltenVK** - Vulkan-to-Metal translation
4. **MESA drivers** - Patched for macOS compatibility

### Security
- MongoDB URI supports file-based secrets (`secrets/mongodb_uri`) — see [Secrets Management](Documentation/SECRETS.md)
- Startup script warns if `.env` contains real credentials
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
Docker is supported as a fallback when Podman is not available. All scripts auto-detect the runtime, so no manual conversion is needed.

1. Install [Docker Desktop](https://docs.docker.com/get-docker/) (macOS/Windows) or Docker Engine (Linux)
2. Ensure Docker is running
3. Run `./start.sh` — it will automatically use `docker-compose.yml`

**GPU tradeoff on macOS:** Docker Desktop on macOS runs containers in a Linux VM without access to the Apple GPU. Ollama will run in CPU-only mode, resulting in ~5-6x slower inference (10-15 tokens/sec for llama3.2:3b vs 50-70 with Podman GPU). For GPU-accelerated containers on macOS, use Podman instead.

**Docker on Linux with NVIDIA GPU:** If you have an NVIDIA GPU on Linux, you can add GPU support by installing the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) and adding a `deploy` section to `docker-compose.yml`. This is not included by default since the project targets macOS Apple Silicon.

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
