# Changelog

## [1.0.0] - 2026-02-05

Initial release of LLM Container with MongoDB MCP integration.

### Added

#### Core Infrastructure
- **Containerfile.ollama**: Fedora 40-based container with Ollama and GPU acceleration
- **Containerfile.openwebui**: Open WebUI container with Ollama integration
- **Containerfile.mcp**: MongoDB MCP server container with Node.js 22
- **podman-compose.yml**: Service orchestration with networking and volumes

#### Configuration
- **.env.template**: Environment variable template with sensible defaults
- **mcp-config.json**: MongoDB MCP server tool configuration
- **.gitignore**: Security-focused exclusions

#### Setup Scripts
- **podman-setup.sh**: Automated Podman Machine setup with GPU support
- **start.sh**: Main startup script with validation and model downloading
- **test.sh**: Comprehensive integration test suite (7 tests)

#### Utility Scripts
- **scripts/pull-model.sh**: Model download and verification
- **scripts/stop.sh**: Graceful service shutdown
- **scripts/logs.sh**: Centralized log viewer with filtering
- **scripts/benchmark.sh**: Performance testing with GPU detection
- **scripts/health-check.sh**: Quick system health overview

#### Documentation
- **README.md**: Complete user guide with 7 sections
  - Overview and architecture
  - Prerequisites and installation
  - Quick start guide
  - Usage instructions
  - Configuration reference
  - Troubleshooting guide
  - Technical deep dive
- **QUICKSTART.md**: Condensed 5-minute setup guide
- **IMPLEMENTATION.md**: Technical implementation details
- **EXAMPLES.md**: Practical usage examples and API integration

### Features

#### GPU Acceleration
- Vulkan-to-Metal translation via MoltenVK
- virtio-gpu Venus driver support
- 3x performance improvement over CPU-only containers
- Automatic GPU device passthrough

#### Service Integration
- Ollama LLM runtime with API (port 11434)
- Open WebUI interface (port 8080)
- MongoDB MCP server (port 3000)
- Internal bridge networking
- Persistent volume storage

#### Model Management
- Automatic download of default model (llama3.2:3b)
- Support for any Ollama-compatible model
- Model caching and persistence
- Easy model switching via UI

#### MongoDB Integration
- Full MCP protocol support
- 9 enabled tools (find, aggregate, insert, update, delete, list, index, vector search)
- Connection via MongoDB Atlas
- Environment-based configuration

#### Monitoring and Testing
- 7-stage integration test suite
- Performance benchmarking with metrics
- Health check system
- Real-time log viewing
- GPU status verification

#### Security
- Environment-based credential management
- Network isolation (only UI exposed)
- .gitignore for sensitive files
- No hardcoded credentials
- Optional authentication support

### Performance

Expected performance on M2/M3 Mac:
- **llama3.2:1b**: 70-90 tokens/sec (GPU), 15-20 tokens/sec (CPU)
- **llama3.2:3b**: 50-70 tokens/sec (GPU), 10-15 tokens/sec (CPU)
- **mistral:7b**: 20-40 tokens/sec (GPU), 4-8 tokens/sec (CPU)

GPU acceleration provides 3-5x speedup compared to CPU-only containers.

### Documentation Stats

- **README.md**: 341 lines
- **QUICKSTART.md**: 86 lines
- **IMPLEMENTATION.md**: 391 lines
- **EXAMPLES.md**: 544 lines
- **Total documentation**: 1,362 lines

### Code Stats

- **Containerfiles**: 76 lines
- **Configuration**: 102 lines
- **Scripts**: 536 lines
- **Documentation**: 1,362 lines
- **Total project**: ~2,100 lines

### System Requirements

- macOS with Apple Silicon (M1/M2/M3)
- Podman 4.0+ with podman-compose
- 8GB+ RAM available
- 20GB+ disk space
- MongoDB Atlas account (free tier supported)

### Known Limitations

1. GPU acceleration requires specific Podman setup (libkrun provider)
2. ~40% performance overhead compared to native Metal execution
3. First request slower (model loading time)
4. Large models (>7B params) may be slow on M1 chips
5. MCP server requires valid MongoDB URI to start

### Architecture Decisions

- **Podman over Docker**: For GPU acceleration support on macOS
- **Fedora 40 base**: Required for patched MESA drivers
- **Open WebUI**: Most popular and actively maintained LLM UI
- **Official MongoDB MCP**: First-party support and latest features
- **Bridge networking**: Simple and sufficient for local deployment
- **Volume storage**: Persistent data across container restarts

### Alternative Setups Supported

1. **Hybrid mode**: Native Ollama + containerized UI/MCP (best performance)
2. **Docker mode**: Pure Docker setup (maximum compatibility, slower)
3. **CPU-only mode**: Fallback when GPU not available

### Future Enhancements

Potential improvements for future versions:
- Multi-model concurrent support
- Prometheus metrics and Grafana dashboards
- Auto-scaling based on load
- Model fine-tuning pipeline
- RAG (Retrieval-Augmented Generation) support
- Multiple MCP server integration (GitHub, Slack, etc.)
- Web API for programmatic access
- Cloud deployment configurations
- Kubernetes manifests

### References

- [Ollama Documentation](https://github.com/ollama/ollama/tree/main/docs)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [MongoDB MCP Server](https://github.com/mongodb-js/mongodb-mcp-server)
- [Podman GPU Acceleration](https://developers.redhat.com/articles/2025/06/05/how-we-improved-ai-inference-macos-podman-containers)
- [Model Context Protocol](https://modelcontextprotocol.io/)

### Contributors

Implementation based on the comprehensive plan for LLM containerization with GPU acceleration and MongoDB integration.

### License

See individual component licenses:
- Ollama: MIT
- Open WebUI: MIT
- MongoDB MCP Server: Apache 2.0
- This implementation: MIT

---

## Version History

- **1.0.0** (2026-02-05): Initial release
