#!/bin/bash
set -e

echo "=========================================="
echo "LLM Performance Benchmark"
echo "=========================================="
echo ""

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "Error: Ollama is not running."
    echo "Please start the services first with ./start.sh"
    exit 1
fi

# Load environment to get model name
if [ -f .env ]; then
    source .env
fi

MODEL=${OLLAMA_MODEL:-llama3.2:3b}

echo "Testing model: $MODEL"
echo ""

# Check GPU acceleration
echo "Checking GPU acceleration..."
echo ""
podman exec ollama sh -c 'if command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo | grep -A5 "GPU"; else echo "vulkaninfo not available"; fi' || echo "Could not check GPU info"
echo ""

# Test prompt processing speed
echo "Running inference test..."
echo "Prompt: 'Write a haiku about containers'"
echo ""

START=$(date +%s.%N)

RESPONSE=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Write a haiku about containers\",
  \"stream\": false
}")

END=$(date +%s.%N)

ELAPSED=$(echo "$END - $START" | bc)

# Extract metrics from response
TOTAL_DURATION=$(echo "$RESPONSE" | grep -o '"total_duration":[0-9]*' | cut -d':' -f2)
LOAD_DURATION=$(echo "$RESPONSE" | grep -o '"load_duration":[0-9]*' | cut -d':' -f2)
PROMPT_EVAL_COUNT=$(echo "$RESPONSE" | grep -o '"prompt_eval_count":[0-9]*' | cut -d':' -f2)
PROMPT_EVAL_DURATION=$(echo "$RESPONSE" | grep -o '"prompt_eval_duration":[0-9]*' | cut -d':' -f2)
EVAL_COUNT=$(echo "$RESPONSE" | grep -o '"eval_count":[0-9]*' | cut -d':' -f2)
EVAL_DURATION=$(echo "$RESPONSE" | grep -o '"eval_duration":[0-9]*' | cut -d':' -f2)

echo ""
echo "=========================================="
echo "Benchmark Results"
echo "=========================================="
echo ""
echo "Model: $MODEL"
echo "Total time: ${ELAPSED}s"
echo ""

if [ -n "$TOTAL_DURATION" ]; then
    TOTAL_SEC=$(echo "scale=2; $TOTAL_DURATION / 1000000000" | bc)
    echo "Total duration: ${TOTAL_SEC}s"
fi

if [ -n "$LOAD_DURATION" ]; then
    LOAD_SEC=$(echo "scale=2; $LOAD_DURATION / 1000000000" | bc)
    echo "Model load time: ${LOAD_SEC}s"
fi

if [ -n "$PROMPT_EVAL_COUNT" ] && [ -n "$PROMPT_EVAL_DURATION" ]; then
    PROMPT_TOKENS_PER_SEC=$(echo "scale=2; $PROMPT_EVAL_COUNT * 1000000000 / $PROMPT_EVAL_DURATION" | bc)
    echo "Prompt processing: $PROMPT_EVAL_COUNT tokens at ${PROMPT_TOKENS_PER_SEC} tokens/sec"
fi

if [ -n "$EVAL_COUNT" ] && [ -n "$EVAL_DURATION" ]; then
    TOKENS_PER_SEC=$(echo "scale=2; $EVAL_COUNT * 1000000000 / $EVAL_DURATION" | bc)
    echo "Token generation: $EVAL_COUNT tokens at ${TOKENS_PER_SEC} tokens/sec"
fi

echo ""
echo "Performance Profile:"
if [ -n "$TOKENS_PER_SEC" ]; then
    if (( $(echo "$TOKENS_PER_SEC > 70" | bc -l) )); then
        echo "✓ Excellent - Likely using GPU acceleration"
    elif (( $(echo "$TOKENS_PER_SEC > 40" | bc -l) )); then
        echo "✓ Good - GPU acceleration active with some overhead"
    elif (( $(echo "$TOKENS_PER_SEC > 15" | bc -l) )); then
        echo "⚠ Moderate - May be CPU-only or suboptimal GPU setup"
    else
        echo "✗ Slow - Likely CPU-only mode"
    fi
fi

echo ""
echo "Expected performance (M2/M3 Mac with $MODEL):"
echo "  Native Metal: 80-100 tokens/sec"
echo "  Podman GPU:   50-70 tokens/sec"
echo "  CPU-only:     10-15 tokens/sec"
echo ""
