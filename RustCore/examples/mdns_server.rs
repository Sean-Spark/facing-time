use std::ffi::CString;
use std::time::Duration;

use facingtime_core::ffi::mdns::{
    ft_mdns_server_create,
    ft_mdns_server_free,
    ft_mdns_server_start,
    ft_mdns_server_stop,
    ft_mdns_server_is_running,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let server = unsafe { ft_mdns_server_create() };

    let service_type = CString::new("_game._tcp.local.").unwrap();
    let instance_name = CString::new("FacingTimeServer").unwrap();
    let hostname = CString::new("facingtime").unwrap();
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
    println!("\nStart mDNS server result: {}", result);

    // Wait for server to be running
    loop {
        let is_running = unsafe { ft_mdns_server_is_running(server) };
        if is_running == 1 {
            println!("mDNS service is registered.");
            println!("Service: {}.{}", instance_name.to_string_lossy(), service_type.to_string_lossy());
            println!("Hostname: {}.local", hostname.to_string_lossy());
            println!("Port: {}", port);
            println!("Press Ctrl+C to stop.");
            break;
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }

    // Wait for Ctrl+C
    tokio::signal::ctrl_c().await?;

    println!("\nShutting down mDNS service...");

    unsafe {
        ft_mdns_server_stop(server);
        ft_mdns_server_free(server);
    }

    println!("mDNS service stopped and freed.");

    Ok(())
}
