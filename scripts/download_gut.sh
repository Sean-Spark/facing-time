#!/bin/bash
# Download and extract GUT testing framework for Godot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADDONS_DIR="$PROJECT_DIR/GodotProject/addons"
GUT_URL="https://github.com/bitwes/Gut/archive/refs/tags/v9.5.0.zip"
GUT_ZIP="/tmp/gut.zip"

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Download and extract GUT testing framework"
    echo ""
    echo "Options:"
    echo "  -f, --force    Overwrite existing installation"
    echo "  -h, --help     Show this help message"
}

FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if GUT already exists
if [ -d "$ADDONS_DIR/gut" ]; then
    if [ "$FORCE" = false ]; then
        echo "GUT already exists at $ADDONS_DIR/gut"
        echo "Use -f to overwrite"
        exit 0
    fi
    rm -rf "$ADDONS_DIR/gut"
fi

echo "Downloading GUT..."
mkdir -p "$ADDONS_DIR"
curl -L -o "$GUT_ZIP" "$GUT_URL"

echo "Extracting GUT..."
unzip -q "$GUT_ZIP" -d /tmp
# GUT archive contains Gut-X.X.X/addons/gut/
mv /tmp/Gut-9.5.0/addons/gut "$ADDONS_DIR/gut"
rm -rf /tmp/Gut-9.5.0 "$GUT_ZIP"

echo "GUT installed to $ADDONS_DIR/gut"
