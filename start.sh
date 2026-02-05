#!/bin/bash
set -e

echo "=========================================="
echo "Starting LLM Container Stack"
echo "=========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo ""
    echo "Please create .env from template:"
    echo "  cp .env.template .env"
    echo ""
    echo "Then edit .env and add your MongoDB connection string."
    exit 1
fi

# Load environment variables
source .env

# Validate MongoDB URI
if [[ "$MONGODB_URI" == *"username:password"* ]] || [ -z "$MONGODB_URI" ]; then
    echo "Error: MONGODB_URI not configured in .env"
    echo "Please update .env with your MongoDB Atlas connection string."
    exit 1
fi

# Check if Podman is running
if ! podman machine list | grep -q "Currently running"; then
    echo "Starting Podman machine..."
    podman machine start
    sleep 5
fi

echo "Building containers..."
echo ""

# Build containers
podman-compose build

echo ""
echo "Starting services..."
echo ""

# Start all services
podman-compose up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo "Service Status:"
echo "---------------"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Checking Ollama health..."
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✓ Ollama is running"
else
    echo "✗ Ollama is not responding"
fi

echo ""
echo "Checking Open WebUI health..."
if curl -s http://localhost:${OPENWEBUI_PORT:-8080} > /dev/null; then
    echo "✓ Open WebUI is running"
else
    echo "✗ Open WebUI is not responding"
fi

echo ""
echo "=========================================="
echo "Services Started Successfully!"
echo "=========================================="
echo ""
echo "Access Open WebUI at: http://localhost:${OPENWEBUI_PORT:-8080}"
echo ""
echo "Downloading initial model (${OLLAMA_MODEL:-llama3.2:3b})..."
echo "This may take several minutes depending on your connection..."
echo ""

# Pull the default model
./scripts/pull-model.sh "${OLLAMA_MODEL:-llama3.2:3b}"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Quick Start:"
echo "1. Open http://localhost:${OPENWEBUI_PORT:-8080} in your browser"
echo "2. Start chatting with the LLM"
echo "3. Use MongoDB MCP tools by asking questions about your database"
echo ""
echo "Useful commands:"
echo "  ./scripts/logs.sh [service]  - View logs"
echo "  ./scripts/stop.sh            - Stop all services"
echo "  ./scripts/pull-model.sh      - Download additional models"
echo "  ./scripts/benchmark.sh       - Run performance tests"
echo ""
