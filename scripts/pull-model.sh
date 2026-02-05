#!/bin/bash
set -e

MODEL=${1:-llama3.2:3b}

echo "Pulling Ollama model: $MODEL"
echo "This may take several minutes..."
echo ""

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "Error: Ollama is not running."
    echo "Please start the services first with ./start.sh"
    exit 1
fi

# Pull the model using Ollama API
podman exec ollama ollama pull "$MODEL"

echo ""
echo "Model $MODEL downloaded successfully!"
echo ""
echo "Available models:"
curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4
