// Integration tests for mDNS Server FFI interface

use std::ffi::CString;

use facingtime_core::ffi::mdns::{
    ft_mdns_server_create,
    ft_mdns_server_free,
    ft_mdns_server_start,
    ft_mdns_server_stop,
    ft_mdns_server_is_running,
};

/// Helper function to check if a raw pointer is valid (non-null)
fn is_valid_ptr<T>(ptr: *const T) -> bool {
    !ptr.is_null()
}

/// Test: ft_mdns_server_create returns a valid server handle
#[test]
fn test_mdns_server_create_returns_valid_handle() {
    let server = unsafe { ft_mdns_server_create() };
    assert!(is_valid_ptr(server), "mDNS server create should return a non-null handle");

    // Clean up - free the created server
    unsafe { ft_mdns_server_free(server); }
}

/// Test: ft_mdns_server_free handles null pointer safely
#[test]
fn test_mdns_server_free_handles_null() {
    // Should not panic when freeing null pointer
    unsafe { ft_mdns_server_free(std::ptr::null_mut()); }
}

/// Test: ft_mdns_server_is_running on new server returns 0 (not running)
#[test]
fn test_new_mdns_server_is_not_running() {
    let server = unsafe { ft_mdns_server_create() };
    assert!(is_valid_ptr(server), "mDNS server should be created");

    let is_running = unsafe { ft_mdns_server_is_running(server) };
    assert_eq!(is_running, 0, "New mDNS server should not be running");

    unsafe { ft_mdns_server_free(server); }
}

/// Test: ft_mdns_server_start returns success code
#[test]
fn test_mdns_server_start() {
    let server = unsafe { ft_mdns_server_create() };
    assert!(is_valid_ptr(server), "mDNS server should be created");

    let service_type = CString::new("_game._tcp.local.").unwrap();
    let instance_name = CString::new("TestServer").unwrap();
    let hostname = CString::new("testserver").unwrap();
    let port = 3456;

    let result = unsafe {
        ft_mdns_server_start(
            server,
            service_type.as_ptr(),
            instance_name.as_ptr(),
            hostname.as_ptr(),
            port,
        )
    };

    // Server should start successfully (return 1)
    assert_eq!(result, 1, "mDNS server should start successfully");

    // Verify server is now running
    let is_running = unsafe { ft_mdns_server_is_running(server) };
    assert_eq!(is_running, 1, "mDNS server should be running after start");

    // Stop and free
    unsafe { ft_mdns_server_stop(server); }
    unsafe { ft_mdns_server_free(server); }

    // Give the background thread time to complete
    std::thread::sleep(std::time::Duration::from_millis(100));
}

/// Test: ft_mdns_server_stop can be called multiple times safely
#[test]
fn test_mdns_server_stop_multiple_times() {
    let server = unsafe { ft_mdns_server_create() };
    assert!(is_valid_ptr(server), "mDNS server should be created");

    let service_type = CString::new("_game._tcp.local.").unwrap();
    let instance_name = CString::new("TestServer").unwrap();
    let hostname = CString::new("testserver").unwrap();
    let port = 3456;

    unsafe {
        ft_mdns_server_start(
            server,
            service_type.as_ptr(),
            instance_name.as_ptr(),
            hostname.as_ptr(),
            port,
        );
        // Stop multiple times should not panic
        ft_mdns_server_stop(server);
        ft_mdns_server_stop(server);
    }

    unsafe { ft_mdns_server_free(server); }

    // Give the background thread time to complete
    std::thread::sleep(std::time::Duration::from_millis(100));
}

/// Test: mDNS server handle consistency after operations
#[test]
fn test_mdns_server_handle_consistency() {
    let server = unsafe { ft_mdns_server_create() };
    let original_handle = server;
    assert!(is_valid_ptr(server), "mDNS server handle should be valid");

    // Check is_running should not change the handle
    let _ = unsafe { ft_mdns_server_is_running(server) };
    assert_eq!(server, original_handle, "Handle should not change after is_running");

    unsafe { ft_mdns_server_free(server); }
}
