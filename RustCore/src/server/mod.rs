//! Server module - HTTP server implementation with axum.
//!
//! Provides HTTP server functionality with routing, WebSocket support,
//! static file serving, and mDNS service discovery.
//!
//! This module is only available on native platforms (not wasm32).

#[cfg(not(target_arch = "wasm32"))]
pub mod http_server;
#[cfg(not(target_arch = "wasm32"))]
pub mod router;
#[cfg(not(target_arch = "wasm32"))]
pub mod mdns_server;

#[cfg(not(target_arch = "wasm32"))]
pub use http_server::HttpServerState;
#[cfg(not(target_arch = "wasm32"))]
pub use mdns_server::MdnsServerState;
