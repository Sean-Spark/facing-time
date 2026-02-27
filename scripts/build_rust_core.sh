#!/bin/bash
# Build script for RustCore library
# Compiles Rust core library for multiple platforms and copies to Godot gdextension

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$PROJECT_DIR/RustCore"
GODOT_EXT_DIR="$PROJECT_DIR/GodotProject/gdextension"
GODOT_RES_DIR="$PROJECT_DIR/GodotProject/resources"
LIB_NAME="facingtime_core"

# Platform configurations: name target
PLATFORMS=(
    "macOS aarch64-apple-darwin"
    "iOS aarch64-apple-ios"
    "Linux x86_64-unknown-linux-gnu"
    "Windows x86_64-pc-windows-gnu"
)

# Default: build all platforms
BUILD_PLATFORMS=()

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build RustCore library for Godot gdextension"
    echo ""
    echo "Options:"
    echo "  -p, --platform PLATFORM   Build for specific platform (can be specified multiple times)"
    echo "  -a, --all                 Build for all platforms (default)"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Supported platforms:"
    for config in "${PLATFORMS[@]}"; do
        read -r platform target <<< "$config"
        echo "  $platform"
    done
    echo ""
    echo "Examples:"
    echo "  $0                        # Build all platforms"
    echo "  $0 -p macOS               # Build only macOS"
    echo "  $0 -p Linux -p Windows    # Build Linux and Windows"
    echo "  $0 --all                  # Build all platforms"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--platform)
                BUILD_PLATFORMS+=("$2")
                shift 2
                ;;
            -a|--all)
                BUILD_PLATFORMS=()
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

    # If no platform specified, build all
    if [ ${#BUILD_PLATFORMS[@]} -eq 0 ]; then
        for config in "${PLATFORMS[@]}"; do
            read -r platform target <<< "$config"
            BUILD_PLATFORMS+=("$platform")
        done
    fi
}

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

    # Determine library extension based on platform
    local ext="dylib"
    local lib_prefix="lib"
    case "$platform" in
        Linux)
            ext="so"
            ;;
        Windows)
            ext="dll"
            lib_prefix=""
            ;;
        macOS|iOS)
            ext="dylib"
            ;;
    esac

    rm -f "$GODOT_EXT_DIR/$platform/lib${LIB_NAME}.${ext}" "$GODOT_EXT_DIR/$platform/${LIB_NAME}.${ext}"
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

main() {
    parse_args "$@"

    # Validate requested platforms
    for requested in "${BUILD_PLATFORMS[@]}"; do
        local valid=false
        for config in "${PLATFORMS[@]}"; do
            read -r platform target <<< "$config"
            if [ "$requested" = "$platform" ]; then
                valid=true
                break
            fi
        done
        if [ "$valid" = false ]; then
            echo "Error: Unknown platform '$requested'"
            show_help
            exit 1
        fi
    done

    echo "Building RustCore..."
    cd "$RUST_DIR"

    for config in "${PLATFORMS[@]}"; do
        read -r platform target <<< "$config"

        # Check if this platform should be built
        local should_build=false
        for requested in "${BUILD_PLATFORMS[@]}"; do
            if [ "$requested" = "$platform" ]; then
                should_build=true
                break
            fi
        done

        if [ "$should_build" = true ]; then
            build_platform "$platform" "$target"
            copy_library "$platform" "$target"
        else
            echo "Skipping $platform (not requested)"
        fi
    done

    echo ""
    echo "Build complete!"
    echo "Outputs:"
    for requested in "${BUILD_PLATFORMS[@]}"; do
        echo "  $requested: $GODOT_EXT_DIR/$requested/"
    done
}

main "$@"
