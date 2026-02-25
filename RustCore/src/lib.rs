//! RustCore - High-performance cross-platform web server library
//!
//! This library provides an efficient concurrent web server implementation
//! using axum and tokio, with FFI bindings for Swift/iOS integration.

#![warn(missing_docs)]
#![allow(non_camel_case_types)]

// Re-export modules
#[cfg(not(target_arch = "wasm32"))]
pub mod error;
#[cfg(not(target_arch = "wasm32"))]
pub mod types;
#[cfg(not(target_arch = "wasm32"))]
pub mod ffi;
#[cfg(not(target_arch = "wasm32"))]
pub mod server;

// Godot integration module (always available)
mod godot_server;

// Re-export commonly used types (native only)
#[cfg(not(target_arch = "wasm32"))]
pub use error::CoreError;
#[cfg(not(target_arch = "wasm32"))]
pub use types::{ServerConfig, HttpRequest, HttpResponse, SharedServerState};
#[cfg(not(target_arch = "wasm32"))]
pub use server::HttpServerState;

use godot::prelude::*;

struct RustExtension;

#[gdextension]
unsafe impl ExtensionLibrary for RustExtension {}
