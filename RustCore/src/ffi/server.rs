// Server FFI implementation - exports C-compatible functions

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

/// Pointer type for HttpServerState
pub type FtHttpServer = crate::server::HttpServerState;

/// Create a new HTTP server instance
///
/// # Safety
/// The returned pointer must be freed with ft_http_server_free
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_create() -> *mut FtHttpServer {
    let server = Box::new(FtHttpServer::new());
    Box::into_raw(server)
}

/// Free an HTTP server instance
///
/// # Safety
/// The pointer must be valid and will be consumed.
/// This function drops the server in a separate thread to avoid
/// "Cannot drop a runtime in a context where blocking is not allowed" errors.
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_free(server: *mut FtHttpServer) {
    if server.is_null() {
        return;
    }
    let server = Box::from_raw(server);

    // Drop the server in a separate thread to avoid tokio runtime conflicts
    std::thread::spawn(|| {
        drop(server);
    });
}

/// Start the HTTP/HTTPS server
///
/// # Arguments
/// * `server` - Server handle
/// * `address` - Address to bind to (e.g., "0.0.0.0:8080" for HTTP, "0.0.0.0:8443" for HTTPS)
/// * `static_dir` - Directory for static files
/// * `use_https` - 1 for HTTPS, 0 for HTTP
///
/// # Returns
/// 1 on success, 0 on failure
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_start(
    server: *mut FtHttpServer,
    address: *const c_char,
    static_dir: *const c_char,
    use_https: i32,
) -> i32 {
    if server.is_null() {
        return 0;
    }

    let address = if address.is_null() {
        "0.0.0.0:8080".to_string()
    } else {
        match CStr::from_ptr(address).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return 0,
        }
    };

    let static_dir = if static_dir.is_null() {
        "/tmp".to_string()
    } else {
        match CStr::from_ptr(static_dir).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return 0,
        }
    };

    // Dereference mutable pointer (safe because we checked for null)
    let server = &mut *server;

    if use_https != 0 {
        match server.start_https(&address, &static_dir) {
            Ok(()) => 1,
            Err(_) => 0,
        }
    } else {
        match server.start(&address, &static_dir) {
            Ok(()) => 1,
            Err(_) => 0,
        }
    }
}

/// Stop the HTTP server
///
/// # Arguments
/// * `server` - Server handle
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_stop(server: *mut FtHttpServer) {
    if server.is_null() {
        return;
    }
    let server = &mut *server;
    server.stop();
}

/// Check if the HTTP server is running
///
/// # Arguments
/// * `server` - Server handle
///
/// # Returns
/// 1 if running, 0 if not
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_is_running(server: *mut FtHttpServer) -> i32 {
    if server.is_null() {
        return 0;
    }
    let server = &*server;
    if server.is_running() {
        1
    } else {
        0
    }
}

/// Handle an HTTP request (for custom request handling)
///
/// # Arguments
/// * `server` - Server handle
/// * `method` - HTTP method
/// * `path` - Request path
/// * `headers` - Request headers (JSON format)
/// * `body` - Request body (optional)
///
/// # Returns
/// JSON response string (must be freed with ft_http_server_free_response)
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_handle_request(
    server: *mut FtHttpServer,
    method: *const c_char,
    path: *const c_char,
    headers: *const c_char,
    body: *const c_char,
) -> *mut c_char {
    if server.is_null() {
        let error = CString::new(r#"{"error": "server is null"}"#).unwrap();
        return error.into_raw();
    }

    let _method_str = if method.is_null() {
        "GET".to_string()
    } else {
        match CStr::from_ptr(method).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return ptr::null_mut(),
        }
    };

    let _path_str = if path.is_null() {
        "/".to_string()
    } else {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return ptr::null_mut(),
        }
    };

    let headers_str = if headers.is_null() {
        "{}".to_string()
    } else {
        match CStr::from_ptr(headers).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return ptr::null_mut(),
        }
    };

    let _body_str = if body.is_null() {
        None
    } else {
        match CStr::from_ptr(body).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return ptr::null_mut(),
        }
    };

    // Build response (simplified - just return success)
    let response = format!(r#"{{"status_code": 200, "headers": {}}}"#, headers_str);

    match CString::new(response) {
        Ok(cstring) => cstring.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

/// Free a response string allocated by Rust
///
/// # Arguments
/// * `response` - Response string to free
#[no_mangle]
pub unsafe extern "C" fn ft_http_server_free_response(response: *mut c_char) {
    if response.is_null() {
        return;
    }
    let _ = CString::from_raw(response);
}
