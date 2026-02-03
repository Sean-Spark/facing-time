#!/bin/bash
# Build Rust core library for iOS and macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building FacingTime Rust Core..."

# Install dependencies if needed
cargo fetch 2>/dev/null || true

# Build for macOS (x86_64)
echo "Building for macOS x86_64..."
cargo build --release --target x86_64-apple-darwin

# Build for macOS (Apple Silicon)
echo "Building for macOS arm64..."
cargo build --release --target aarch64-apple-darwin

# Build for iOS (arm64)
echo "Building for iOS arm64..."
cargo build --release --target aarch64-apple-ios

# Build for iOS Simulator
echo "Building for iOS Simulator..."
cargo build --release --target aarch64-apple-ios-sim

echo "Build complete!"
echo "Libraries available in target/release/"
