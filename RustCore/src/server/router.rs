//! Router configuration for axum.
//!
//! Provides HTTP routing with static file serving and path traversal protection.

use axum::{
    body::Body,
    extract::{Path, State},
    routing::get,
    response::{IntoResponse, Response},
    Router,
};
use http::StatusCode;
use std::path::PathBuf;
use tokio::sync::broadcast;
use bytes::Bytes;

/// Application state for the router.
#[derive(Clone)]
pub struct AppState {
    /// Directory for serving static files
    pub static_dir: PathBuf,
}

/// Create the main router with all routes.
///
/// # Arguments
/// * `static_dir` - Directory path for static file serving
///
/// # Returns
/// Configured Axum Router
#[allow(dead_code)]
pub fn create_router(static_dir: &str) -> Router {
    // Print directly to stderr for debugging
    eprintln!("[ROUTER] Creating router with static directory: {}", static_dir);

    let static_dir_path = std::path::Path::new(static_dir);
    eprintln!("[ROUTER] Static directory exists: {}", static_dir_path.exists());

    let (tx, _) = broadcast::channel::<Bytes>(100);
    let _ = tx; // Suppress unused warning
    let static_dir = PathBuf::from(static_dir);
    let app_state = AppState { static_dir };

    let router = Router::new()
        .route("/", get(serve_index_html))
        .route("/{*path}", get(serve_static_file))
        .route("/health", get(health_handler))
        .with_state(app_state.clone());

    eprintln!("[ROUTER] Router created successfully with static_dir={}", app_state.static_dir.display());

    router
}

/// Serve index.html for root path
async fn serve_index_html(State(state): State<AppState>) -> impl IntoResponse {
    serve_static_file(Path("index.html".to_string()), State(state)).await
}

/// Health check endpoint handler.
///
/// Returns "OK" to indicate the server is running.
async fn health_handler() -> &'static str {
    tracing::debug!("[ROUTER] Health check request received");
    "OK"
}

/// Serve static files with path traversal protection.
///
/// # Arguments
/// * `path` - The requested file path from URL
/// * `state` - Application state containing static directory
///
/// # Returns
/// File content response or error status code
#[allow(dead_code)]
async fn serve_static_file(Path(path): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    tracing::debug!("Static file request: path={}", path);
    let static_dir = &state.static_dir;

    // 1. Build the requested file path
    let requested_path = PathBuf::from(&path);

    // 2. Resolve the full path by joining with static directory
    let full_path = match static_dir.join(&requested_path).canonicalize() {
        Ok(path) => path,
        Err(e) => {
            eprintln!("File not found: {} (error: {})", requested_path.display(), e);
            return StatusCode::NOT_FOUND.into_response();
        }
    };

    // 3. Security check: verify the resolved path is within static directory
    let static_root = match static_dir.canonicalize() {
        Ok(path) => path,
        Err(e) => {
            // Try to check if directory exists
            let exists = std::path::Path::new(static_dir).exists();
            eprintln!("Failed to canonicalize static directory: {} (exists: {})", e, exists);
            return StatusCode::INTERNAL_SERVER_ERROR.into_response();
        }
    };

    if !full_path.starts_with(&static_root) {
        // Path traversal attack detected
        eprintln!("Path traversal attack detected: requested={}, resolved={}", path, full_path.display());
        return StatusCode::FORBIDDEN.into_response();
    }

    // 4. Check if path is a file (not a directory)
    if full_path.is_dir() {
        eprintln!("Directory access forbidden: {}", full_path.display());
        return StatusCode::FORBIDDEN.into_response();
    }

    // 5. Read and serve the file
    match tokio::fs::read(&full_path).await {
        Ok(content) => {
            // Determine content type from file extension
            let content_type = match full_path.extension().and_then(|e| e.to_str()) {
                Some("html") | Some("htm") => "text/html",
                Some("css") => "text/css",
                Some("js") => "application/javascript",
                Some("json") => "application/json",
                Some("png") => "image/png",
                Some("jpg") | Some("jpeg") => "image/jpeg",
                Some("gif") => "image/gif",
                Some("svg") => "image/svg+xml",
                Some("ico") => "image/x-icon",
                Some("txt") => "text/plain",
                Some("woff") => "font/woff",
                Some("woff2") => "font/woff2",
                _ => "application/octet-stream",
            };

            eprintln!("Served static file: {} ({} bytes)", full_path.display(), content.len());

            Response::builder()
                .status(StatusCode::OK)
                .header(http::header::CONTENT_TYPE, content_type)
                .header("Cross-Origin-Opener-Policy", "same-origin")
                .header("Cross-Origin-Embedder-Policy", "require-corp")
                .body(Body::from(content))
                .unwrap()
        }
        Err(e) => {
            eprintln!("Failed to read file: {} (error: {})", full_path.display(), e);
            StatusCode::NOT_FOUND.into_response()
        }
    }
}
