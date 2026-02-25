//! Godot integration for RustCore HTTP Server and mDNS
//!
//! This module provides a Godot-native class that wraps the HTTP server and mDNS,
//! allowing GDScript to control the Rust HTTP server and mDNS service.

use godot::prelude::*;
use crate::server::{HttpServerState, MdnsServerState};

/// Godot class that wraps the Rust HTTP server and mDNS
///
/// Exposes the following methods to GDScript:
/// HTTP Server:
/// - `create_server() -> bool`
/// - `start_server(address: String, static_dir: String, use_https: bool) -> bool`
/// - `stop_server()`
/// - `is_running() -> bool`
/// - `free_server()`
/// mDNS:
/// - `create_mdns() -> bool`
/// - `start_mdns(service_type: String, instance_name: String, hostname: String, port: i32) -> bool`
/// - `stop_mdns()`
/// - `is_mdns_running() -> bool`
/// - `free_mdns()`
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct RustCoreServer {
    /// Inner HTTP server state
    http_server: Option<HttpServerState>,
    /// Inner mDNS server state
    mdns_server: Option<MdnsServerState>,
}

#[godot_api]
impl IRefCounted for RustCoreServer {
    fn init(_base: Base<RefCounted>) -> Self {
        godot_print!("[RustCoreServer] Constructor called");
        Self {
            http_server: None,
            mdns_server: None,
        }
    }
}

impl Drop for RustCoreServer {
    fn drop(&mut self) {
        self.stop_server();
        self.stop_mdns();
        self.free_server();
        self.free_mdns();
        godot_print!("[RustCoreServer] Destructor called - resources cleaned up");
    }
}

#[godot_api]
impl RustCoreServer {
    // === HTTP Server Methods ===

    #[func]
    fn create_server(&mut self) -> bool {
        if self.http_server.is_some() {
            eprintln!("Server already created");
            return true;
        }

        self.http_server = Some(HttpServerState::new());
        eprintln!("RustCoreServer created successfully");
        true
    }

    #[func]
    fn start_server(&mut self, address: String, static_dir: String, use_https: bool) -> bool {
        let http_server = match self.http_server.as_mut() {
            Some(s) => s,
            None => {
                eprintln!("Error: Server not created. Call create_server() first.");
                return false;
            }
        };

        if use_https {
            match http_server.start_https(&address, &static_dir) {
                Ok(_) => {
                    eprintln!("HTTPS server started on {}", address);
                    true
                }
                Err(e) => {
                    eprintln!("Failed to start HTTPS server: {:?}", e);
                    false
                }
            }
        } else {
            match http_server.start(&address, &static_dir) {
                Ok(_) => {
                    eprintln!("HTTP server started on {}", address);
                    true
                }
                Err(e) => {
                    eprintln!("Failed to start HTTP server: {:?}", e);
                    false
                }
            }
        }
    }

    #[func]
    fn stop_server(&mut self) {
        if let Some(http_server) = self.http_server.as_mut() {
            http_server.stop();
            eprintln!("Server stopped");
        } else {
            eprintln!("Server not running (no http_server instance)");
        }
    }

    #[func]
    fn is_running(&self) -> bool {
        match self.http_server.as_ref() {
            Some(s) => s.is_running(),
            None => false,
        }
    }

    /// Get detailed server status for debugging
    #[func]
    fn get_status(&self) -> String {
        let http_status = match self.http_server.as_ref() {
            Some(s) => {
                if s.is_running() {
                    "running"
                } else {
                    "stopped"
                }
            }
            None => "not created",
        };

        let mdns_status = match self.mdns_server.as_ref() {
            Some(s) => {
                if s.is_running() {
                    "running"
                } else {
                    "stopped"
                }
            }
            None => "not created",
        };

        format!("HTTP: {}, mDNS: {}", http_status, mdns_status)
    }

    /// Get the HTTP server address if running, empty string otherwise
    #[func]
    fn get_server_address(&self) -> String {
        match self.http_server.as_ref() {
            Some(s) => s.get_address(),
            None => String::new(),
        }
    }

    #[func]
    fn free_server(&mut self) {
        self.http_server = None;
        eprintln!("Server freed");
    }

    // === mDNS Methods ===

    #[func]
    fn create_mdns(&mut self) -> bool {
        if self.mdns_server.is_some() {
            eprintln!("mDNS server already created");
            return true;
        }

        self.mdns_server = Some(MdnsServerState::new());
        eprintln!("mDNS server created successfully");
        true
    }

    #[func]
    fn start_mdns(&mut self, service_type: String, instance_name: String, hostname: String, port: i32) -> bool {
        eprintln!("Starting mDNS: type={}, instance={}, hostname={}, port={}",
            service_type, instance_name, hostname, port);

        let mdns_server = match self.mdns_server.as_mut() {
            Some(s) => s,
            None => {
                eprintln!("Error: mDNS not created. Call create_mdns() first.");
                return false;
            }
        };

        match mdns_server.start(&service_type, &instance_name, &hostname, port as u16) {
            Ok(_) => {
                let fullname = format!("{}.{}.", instance_name, service_type);
                eprintln!("mDNS service registered: {}", fullname);
                true
            }
            Err(e) => {
                eprintln!("Failed to start mDNS: {:?}", e);
                false
            }
        }
    }

    #[func]
    fn stop_mdns(&mut self) {
        if let Some(mdns_server) = self.mdns_server.as_mut() {
            if mdns_server.is_running() {
                let fullname = mdns_server.service_fullname();
                mdns_server.stop();
                eprintln!("mDNS service stopped: {}", fullname);
            } else {
                eprintln!("mDNS service not running");
            }
        } else {
            eprintln!("mDNS not created (no mdns_server instance)");
        }
    }

    #[func]
    fn is_mdns_running(&self) -> bool {
        match self.mdns_server.as_ref() {
            Some(s) => s.is_running(),
            None => false,
        }
    }

    #[func]
    fn free_mdns(&mut self) {
        self.mdns_server = None;
        eprintln!("mDNS server freed");
    }
}
