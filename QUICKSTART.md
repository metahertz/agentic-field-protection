# Quick Start Guide

Get up and running in 5 minutes.

## Prerequisites Check

```bash
# Check if you have Podman
podman --version

# If not installed:
# macOS:
brew install podman podman-compose

# Fedora/RHEL (ARM64 Linux):
sudo dnf install podman podman-compose mesa-vulkan-drivers

# Ubuntu/Debian (ARM64 Linux):
sudo apt install podman mesa-vulkan-drivers
pip install podman-compose
```

## Installation

```bash
# 1. Set up Podman with GPU support
./podman-setup.sh

# 2. Create your configuration
cp .env.template .env

# 3. Edit .env and add your MongoDB URI
nano .env
# Replace: MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/database

# 4. Start everything
./start.sh
```

## Access

Open http://localhost:8080 in your browser.

## Common Commands

```bash
# View logs
./scripts/logs.sh

# Stop everything
./scripts/stop.sh

# Download more models
./scripts/pull-model.sh llama3.2:1b

# Test performance
./scripts/benchmark.sh

# Run full tests
./test.sh
```

## Troubleshooting

### Podman not running
```bash
podman machine start
```

### Slow performance
```bash
./scripts/benchmark.sh
# Should show 50-70 tokens/sec for llama3.2:3b
# If slower, check GPU: podman exec ollama ls /dev/dri
```

### MongoDB connection errors
- Check your `MONGODB_URI` in `.env`
- Verify IP allowlist in MongoDB Atlas
- Test: `mongosh "$MONGODB_URI"`

## What's Running?

After `./start.sh`, you have:

1. **Ollama** (port 11434) - LLM runtime
2. **Open WebUI** (port 8080) - Chat interface
3. **MCP Server** (port 3000) - MongoDB integration

## Next Steps

- Try different models: `./scripts/pull-model.sh phi3:3.8b`
- Ask MongoDB questions: "List all my databases"
- Read full documentation: [README.md](README.md)
