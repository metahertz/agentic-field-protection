#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/detect-runtime.sh
source "$SCRIPT_DIR/detect-runtime.sh"

# Usage: ./scripts/pull-model.sh [OPTIONS] [MODEL...]
#
# Pull one or more Ollama models. Models can be specified as positional
# arguments, via the MODEL env var, or via OLLAMA_MODEL in .env.
#
# Options:
#   --list    List currently downloaded models and exit
#   --help    Show this help message
#
# Examples:
#   ./scripts/pull-model.sh                      # Pull default (llama3.2:3b)
#   ./scripts/pull-model.sh llama3.2:1b          # Pull a specific model
#   ./scripts/pull-model.sh mistral:7b phi3:3.8b # Pull multiple models
#   MODEL=qwen2.5:3b ./scripts/pull-model.sh     # Use MODEL env var
#   ./scripts/pull-model.sh --list               # List downloaded models

show_help() {
    echo "Usage: ./scripts/pull-model.sh [OPTIONS] [MODEL...]"
    echo ""
    echo "Pull one or more Ollama models."
    echo ""
    echo "Options:"
    echo "  --list    List currently downloaded models and exit"
    echo "  --help    Show this help message"
    echo ""
    echo "Model priority: positional args > MODEL env var > OLLAMA_MODEL env var > llama3.2:3b"
    echo ""
    echo "Popular models:"
    echo "  llama3.2:1b    Smallest, fastest (1.3GB)"
    echo "  llama3.2:3b    Recommended default (2GB)"
    echo "  phi3:3.8b      Microsoft's efficient model (2.3GB)"
    echo "  qwen2.5:3b     Excellent for coding (2GB)"
    echo "  mistral:7b     Strong general-purpose (4.1GB)"
    echo "  llama3.1:8b    Larger, more capable (4.7GB)"
}

list_models() {
    if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "Error: Ollama is not running."
        echo "Please start the services first with ./start.sh"
        exit 1
    fi
    echo "Downloaded models:"
    echo "------------------"
    curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4
}

# Parse options
MODELS=()
for arg in "$@"; do
    case "$arg" in
        --list)
            list_models
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            MODELS+=("$arg")
            ;;
    esac
done

# If no positional args, fall back to MODEL env var, then OLLAMA_MODEL, then default
if [ ${#MODELS[@]} -eq 0 ]; then
    DEFAULT_MODEL="${MODEL:-${OLLAMA_MODEL:-llama3.2:3b}}"
    MODELS=("$DEFAULT_MODEL")
fi

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "Error: Ollama is not running."
    echo "Please start the services first with ./start.sh"
    exit 1
fi

# Pull each model
for MODEL_NAME in "${MODELS[@]}"; do
    echo "Pulling Ollama model: $MODEL_NAME"
    echo "This may take several minutes..."
    echo ""

    $CONTAINER_CMD exec ollama ollama pull "$MODEL_NAME"

    echo ""
    echo "Model $MODEL_NAME downloaded successfully!"
    echo ""
done

echo "Available models:"
curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4
