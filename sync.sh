#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

get_tracked_files() {
    find "$DOTFILES_DIR" -type f \
        -not -path "*/.git/*" \
        -not -name "README.md" \
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
        .config/Code/User/*)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # Map .config/Code/User/* to ~/Library/Application Support/Code/User/*
                local vscode_path="${rel_path#.config/Code/User/}"
                echo "/Users/${USER}/Library/Application Support/Code/User/${vscode_path}"
            else
                echo "$HOME_DIR/$rel_path"
            fi
            ;;
        .config/focus-editor/*)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # Map .config/focus-editor/* to ~/Library/Application Support/dev.focus-editor/*
                local focus_path="${rel_path#.config/focus-editor/}"
                echo "/Users/${USER}/Library/Application Support/dev.focus-editor/${focus_path}"
            else
                echo "$HOME_DIR/$rel_path"
            fi
            ;;
        .config/Sublime\ Text/Packages/User/*|.config/Sublime\ Text/Packages/user/*)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # Map .config/Sublime Text/Packages/User/* to ~/Library/Application Support/Sublime Text/Packages/User/*
                local sublime_path="${rel_path#.config/Sublime\ Text/Packages/User/}"
                [[ -z "$sublime_path" ]] && sublime_path="${rel_path#.config/Sublime\ Text/Packages/user/}"
                echo "/Users/${USER}/Library/Application Support/Sublime Text/Packages/User/${sublime_path}"
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

sync_emacs_dir() {
    local src_base="$1"
    local dest_base="$2"
    local action="$3"

    # Files to sync
    local files=("custom.el" "init.el")
    # Directories to sync (cleared first)
    local dirs=("lisp" "themes")

    # Sync individual files
    for file in "${files[@]}"; do
        local src="$src_base/$file"
        local dest="$dest_base/$file"
        if [[ -f "$src" ]]; then
            ensure_dir "$dest_base"
            cp "$src" "$dest"
        fi
    done

    # Sync directories (clear destination first)
    for dir in "${dirs[@]}"; do
        local src_dir="$src_base/$dir"
        local dest_dir="$dest_base/$dir"
        if [[ -d "$src_dir" ]]; then
            # Clear destination directory
            if [[ -d "$dest_dir" ]]; then
                rm -rf "$dest_dir"
            fi
            # Copy directory
            cp -r "$src_dir" "$dest_dir"
        fi
    done
}

sync_sublime_dir() {
    local src_base="$1"
    local dest_base="$2"
    local action="$3"

    # Sync the entire Packages/User directory (clear destination first)
    local src_dir="$src_base/Packages/User"
    local dest_dir="$dest_base/Packages/User"
    
    if [[ -d "$src_dir" ]]; then
        # Clear destination directory
        if [[ -d "$dest_dir" ]]; then
            rm -rf "$dest_dir"
        fi
        # Ensure parent directory exists
        ensure_dir "$(dirname "$dest_dir")"
        # Copy directory
        cp -r "$src_dir" "$dest_dir"
    fi
}

push_dotfiles() {
    echo "Pushing dotfiles from repo to home directory..."

    # Handle .emacs.d specially (clear folders before syncing)
    if [[ -d "$DOTFILES_DIR/.emacs.d" ]]; then
        sync_emacs_dir "$DOTFILES_DIR/.emacs.d" "$HOME_DIR/.emacs.d" "Push"
    fi

    # Handle Sublime Text specially (clear folders before syncing)
    if [[ -d "$DOTFILES_DIR/.config/Sublime Text" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sync_sublime_dir "$DOTFILES_DIR/.config/Sublime Text" "/Users/${USER}/Library/Application Support/Sublime Text" "Push"
        else
            sync_sublime_dir "$DOTFILES_DIR/.config/Sublime Text" "$HOME_DIR/.config/Sublime Text" "Push"
        fi
    fi

    local count=0
    while IFS= read -r src_file; do
        rel_path="${src_file#$DOTFILES_DIR/}"
        # Skip .emacs.d files (handled above)
        if [[ "$rel_path" == .emacs.d/* ]]; then
            continue
        fi
        # Skip Sublime Text files (handled above)
        if [[ "$rel_path" == .config/Sublime\ Text/* ]]; then
            continue
        fi
        dest_file="$(get_system_path "$rel_path")"
        copy_file "$src_file" "$dest_file" "Push"
        ((count++))
    done < <(get_tracked_files)

    echo "Push completed! ($count files processed)"
}

pull_dotfiles() {
    echo "Pulling dotfiles from home directory to repo..."

    # Handle .emacs.d specially (clear folders before syncing)
    if [[ -d "$HOME_DIR/.emacs.d" ]]; then
        sync_emacs_dir "$HOME_DIR/.emacs.d" "$DOTFILES_DIR/.emacs.d" "Pull"
    fi

    # Handle Sublime Text specially (clear folders before syncing)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ -d "/Users/${USER}/Library/Application Support/Sublime Text" ]]; then
            sync_sublime_dir "/Users/${USER}/Library/Application Support/Sublime Text" "$DOTFILES_DIR/.config/Sublime Text" "Pull"
        fi
    else
        if [[ -d "$HOME_DIR/.config/Sublime Text" ]]; then
            sync_sublime_dir "$HOME_DIR/.config/Sublime Text" "$DOTFILES_DIR/.config/Sublime Text" "Pull"
        fi
    fi

    local count=0
    while IFS= read -r dest_file; do
        rel_path="${dest_file#$DOTFILES_DIR/}"
        # Skip .emacs.d files (handled above)
        if [[ "$rel_path" == .emacs.d/* ]]; then
            continue
        fi
        # Skip Sublime Text files (handled above)
        if [[ "$rel_path" == .config/Sublime\ Text/* ]]; then
            continue
        fi
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
