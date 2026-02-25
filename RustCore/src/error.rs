//! Error types for RustCore.

#[cfg(not(target_arch = "wasm32"))]
use thiserror::Error;

/// Main error type for RustCore operations.
#[derive(Error, Debug)]
pub enum CoreError {
    /// Server is not running when an operation requires it to be running.
    #[error("Server is not running")]
    NotRunning,

    /// Server is already running when a start operation is attempted.
    #[error("Server is already running")]
    AlreadyRunning,

    /// Failed to bind to the specified network address.
    #[error("Failed to bind to address: {0}")]
    BindFailed(String),

    /// The provided address format is invalid.
    #[error("Invalid address format: {0}")]
    InvalidAddress(String),

    /// The static directory does not exist or is not accessible.
    #[error("Static directory not found: {0}")]
    StaticDirNotFound(String),

    /// An I/O operation failed.
    #[error("IO error: {0}")]
    IoError(String),

    /// JSON serialization or deserialization failed.
    #[error("JSON serialization error: {0}")]
    JsonError(String),

    /// An unknown error occurred.
    #[error("Unknown error occurred")]
    Unknown,
}
