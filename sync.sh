#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

get_tracked_files() {
    find "$DOTFILES_DIR" -type f \
        -not -path "*/.git/*" \
        -not -name "sync.sh" | sort
}

usage() {
    echo "Usage: $0 [push|pull|list]"
    echo ""
    echo "Commands:"
    echo "  push    Copy dotfiles from this repo to home directory"
    echo "  pull    Copy dotfiles from home directory to this repo"
    echo "  list    Show all tracked dotfiles"
    echo ""
    exit 1
}

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

get_system_path() {
    local rel_path="$1"

    # Special case mappings for specific files
    case "$rel_path" in
        "global.focus-config")
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "/Users/${USER}/Library/Application Support/dev.focus-editor/global.focus-config"
            else
                echo "$HOME_DIR/$rel_path"
            fi
            ;;
        *)
            echo "$HOME_DIR/$rel_path"
            ;;
    esac
}

copy_file() {
    local src="$1"
    local dest="$2"
    local action="$3"

    if [[ -f "$src" ]]; then
        ensure_dir "$(dirname "$dest")"
        # echo "$action: $src -> $dest"
        cp "$src" "$dest"
    else
        echo "Warning: Source file does not exist: $src"
    fi
}

push_dotfiles() {
    echo "Pushing dotfiles from repo to home directory..."

    local count=0
    while IFS= read -r src_file; do
        rel_path="${src_file#$DOTFILES_DIR/}"
        dest_file="$(get_system_path "$rel_path")"
        copy_file "$src_file" "$dest_file" "Push"
        ((count++))
    done < <(get_tracked_files)

    echo "Push completed! ($count files processed)"
}

pull_dotfiles() {
    echo "Pulling dotfiles from home directory to repo..."

    local count=0
    while IFS= read -r dest_file; do
        rel_path="${dest_file#$DOTFILES_DIR/}"
        src_file="$(get_system_path "$rel_path")"
        copy_file "$src_file" "$dest_file" "Pull"
        ((count++))
    done < <(get_tracked_files)

    echo "Pull completed! ($count files processed)"
}

if [[ $# -eq 0 ]]; then
    usage
fi

case "$1" in
    push)
        push_dotfiles
        ;;
    pull)
        pull_dotfiles
        ;;
    list)
        echo "Tracked dotfiles:"
        while IFS= read -r file; do
            rel_path="${file#$DOTFILES_DIR/}"
            echo "  ~/$rel_path"
        done < <(get_tracked_files)
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        usage
        ;;
esac