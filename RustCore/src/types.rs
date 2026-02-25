//! Shared types for RustCore.

use std::sync::Arc;
use parking_lot::Mutex;

/// Server state configuration.
#[derive(Clone, Debug)]
pub struct ServerConfig {
    /// Network address to bind to (e.g., "0.0.0.0:8080")
    pub address: String,
    /// Directory path for static files
    pub static_dir: String,
    /// Whether to use HTTPS
    pub use_https: bool,
    /// Path to TLS certificate file (PEM format)
    pub cert_path: Option<String>,
    /// Path to TLS private key file (PEM format)
    pub key_path: Option<String>,
}

/// HTTP request data.
#[derive(Clone, Debug)]
pub struct HttpRequest {
    /// HTTP method (GET, POST, etc.)
    pub method: String,
    /// Request path
    pub path: String,
    /// Request headers in JSON format
    pub headers: String,
    /// Optional request body
    pub body: Option<String>,
}

/// HTTP response data.
#[derive(Clone, Debug)]
pub struct HttpResponse {
    /// HTTP status code
    pub status_code: i32,
    /// Response body content
    pub body: String,
    /// Response headers in JSON format
    pub headers: String,
}

/// WebSocket message.
#[derive(Clone, Debug)]
pub struct WebSocketMessage {
    /// Message content
    pub content: String,
    /// Unix timestamp in milliseconds
    pub timestamp: u64,
}

/// Shared server state protected by mutex.
pub type SharedServerState = Arc<Mutex<ServerState>>;

/// Internal server state.
#[derive(Clone, Debug, Default)]
pub struct ServerState {
    /// Whether the server is currently running
    pub is_running: bool,
    /// Number of connected WebSocket clients
    pub connected_clients: usize,
    /// Server configuration
    pub config: Option<ServerConfig>,
}
