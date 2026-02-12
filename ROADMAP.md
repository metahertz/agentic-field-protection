# Roadmap — agentic-field-protection

Containerized local LLM setup with GPU acceleration and MongoDB MCP integration.

## P0 — Core Infrastructure

- [x] Podman container setup with GPU acceleration (Vulkan-to-Metal)
- [x] Ollama LLM runtime container
- [x] Open WebUI container
- [x] MongoDB MCP Server container
- [x] Startup / shutdown scripts
- [x] Integration test suite
- [x] CI pipeline (lint, test, container build validation)

## P1 — Hardening

- [ ] Automated health checks in CI
- [ ] Security scan for container images
- [ ] Credential management improvements (secrets, not .env)
- [ ] Performance regression tests (benchmark baselines)

## P2 — Extensions

- [ ] Multi-model support (switch models without rebuild)
- [ ] Persistent volume configuration for model cache
- [ ] ARM64 Linux support (beyond macOS)
- [ ] Docker fallback for non-Podman environments

## Out of Scope

- Cloud deployment / Kubernetes
- Custom model training or fine-tuning
- Non-MongoDB database integrations
- GUI/desktop application wrappers
