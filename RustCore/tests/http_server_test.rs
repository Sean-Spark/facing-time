// Integration tests for RustCore FFI interface
// These tests verify the FFI functions are properly exported and functional

use std::ffi::CString;

use facingtime_core::ffi::server::{
    ft_http_server_create,
    ft_http_server_free,
    ft_http_server_start,
    ft_http_server_stop,
    ft_http_server_is_running,
};

/// Helper function to check if a raw pointer is valid (non-null)
fn is_valid_ptr<T>(ptr: *const T) -> bool {
    !ptr.is_null()
}

/// Test: ft_http_server_create returns a valid server handle
#[test]
fn test_server_create_returns_valid_handle() {
    let server = unsafe { ft_http_server_create() };
    assert!(is_valid_ptr(server), "Server create should return a non-null handle");

    // Clean up - free the created server
    unsafe { ft_http_server_free(server); }
}

/// Test: ft_http_server_free handles null pointer safely
#[test]
fn test_server_free_handles_null() {
    // Should not panic when freeing null pointer
    unsafe { ft_http_server_free(std::ptr::null_mut()); }
}

/// Test: ft_http_server_is_running on new server returns 0 (not running)
#[test]
fn test_new_server_is_not_running() {
    let server = unsafe { ft_http_server_create() };
    assert!(is_valid_ptr(server), "Server should be created");

    let is_running = unsafe { ft_http_server_is_running(server) };
    assert_eq!(is_running, 0, "New server should not be running");

    unsafe { ft_http_server_free(server); }
}

/// Test: Server handle consistency after operations
#[test]
fn test_server_handle_consistency() {
    let server = unsafe { ft_http_server_create() };
    let original_handle = server;
    assert!(is_valid_ptr(server), "Server handle should be valid");

    // Check is_running should not change the handle
    let _ = unsafe { ft_http_server_is_running(server) };
    assert_eq!(server, original_handle, "Handle should not change after is_running");

    unsafe { ft_http_server_free(server); }
}

/// Test: ft_http_server_start returns success code
#[test]
fn test_server_start() {
    let server = unsafe { ft_http_server_create() };
    assert!(is_valid_ptr(server), "Server should be created");

    let address = CString::new("127.0.0.1:0").unwrap(); // Use random port
    let static_dir = CString::new("/tmp").unwrap();

    let result = unsafe {
        ft_http_server_start(server, address.as_ptr(), static_dir.as_ptr() ,0)
    };

    // Server should start successfully (return 1)
    assert_eq!(result, 1, "Server should start successfully");

    // Verify server is now running
    let is_running = unsafe { ft_http_server_is_running(server) };
    assert_eq!(is_running, 1, "Server should be running after start");

    // Stop and free
    unsafe { ft_http_server_stop(server); }
    unsafe { ft_http_server_free(server); }
}

/// Test: ft_http_server_stop can be called multiple times safely
#[test]
fn test_server_stop_multiple_times() {
    let server = unsafe { ft_http_server_create() };
    assert!(is_valid_ptr(server), "Server should be created");

    let address = CString::new("127.0.0.1:0").unwrap();
    let static_dir = CString::new("/tmp").unwrap();

    unsafe {
        ft_http_server_start(server, address.as_ptr(), static_dir.as_ptr(), 0);
        // Stop multiple times should not panic
        ft_http_server_stop(server);
        ft_http_server_stop(server);
    }

    unsafe { ft_http_server_free(server); }
}
