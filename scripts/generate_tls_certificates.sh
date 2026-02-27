#!/bin/bash
# Generate TLS certificates for WebSocket server
# Creates self-signed certificate and private key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT_RES_DIR="$PROJECT_DIR/GodotProject/resources"
TLS_DIR="$GODOT_RES_DIR/tls"

# Default values
CERT_FILE=""
KEY_FILE=""
DAYS=9999
FORCE=false

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Generate TLS certificates for WebSocket server"
    echo ""
    echo "Options:"
    echo "  -o, --output DIR    Output directory (default: GodotProject/resources/tls)"
    echo "  -d, --days N        Validity days (default: 9999)"
    echo "  -f, --force         Overwrite existing certificates"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Example:"
    echo "  $0                  # Generate certificates in default location"
    echo "  $0 -f               # Overwrite existing certificates"
    echo "  $0 -o /custom/path  # Generate in custom directory"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                TLS_DIR="$2"
                shift 2
                ;;
            -d|--days)
                DAYS="$2"
                shift 2
                ;;
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
}

main() {
    parse_args "$@"

    # Check if certificates already exist
    CERT_FILE="$TLS_DIR/cert.pem"
    KEY_FILE="$TLS_DIR/key.pem"

    if [ -f "$CERT_FILE" ] || [ -f "$KEY_FILE" ]; then
        if [ "$FORCE" = false ]; then
            echo "TLS certificates already exist in $TLS_DIR"
            echo "Use -f to overwrite"
            exit 0
        fi
    fi

    echo "Generating TLS certificates..."
    mkdir -p "$TLS_DIR"

    # Generate private key and self-signed certificate
    openssl req -x509 -newkey rsa:2048 -keyout "$KEY_FILE" -out "$CERT_FILE" \
        -days "$DAYS" -nodes -subj "/C=CN/ST=Shanghai/L=Shanghai/O=qo-oq/CN=qo-oq.local" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "TLS certificates generated:"
        echo "  Certificate: $CERT_FILE"
        echo "  Private Key: $KEY_FILE"
    else
        echo "Failed to generate TLS certificates"
        exit 1
    fi
}

main "$@"
