#!/bin/bash
# Build script for RustCore library
# Compiles Rust core library for multiple platforms and copies to Godot gdextension

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$SCRIPT_DIR/RustCore"
GODOT_EXT_DIR="$SCRIPT_DIR/GodotProject/gdextension"
GODOT_RES_DIR="$SCRIPT_DIR/GodotProject/resources"
LIB_NAME="facingtime_core"
TLS_DIR="$GODOT_RES_DIR/tls"

# Platform configurations: name target
PLATFORMS=(
    "macOS aarch64-apple-darwin"
    "iOS aarch64-apple-ios"
)

build_platform() {
    local name="$1"
    local target="$2"

    echo "Building for $name (${target})..."
    cargo build --release --target "$target"
    cargo build --target "$target"
    echo "$name build complete"
}

sign_library() {
    local library="$1"
    if [ -f "$library" ]; then
        codesign --force --sign - --deep "$library" 2>/dev/null || true
    fi
}

copy_library() {
    local platform="$1"
    local target="$2"

    mkdir -p "$GODOT_EXT_DIR/$platform/debug"
    mkdir -p "$GODOT_EXT_DIR/$platform/release"

    local ext="dylib"
    local lib_prefix="lib"

    rm -f "$GODOT_EXT_DIR/$platform/lib${LIB_NAME}.${ext}"
    cp "target/$target/debug/${lib_prefix}${LIB_NAME}.${ext}" "$GODOT_EXT_DIR/$platform/debug/"
    cp "target/$target/release/${lib_prefix}${LIB_NAME}.${ext}" "$GODOT_EXT_DIR/$platform/release/"

    # Sign macOS debug library for Godot compatibility
    if [ "$platform" = "macOS" ]; then
        echo "Signing macOS library..."
        sign_library "$GODOT_EXT_DIR/$platform/debug/lib${LIB_NAME}.dylib"
        sign_library "$GODOT_EXT_DIR/$platform/release/lib${LIB_NAME}.dylib"
    fi

    echo "Copied $platform library to Godot gdextension"
}

generate_tls_certificates() {
    echo "Generating TLS certificates..."
    mkdir -p "$TLS_DIR"

    local cert_file="$TLS_DIR/cert.pem"
    local key_file="$TLS_DIR/key.pem"

    # Generate private key and self-signed certificate
    openssl req -x509 -newkey rsa:2048 -keyout "$key_file" -out "$cert_file" \
        -days 9999 -nodes -subj "/C=CN/ST=Shanghai/L=Shanghai/O=qo-oq/CN=qo-oq.local" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "TLS certificates generated:"
        echo "  Certificate: $cert_file"
        echo "  Private Key: $key_file"
    else
        echo "Failed to generate TLS certificates"
        exit 1
    fi
}

main() {
    # Generate TLS certificates for WebSocket server
    generate_tls_certificates

    echo "Building RustCore..."
    cd "$RUST_DIR"

    for config in "${PLATFORMS[@]}"; do
        read -r platform target <<< "$config"
        build_platform "$platform" "$target"
        copy_library "$platform" "$target"
    done

    echo ""
    echo "Build complete!"
    echo "Outputs:"
    for config in "${PLATFORMS[@]}"; do
        read -r platform target <<< "$config"
        echo "  $platform: $GODOT_EXT_DIR/$platform/"
    done
}

main "$@"
