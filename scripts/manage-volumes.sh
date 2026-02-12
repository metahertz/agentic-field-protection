#!/bin/bash
set -e

# Volume management for LLM Container Stack
# Handles listing, inspection, backup, restore, and cleanup of persistent volumes.

OLLAMA_VOLUME="ollama-data"
WEBUI_VOLUME="openwebui-data"

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  list       List all project volumes and their sizes"
    echo "  inspect    Show detailed info for project volumes"
    echo "  backup     Export volumes to tar archives"
    echo "  restore    Import volumes from tar archives"
    echo "  reset      Remove all project volumes (prompts for confirmation)"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 backup                     # Creates backups in ./backups/"
    echo "  $0 backup /path/to/dir        # Creates backups in specified dir"
    echo "  $0 restore                    # Restores from ./backups/"
    echo "  $0 restore /path/to/dir       # Restores from specified dir"
}

cmd_list() {
    echo "Project Volumes"
    echo "==============="
    echo ""

    for vol in "$OLLAMA_VOLUME" "$WEBUI_VOLUME"; do
        if podman volume exists "$vol" 2>/dev/null; then
            mountpoint=$(podman volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null)
            echo "  $vol"
            echo "    Status:     exists"
            echo "    Mountpoint: $mountpoint"
            # Try to get size; may fail if volume is on a VM
            if [ -d "$mountpoint" ]; then
                size=$(du -sh "$mountpoint" 2>/dev/null | cut -f1 || echo "unknown")
                echo "    Size:       $size"
            fi
        else
            echo "  $vol"
            echo "    Status:     not created"
        fi
        echo ""
    done

    # Check for bind mount overrides
    if [ -f .env ]; then
        source .env 2>/dev/null || true
    fi
    if [ -n "${OLLAMA_MODEL_STORAGE:-}" ] && [ "$OLLAMA_MODEL_STORAGE" != "$OLLAMA_VOLUME" ]; then
        echo "Note: Ollama using bind mount at $OLLAMA_MODEL_STORAGE"
    fi
    if [ -n "${OPENWEBUI_DATA_STORAGE:-}" ] && [ "$OPENWEBUI_DATA_STORAGE" != "$WEBUI_VOLUME" ]; then
        echo "Note: Open WebUI using bind mount at $OPENWEBUI_DATA_STORAGE"
    fi
}

cmd_inspect() {
    for vol in "$OLLAMA_VOLUME" "$WEBUI_VOLUME"; do
        if podman volume exists "$vol" 2>/dev/null; then
            echo "--- $vol ---"
            podman volume inspect "$vol"
            echo ""
        else
            echo "--- $vol ---"
            echo "  Volume does not exist."
            echo ""
        fi
    done
}

cmd_backup() {
    local backup_dir="${1:-./backups}"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    mkdir -p "$backup_dir"

    for vol in "$OLLAMA_VOLUME" "$WEBUI_VOLUME"; do
        if podman volume exists "$vol" 2>/dev/null; then
            local dest="$backup_dir/${vol}-${timestamp}.tar"
            echo "Backing up $vol -> $dest"
            podman volume export "$vol" > "$dest"
            echo "  Done ($(du -h "$dest" | cut -f1))"
        else
            echo "Skipping $vol (does not exist)"
        fi
    done

    echo ""
    echo "Backups saved to: $backup_dir"
    ls -lh "$backup_dir"/*.tar 2>/dev/null || true
}

cmd_restore() {
    local backup_dir="${1:-./backups}"

    if [ ! -d "$backup_dir" ]; then
        echo "Error: Backup directory not found: $backup_dir"
        exit 1
    fi

    for vol in "$OLLAMA_VOLUME" "$WEBUI_VOLUME"; do
        # Find the most recent backup for this volume
        local latest
        latest=$(ls -t "$backup_dir"/${vol}-*.tar 2>/dev/null | head -1)

        if [ -z "$latest" ]; then
            echo "No backup found for $vol in $backup_dir"
            continue
        fi

        echo "Restoring $vol from $latest"

        # Create volume if it doesn't exist
        if ! podman volume exists "$vol" 2>/dev/null; then
            podman volume create "$vol"
        fi

        podman volume import "$vol" "$latest"
        echo "  Done"
    done

    echo ""
    echo "Restore complete. Restart services to use restored data:"
    echo "  ./scripts/stop.sh && ./start.sh"
}

cmd_reset() {
    echo "WARNING: This will permanently delete all project volumes."
    echo "The following volumes will be removed:"
    echo "  - $OLLAMA_VOLUME (downloaded models)"
    echo "  - $WEBUI_VOLUME (chat history, settings)"
    echo ""
    read -r -p "Are you sure? (y/N) " confirm

    if [[ "$confirm" != [yY] ]]; then
        echo "Aborted."
        exit 0
    fi

    # Stop services first
    echo "Stopping services..."
    podman-compose down 2>/dev/null || true

    for vol in "$OLLAMA_VOLUME" "$WEBUI_VOLUME"; do
        if podman volume exists "$vol" 2>/dev/null; then
            echo "Removing $vol..."
            podman volume rm "$vol"
        fi
    done

    echo ""
    echo "All project volumes removed."
    echo "Run ./start.sh to recreate volumes and re-download models."
}

# Main
case "${1:-}" in
    list)    cmd_list ;;
    inspect) cmd_inspect ;;
    backup)  cmd_backup "${2:-}" ;;
    restore) cmd_restore "${2:-}" ;;
    reset)   cmd_reset ;;
    -h|--help|help) usage ;;
    *)
        usage
        exit 1
        ;;
esac
