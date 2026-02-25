// HTTP Server implementation using axum

use std::future::Future;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio_rustls::TlsAcceptor;
use rustls::ServerConfig as RustlsServerConfig;
use rustls_pemfile::{certs, pkcs8_private_keys};

use crate::error::CoreError;
use crate::types::{ServerConfig, ServerState, SharedServerState};
use parking_lot::Mutex;

use super::router::create_router;

/// HTTP Server state for FFI interface
#[derive(Clone)]
pub struct HttpServerState {
    /// Shared server state protected by mutex
    pub inner: SharedServerState,

    /// Tokio runtime for async operations
    runtime: Option<Arc<Runtime>>,

    /// Server shutdown sender
    shutdown_tx: Option<tokio::sync::watch::Sender<()>>,
}

impl HttpServerState {
    /// Create a new HTTP server state
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(ServerState::default())),
            runtime: None,
            shutdown_tx: None,
        }
    }

    /// Start the HTTP server
    ///
    /// # Arguments
    /// * `address` - Server address to bind to (e.g., "0.0.0.0:8080")
    /// * `static_dir` - Directory for static file serving
    ///
    /// # Returns
    /// Ok(()) on success, Err(CoreError) on failure
    pub fn start(&mut self, address: &str, static_dir: &str) -> Result<(), CoreError> {
        eprintln!("[HTTP] Starting HTTP server on {} with static directory: {}", address, static_dir);

        // Step 1: Check if already running
        eprintln!("[HTTP] Step 1/6: Checking if server is already running...");
        {
            let state = self.inner.lock();
            if state.is_running {
                eprintln!("[HTTP] Start failed: server is already running");
                return Err(CoreError::AlreadyRunning);
            }
        }
        eprintln!("[HTTP] Step 1/6: Server is not running, proceeding...");

        // Step 2: Validate address format
        eprintln!("[HTTP] Step 2/6: Parsing address '{}'...", address);
        let addr: SocketAddr = address
            .parse()
            .map_err(|e| {
                eprintln!("[HTTP] Failed to parse address '{}': {}", address, e);
                CoreError::InvalidAddress(address.to_string())
            })?;
        eprintln!("[HTTP] Step 2/6: Address parsed successfully: {}", addr);

        // Step 3: Create tokio runtime if not exists
        eprintln!("[HTTP] Step 3/6: Creating Tokio runtime...");
        if self.runtime.is_none() {
            let runtime = Runtime::new()
                .map_err(|e| {
                    eprintln!("[HTTP] Failed to create Tokio runtime: {}", e);
                    CoreError::Unknown
                })?;
            self.runtime = Some(Arc::new(runtime));
        }
        eprintln!("[HTTP] Step 3/6: Tokio runtime created successfully");

        let runtime = self.runtime.as_ref().unwrap().clone();

        // Step 4: Update server state
        eprintln!("[HTTP] Step 4/6: Updating server state...");
        {
            let mut state = self.inner.lock();
            state.is_running = true;
            state.config = Some(ServerConfig {
                address: address.to_string(),
                static_dir: static_dir.to_string(),
                use_https: false,
                cert_path: None,
                key_path: None,
            });
        }
        eprintln!("[HTTP] Step 4/6: Server state updated: running=true");

        // Step 5: Create shutdown channel and router
        eprintln!("[HTTP] Step 5/6: Creating shutdown channel and router...");

        let (shutdown_tx, shutdown_rx) = tokio::sync::watch::channel(());
        self.shutdown_tx = Some(shutdown_tx);
        eprintln!("[HTTP]   Shutdown channel created");

        let router = create_router(static_dir);
        eprintln!("[HTTP]   Router created with static directory");

        // Store the state for later reference
        let inner = self.inner.clone();
        let addr_clone = addr.to_string();

        // Step 6: Spawn async server task
        eprintln!("[HTTP] Step 6/6: Spawning async server task...");
        runtime.spawn(async move {
            eprintln!("[HTTP] Async task started, binding to {}", addr_clone);

            // Use axum's serve directly
            let listener = match tokio::net::TcpListener::bind(&addr_clone).await {
                Ok(l) => {
                    eprintln!("[HTTP] TCP listener bound successfully to {}", addr_clone);
                    l
                }
                Err(e) => {
                    eprintln!("[HTTP] Failed to bind TCP listener: {}", e);
                    return;
                }
            };

            eprintln!("[HTTP] Starting axum serve...");

            let server = axum::serve(listener, router)
                .with_graceful_shutdown(watch_shutdown(shutdown_rx));

            eprintln!("[HTTP] HTTP server is now accepting connections");

            if let Err(e) = server.await {
                eprintln!("[HTTP] Server error: {}", e);
                let mut state = inner.lock();
                state.is_running = false;
                eprintln!("[HTTP] Server state updated: running=false (error)");
            }
        });

        eprintln!("[HTTP] HTTP server started successfully on {}", address);
        Ok(())
    }

    /// Start the HTTPS server with auto-generated self-signed certificate
    ///
    /// # Arguments
    /// * `address` - Server address to bind to (e.g., "0.0.0.0:8443")
    /// * `static_dir` - Directory for static file serving
    ///
    /// # Returns
    /// Ok(()) on success, Err(CoreError) on failure
    pub fn start_https(&mut self, address: &str, static_dir: &str) -> Result<(), CoreError> {
        eprintln!("[HTTPS] Starting HTTPS server on {} with static directory: {}", address, static_dir);

        // Step 1: Check if already running
        eprintln!("[HTTPS] Step 1/7: Checking if server is already running...");
        {
            let state = self.inner.lock();
            if state.is_running {
                eprintln!("[HTTPS] Start failed: server is already running");
                return Err(CoreError::AlreadyRunning);
            }
        }
        eprintln!("[HTTPS] Step 1/7: Server is not running, proceeding...");

        // Step 2: Validate address format
        eprintln!("[HTTPS] Step 2/7: Parsing address '{}'...", address);
        let addr: SocketAddr = address
            .parse()
            .map_err(|e| {
                eprintln!("[HTTPS] Failed to parse address '{}': {}", address, e);
                CoreError::InvalidAddress(address.to_string())
            })?;
        eprintln!("[HTTPS] Step 2/7: Address parsed successfully: {}", addr);

        // Step 3: Create self-signed certificate
        eprintln!("[HTTPS] Step 3/7: Generating self-signed certificate...");
        let (cert_pem, key_pem) = generate_self_signed_cert()
            .map_err(|e| {
                eprintln!("[HTTPS] Failed to generate certificate: {}", e);
                CoreError::Unknown
            })?;
        eprintln!("[HTTPS] Step 3/7: Certificate generated successfully");

        // Step 4: Configure TLS
        eprintln!("[HTTPS] Step 4/7: Configuring TLS...");

        // Parse certificate for rustls
        let certs = certs(&mut cert_pem.as_bytes())
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| {
                eprintln!("[HTTPS] Failed to parse certificate: {}", e);
                CoreError::Unknown
            })?;

        // Parse private key for rustls
        let keys = pkcs8_private_keys(&mut key_pem.as_bytes())
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| {
                eprintln!("[HTTPS] Failed to parse private key: {}", e);
                CoreError::Unknown
            })?;

        let key = keys.into_iter().next().ok_or_else(|| {
            eprintln!("[HTTPS] No private key found");
            CoreError::Unknown
        })?;

        let key = rustls::pki_types::PrivateKeyDer::Pkcs8(key);

        let tls_config = RustlsServerConfig::builder()
            .with_no_client_auth()
            .with_single_cert(certs, key)
            .map_err(|e| {
                eprintln!("[HTTPS] Failed to configure TLS: {}", e);
                CoreError::Unknown
            })?;

        let tls_acceptor = TlsAcceptor::from(Arc::new(tls_config));
        eprintln!("[HTTPS] Step 4/7: TLS configured successfully");

        // Step 5: Create tokio runtime if not exists
        eprintln!("[HTTPS] Step 5/7: Creating Tokio runtime...");
        if self.runtime.is_none() {
            let runtime = Runtime::new()
                .map_err(|e| {
                    eprintln!("[HTTPS] Failed to create Tokio runtime: {}", e);
                    CoreError::Unknown
                })?;
            self.runtime = Some(Arc::new(runtime));
        }
        eprintln!("[HTTPS] Step 5/7: Tokio runtime created successfully");

        let runtime = self.runtime.as_ref().unwrap().clone();

        // Step 6: Update server state
        eprintln!("[HTTPS] Step 6/7: Updating server state...");
        {
            let mut state = self.inner.lock();
            state.is_running = true;
            state.config = Some(ServerConfig {
                address: address.to_string(),
                static_dir: static_dir.to_string(),
                use_https: true,
                cert_path: None,
                key_path: None,
            });
        }
        eprintln!("[HTTPS] Step 6/7: Server state updated: running=true");

        // Step 7: Spawn async server task
        eprintln!("[HTTPS] Step 7/7: Spawning async HTTPS server task...");

        let (shutdown_tx, shutdown_rx) = tokio::sync::watch::channel(());
        self.shutdown_tx = Some(shutdown_tx);
        eprintln!("[HTTPS]   Shutdown channel created");

        let router = create_router(static_dir);
        eprintln!("[HTTPS]   Router created with static directory");

        let inner = self.inner.clone();
        let addr_clone = addr.to_string();

        runtime.spawn(async move {
            eprintln!("[HTTPS] Async task started, binding to {}", addr_clone);

            let listener = match tokio::net::TcpListener::bind(&addr_clone).await {
                Ok(l) => {
                    eprintln!("[HTTPS] TCP listener bound successfully to {}", addr_clone);
                    l
                }
                Err(e) => {
                    eprintln!("[HTTPS] Failed to bind TCP listener: {}", e);
                    return;
                }
            };

            eprintln!("[HTTPS] Starting HTTPS server with TLS...");

            let acceptor = Arc::new(tls_acceptor);
            let router = Arc::new(router);
            let inner = inner.clone();
            let mut shutdown_rx = shutdown_rx;

            loop {
                tokio::select! {
                    result = listener.accept() => {
                        let (stream, _) = match result {
                            Ok(s) => s,
                            Err(e) => {
                                eprintln!("[HTTPS] Failed to accept connection: {}", e);
                                continue;
                            }
                        };

                        let acceptor = acceptor.clone();
                        let router = router.clone();
                        let inner = inner.clone();

                        tokio::spawn(async move {
                            match acceptor.accept(stream).await {
                                Ok(tls_stream) => {
                                    let io = hyper_util::rt::TokioIo::new(tls_stream);
                                    let inner = inner.clone();

                                    // Dereference Arc to get Router
                                    let router_ref = (*router).clone();

                                    // Create a service from the router
                                    let svc = tower::ServiceBuilder::new()
                                        .layer(tower_http::add_extension::AddExtensionLayer::new(inner))
                                        .service(router_ref);

                                    // Use hyper_util's TowerToHyperService to convert tower service to hyper service
                                    let hyper_svc = hyper_util::service::TowerToHyperService::new(svc);

                                    let hyper_builder = hyper_util::server::conn::auto::Builder::new(
                                        hyper_util::rt::TokioExecutor::new()
                                    );

                                    if let Err(e) = hyper_builder
                                        .serve_connection_with_upgrades(io, hyper_svc)
                                        .await
                                    {
                                        eprintln!("[HTTPS] TLS serve error: {}", e);
                                    }
                                }
                                Err(e) => {
                                    eprintln!("[HTTPS] TLS handshake failed: {}", e);
                                }
                            }
                        });
                    }
                    _ = shutdown_rx.changed() => {
                        eprintln!("[HTTPS] Shutdown signal received");
                        break;
                    }
                }
            }

            let mut state = inner.lock();
            state.is_running = false;
            eprintln!("[HTTPS] Server state updated: running=false");
        });

        eprintln!("[HTTPS] HTTPS server started successfully on {}", address);
        Ok(())
    }

    /// Stop the HTTP server
    ///
    /// Note: This only sends the shutdown signal. The runtime is not dropped
    /// here to avoid panics when called from within the async context.
    /// Use ft_http_server_free to fully release resources.
    pub fn stop(&mut self) {
        eprintln!("[HTTP] Stopping HTTP server...");

        // Step 1: Check current state
        eprintln!("[HTTP] Step 1/3: Checking server state...");
        let was_running = {
            let state = self.inner.lock();
            state.is_running
        };

        if !was_running {
            eprintln!("[HTTP] Stop called but server is not running");
            return;
        }
        eprintln!("[HTTP] Step 1/3: Server was running, proceeding with stop...");

        // Step 2: Send shutdown signal
        eprintln!("[HTTP] Step 2/3: Sending shutdown signal...");
        if self.shutdown_tx.is_some() {
            if let Some(tx) = self.shutdown_tx.take() {
                let _ = tx.send(());
                eprintln!("[HTTP]   Shutdown signal sent");
            }
        } else {
            eprintln!("[HTTP]   No shutdown sender present");
        }

        // Step 3: Update state
        eprintln!("[HTTP] Step 3/3: Updating server state...");
        {
            let mut state = self.inner.lock();
            state.is_running = false;
            state.connected_clients = 0;
        }
        eprintln!("[HTTP] Server state updated: running=false, connected_clients=0");
    }

    /// Check if the server is running
    pub fn is_running(&self) -> bool {
        let state = self.inner.lock();
        let is_running = state.is_running;
        eprintln!("[HTTP] is_running check: {}", is_running);
        is_running
    }

    /// Get the server address if running
    pub fn get_address(&self) -> String {
        let state = self.inner.lock();
        match &state.config {
            Some(config) => config.address.clone(),
            None => String::new(),
        }
    }
}

/// Generate a self-signed certificate using rcgen
/// Returns (cert_pem, key_pem) as strings
fn generate_self_signed_cert() -> Result<(String, String), rcgen::Error> {
    // In rcgen 0.14+, use generate_simple_self_signed
    let certified_key = rcgen::generate_simple_self_signed(&["localhost".to_string()])?;

    let cert_pem = certified_key.cert.pem();
    let key_pem = certified_key.signing_key.serialize_pem();

    Ok((cert_pem.to_string(), key_pem))
}

/// Create a shutdown future from a watch receiver
fn watch_shutdown(
    mut shutdown_rx: tokio::sync::watch::Receiver<()>,
) -> impl Future<Output = ()> {
    async move {
        let _ = shutdown_rx.changed().await;
    }
}

impl Default for HttpServerState {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for HttpServerState {
    fn drop(&mut self) {
        // Don't call stop() here - it can cause panics when dropped inside async context
        // The runtime will be dropped naturally, which will cancel tasks
        eprintln!("[HTTP] Dropping HttpServerState - resources will be cleaned up");

        // Take ownership of resources to drop them
        self.shutdown_tx.take();
        self.runtime.take();
    }
}
