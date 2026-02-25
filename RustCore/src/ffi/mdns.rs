// mDNS Server FFI implementation - exports C-compatible functions

use std::ffi::CStr;
use std::os::raw::c_char;

/// Pointer type for MdnsServerState
pub type FtMdnsServer = crate::server::MdnsServerState;

/// Create a new mDNS server instance
///
/// # Safety
/// The returned pointer must be freed with ft_mdns_server_free
#[no_mangle]
pub unsafe extern "C" fn ft_mdns_server_create() -> *mut FtMdnsServer {
    let server = Box::new(FtMdnsServer::new());
    Box::into_raw(server)
}

/// Free an mDNS server instance
///
/// # Safety
/// The pointer must be valid and will be consumed.
/// This function drops the server in a separate thread to avoid
/// "Cannot drop a runtime in a context where blocking is not allowed" errors.
#[no_mangle]
pub unsafe extern "C" fn ft_mdns_server_free(server: *mut FtMdnsServer) {
    if server.is_null() {
        return;
    }
    let server = Box::from_raw(server);

    // Drop the server in a separate thread to avoid tokio runtime conflicts
    std::thread::spawn(|| {
        drop(server);
    });
}

/// Start the mDNS service registration
///
/// # Arguments
/// * `server` - Server handle
/// * `service_type` - Service type (e.g., "_game._tcp.local.")
/// * `instance_name` - Instance name (e.g., "MyServer")
/// * `hostname` - Hostname (e.g., "myserver")
/// * `port` - Service port
///
/// # Returns
/// 1 on success, 0 on failure
#[no_mangle]
pub unsafe extern "C" fn ft_mdns_server_start(
    server: *mut FtMdnsServer,
    service_type: *const c_char,
    instance_name: *const c_char,
    hostname: *const c_char,
    port: u16,
) -> i32 {
    if server.is_null() {
        return 0;
    }

    let service_type = if service_type.is_null() {
        "_service._tcp.local.".to_string()
    } else {
        match CStr::from_ptr(service_type).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return 0,
        }
    };

    let instance_name = if instance_name.is_null() {
        "Instance".to_string()
    } else {
        match CStr::from_ptr(instance_name).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return 0,
        }
    };

    let hostname = if hostname.is_null() {
        "server".to_string()
    } else {
        match CStr::from_ptr(hostname).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return 0,
        }
    };

    // Dereference mutable pointer (safe because we checked for null)
    let server = &mut *server;
    match server.start(&service_type, &instance_name, &hostname, port) {
        Ok(()) => 1,
        Err(_) => 0,
    }
}

/// Stop the mDNS service
///
/// # Arguments
/// * `server` - Server handle
#[no_mangle]
pub unsafe extern "C" fn ft_mdns_server_stop(server: *mut FtMdnsServer) {
    if server.is_null() {
        return;
    }
    let server = &mut *server;
    server.stop();
}

/// Check if the mDNS service is running
///
/// # Arguments
/// * `server` - Server handle
///
/// # Returns
/// 1 if running, 0 if not
#[no_mangle]
pub unsafe extern "C" fn ft_mdns_server_is_running(server: *mut FtMdnsServer) -> i32 {
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
