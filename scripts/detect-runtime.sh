#!/bin/bash
# detect-runtime.sh — Detect container runtime (Podman or Docker)
#
# Source this file from other scripts to get:
#   CONTAINER_CMD   — "podman" or "docker"
#   COMPOSE_CMD     — "podman-compose" or "docker compose"
#   COMPOSE_FILE    — "podman-compose.yml" or "docker-compose.yml"
#   RUNTIME_NAME    — "Podman" or "Docker" (for display)
#   RUNTIME_HAS_GPU — "true" or "false" (GPU passthrough available)
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/detect-runtime.sh"

# Allow override via environment variable
if [ -n "$CONTAINER_RUNTIME" ]; then
    case "$CONTAINER_RUNTIME" in
        podman)
            CONTAINER_CMD="podman"
            COMPOSE_CMD="podman-compose"
            COMPOSE_FILE="podman-compose.yml"
            RUNTIME_NAME="Podman"
            RUNTIME_HAS_GPU="true"
            ;;
        docker)
            CONTAINER_CMD="docker"
            COMPOSE_CMD="docker compose"
            COMPOSE_FILE="docker-compose.yml"
            RUNTIME_NAME="Docker"
            RUNTIME_HAS_GPU="false"
            ;;
        *)
            echo "Error: CONTAINER_RUNTIME must be 'podman' or 'docker', got '$CONTAINER_RUNTIME'"
            exit 1
            ;;
    esac
elif command -v podman &>/dev/null && command -v podman-compose &>/dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
    COMPOSE_FILE="podman-compose.yml"
    RUNTIME_NAME="Podman"
    RUNTIME_HAS_GPU="true"
elif command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker compose"
    COMPOSE_FILE="docker-compose.yml"
    RUNTIME_NAME="Docker"
    RUNTIME_HAS_GPU="false"
else
    echo "Error: No container runtime found."
    echo "Please install one of:"
    echo "  Podman (recommended): brew install podman podman-compose"
    echo "  Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

export CONTAINER_CMD COMPOSE_CMD COMPOSE_FILE RUNTIME_NAME RUNTIME_HAS_GPU
