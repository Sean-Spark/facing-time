use std::ffi::CString;
use std::time::Duration;

use facingtime_core::ffi::server::{
    ft_http_server_create,
    ft_http_server_free,
    ft_http_server_start,
    ft_http_server_stop,
    ft_http_server_is_running,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let server = unsafe { ft_http_server_create() };
    let address = CString::new("127.0.0.1:8080").unwrap();
    let static_dir = CString::new("./web").unwrap();

    let result = unsafe {
        ft_http_server_start(server, address.as_ptr(), static_dir.as_ptr(), 1)
    };
    println!("\nStart server result {}", result);
    // Wait for server to be running
    loop {
        let is_running = unsafe { ft_http_server_is_running(server) };
        if is_running == 1 {
            println!("Server is running. Press Ctrl+C to stop.");
            break;
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }

    // Wait for Ctrl+C
    tokio::signal::ctrl_c().await?;

    println!("\nShutting down server...");

    unsafe {
        ft_http_server_stop(server);
        ft_http_server_free(server);
    }

    println!("Server stopped and freed.");

    Ok(())
}