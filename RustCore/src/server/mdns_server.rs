//! mDNS Server implementation using mdns-sd with Tokio runtime.
//!
//! Provides asynchronous mDNS service discovery and registration.

use std::sync::Arc;
use tokio::runtime::Runtime;

use mdns_sd::{DaemonEvent, ServiceDaemon, ServiceInfo};

use crate::error::CoreError;

/// mDNS Server state for FFI interface
#[derive(Clone)]
pub struct MdnsServerState {
    /// mDNS daemon (None when stopped)
    daemon: Option<ServiceDaemon>,

    /// Tokio runtime (None when stopped)
    runtime: Option<Arc<Runtime>>,

    /// Whether the service is currently registered
    is_registered: bool,

    /// Service type (e.g., "_game._tcp.local.")
    pub(super) service_type: String,

    /// Instance name (e.g., "MyServer")
    pub(super) instance_name: String,

    /// Hostname (e.g., "myserver")
    pub(super) hostname: String,

    /// Service port
    pub(super) port: u16,
}

impl Default for MdnsServerState {
    fn default() -> Self {
        Self::new()
    }
}

impl MdnsServerState {
    /// Create a new mDNS server state
    pub fn new() -> Self {
        eprintln!("Creating new MdnsServerState");
        Self {
            daemon: None,
            runtime: None,
            is_registered: false,
            service_type: String::new(),
            instance_name: String::new(),
            hostname: String::new(),
            port: 0,
        }
    }

    /// Check if the mDNS service is running
    pub fn is_running(&self) -> bool {
        self.is_registered
    }

    /// Get the service full name for logging
    pub fn service_fullname(&self) -> String {
        format!("{}.{}.", self.instance_name, self.service_type)
    }

    /// Start the mDNS service registration
    ///
    /// # Arguments
    /// * `service_type` - Service type (e.g., "_game._tcp.local.")
    /// * `instance_name` - Instance name (e.g., "MyServer")
    /// * `hostname` - Hostname (e.g., "myserver")
    /// * `port` - Service port
    ///
    /// # Returns
    /// Ok(()) on success, Err(CoreError) on failure
    pub fn start(
        &mut self,
        service_type: &str,
        instance_name: &str,
        hostname: &str,
        port: u16,
    ) -> Result<(), CoreError> {
        // Check if already running
        if self.is_registered {
            eprintln!("[mDNS] Start failed: service already registered (fullname={}.{}.{})",
                instance_name, service_type, hostname);
            return Err(CoreError::AlreadyRunning);
        }

        eprintln!("[mDNS] Starting service registration...");
        eprintln!("[mDNS]   service_type={}", service_type);
        eprintln!("[mDNS]   instance_name={}", instance_name);
        eprintln!("[mDNS]   hostname={}", hostname);
        eprintln!("[mDNS]   port={}", port);

        // Step 1: Create Tokio runtime
        eprintln!("[mDNS] Step 1/5: Creating Tokio runtime...");
        let runtime = Runtime::new()
            .map_err(|e| {
                eprintln!("[mDNS] Failed to create Tokio runtime: {}", e);
                CoreError::Unknown
            })?;
        eprintln!("[mDNS] Tokio runtime created successfully");
        let runtime = Arc::new(runtime);

        // Step 2: Create mDNS daemon
        eprintln!("[mDNS] Step 2/5: Creating mDNS daemon...");
        let daemon = ServiceDaemon::new()
            .map_err(|e| {
                eprintln!("[mDNS] Failed to create mDNS daemon: {}", e);
                CoreError::Unknown
            })?;
        eprintln!("[mDNS] mDNS daemon created successfully");

        // Step 3: Build service info
        eprintln!("[mDNS] Step 3/5: Building service info...");
        let service_hostname = format!("{}.local.", hostname);
        eprintln!("[mDNS]   service_hostname={}", service_hostname);

        let service_info = ServiceInfo::new::<_, &[(&str, &str)]>(
            service_type,
            instance_name,
            &service_hostname,
            "",
            port,
            &[],
        )
        .map_err(|e| {
            eprintln!("[mDNS] Failed to create service info: {}", e);
            CoreError::Unknown
        })?
        .enable_addr_auto();

        let service_fullname = service_info.get_fullname().to_string();
        eprintln!("[mDNS] Service info built: fullname={}", service_fullname);

        // Step 4: Register service
        eprintln!("[mDNS] Step 4/5: Registering service with mDNS...");
        let daemon_for_monitor = daemon.clone();
        let service_fullname_clone = service_fullname.clone();

        daemon
            .register(service_info.clone())
            .map_err(|e| {
                eprintln!("[mDNS] Failed to register service: {}", e);
                CoreError::Unknown
            })?;
        eprintln!("[mDNS] Service registered successfully with mDNS");

        // Step 5: Spawn monitor task
        eprintln!("[mDNS] Step 5/5: Spawning monitor task...");
        runtime.spawn(async move {
            eprintln!("[mDNS] Monitor task started for {}", service_fullname_clone);

            if let Ok(monitor) = daemon_for_monitor.monitor() {
                loop {
                    // Use recv_timeout to avoid blocking indefinitely
                    match monitor.recv_timeout(tokio::time::Duration::from_secs(1)) {
                        Ok(event) => {
                            eprintln!("[mDNS] Daemon event: {:?}", event);
                            if let DaemonEvent::Error(e) = event {
                                eprintln!("[mDNS] Daemon error: {}", e);
                                break;
                            }
                        }
                        Err(_) => {
                            // Timeout or error - check if daemon is still alive by trying to get service info
                            tracing::debug!("[mDNS] Monitor timeout or error, continuing...");
                            continue;
                        }
                    }
                }
            }

            eprintln!("[mDNS] Monitor task ended for {}", service_fullname_clone);
        });

        // Update state
        eprintln!("[mDNS] Updating internal state...");
        self.daemon = Some(daemon);
        self.runtime = Some(runtime);
        self.is_registered = true;
        self.service_type = service_type.to_string();
        self.instance_name = instance_name.to_string();
        self.hostname = hostname.to_string();
        self.port = port;

        eprintln!("[mDNS] Service started successfully: fullname={}", service_fullname);
        Ok(())
    }

    /// Stop the mDNS service and release resources
    ///
    /// This drops the daemon (which stops the monitor task) and the runtime.
    /// Subsequent start() calls will create new instances.
    pub fn stop(&mut self) {
        if !self.is_registered {
            eprintln!("[mDNS] Stop called but service is not running");
            return;
        }

        let fullname = self.service_fullname();
        eprintln!("[mDNS] Stopping service: {}", fullname);

        // Step 1: Drop daemon (causes monitor task to exit)
        eprintln!("[mDNS] Step 1/2: Dropping daemon (monitor will exit)...");
        self.daemon.take();

        // Step 2: Update state
        eprintln!("[mDNS] Step 2/2: Updating internal state...");
        self.is_registered = false;

        eprintln!("[mDNS] Service stopped successfully: {}", fullname);
    }
}

impl Drop for MdnsServerState {
    fn drop(&mut self) {
        let fullname = self.service_fullname();

        // Don't call stop() here - it can cause panics when dropped inside async context
        // The daemon and runtime will be dropped naturally, which will cancel tasks
        if self.is_registered {
            eprintln!("[mDNS] Dropping MdnsServerState (fullname={}) - resources will be cleaned up", fullname);
        }
        eprintln!("[mDNS] Dropping runtime (stops async tasks)...");
        self.runtime.take();
    }
}
