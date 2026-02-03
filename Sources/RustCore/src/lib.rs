use std::collections::HashMap;
use std::sync::Arc;
use parking_lot::RwLock;
use uuid::Uuid;
use bytes::BytesMut;
use regex::Regex;
use serde::{Serialize, Deserialize};

pub struct HttpRequest {
    pub method: String,
    pub path: String,
    pub headers: HashMap<String, String>,
    pub body: Option<String>,
}

pub struct HttpResponse {
    pub status_code: u16,
    pub headers: HashMap<String, String>,
    pub body: Option<String>,
}

impl HttpResponse {
    pub fn new(status_code: u16) -> Self {
        Self {
            status_code,
            headers: HashMap::new(),
            body: None,
        }
    }

    pub fn with_body(mut self, body: String, content_type: &str) -> Self {
        self.body = Some(body);
        self.headers.insert("Content-Type".to_string(), content_type.to_string());
        self
    }

    pub fn json<T: Serialize>(self, data: &T) -> Self {
        let json = serde_json::to_string(data).unwrap_or_default();
        self.with_body(json, "application/json")
    }
}

#[derive(Clone)]
pub struct ChatMessage {
    pub id: String,
    pub username: String,
    pub content: String,
    pub timestamp: u64,
}

#[derive(Clone)]
pub struct ChatRoom {
    messages: Arc<RwLock<Vec<ChatMessage>>>,
    clients: Arc<RwLock<HashMap<String, tokio::sync::mpsc::Sender<ChatMessage>>>>,
}

impl ChatRoom {
    pub fn new() -> Self {
        Self {
            messages: Arc::new(RwLock::new(Vec::new())),
            clients: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn add_message(&self, username: String, content: String) -> ChatMessage {
        let msg = ChatMessage {
            id: Uuid::new_v4().to_string(),
            username,
            content,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
        };
        self.messages.write().push(msg.clone());
        msg
    }

    pub fn get_messages(&self, limit: Option<usize>) -> Vec<ChatMessage> {
        let messages = self.messages.read();
        match limit {
            Some(n) => messages.iter().rev().take(n).cloned().collect(),
            None => messages.clone(),
        }
    }

    pub fn register_client(&self, client_id: String, sender: tokio::sync::mpsc::Sender<ChatMessage>) {
        self.clients.write().insert(client_id, sender);
    }

    pub fn unregister_client(&self, client_id: &str) {
        self.clients.write().remove(client_id);
    }

    pub fn broadcast(&self, message: ChatMessage) {
        let clients = self.clients.read().clone();
        for sender in clients.values() {
            let msg = message.clone();
            tokio::spawn(async move {
                let _ = sender.send(msg).await;
            });
        }
    }
}

pub struct Router {
    routes: HashMap<(String, String), fn(&HttpRequest) -> HttpResponse>,
    chat_room: Arc<ChatRoom>,
}

impl Router {
    pub fn new() -> Self {
        let mut routes = HashMap::new();
        let chat_room = Arc::new(ChatRoom::new());

        // HTML endpoints
        routes.insert(("GET".to_string(), "/".to_string()), Self::handle_index);
        routes.insert(("GET".to_string(), "/chat".to_string()), Self::handle_chat);
        routes.insert(("GET".to_string(), "/api/status".to_string()), Self::handle_status);

        // Chat API endpoints
        routes.insert(("GET".to_string(), "/api/messages".to_string()), Self::handle_get_messages);
        routes.insert(("POST".to_string(), "/api/messages".to_string()), Self::handle_post_message);

        Self { routes, chat_room }
    }

    pub fn route(&self, req: &HttpRequest) -> HttpResponse {
        let key = (req.method.clone(), req.path.clone());
        if let Some(handler) = self.routes.get(&key) {
            return handler(req);
        }
        HttpResponse::new(404).with_body("Not Found".to_string(), "text/plain")
    }

    fn handle_index(_req: &HttpRequest) -> HttpResponse {
        let html = r#"<!DOCTYPE html>
<html>
<head>
    <title>FacingTime Chat</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: system-ui, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; margin-top: 0; }
        #messages { height: 300px; overflow-y: auto; border: 1px solid #ddd; border-radius: 8px; padding: 10px; margin-bottom: 15px; }
        .message { padding: 8px 12px; margin: 5px 0; border-radius: 8px; background: #e8f4fc; }
        .message .username { font-weight: bold; color: #0066cc; }
        .message .time { color: #999; font-size: 0.8em; }
        .input-group { display: flex; gap: 10px; }
        input { flex: 1; padding: 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 16px; }
        button { padding: 12px 24px; background: #0066cc; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 16px; }
        button:hover { background: #0055aa; }
        .status { color: #666; margin-bottom: 15px; padding: 10px; background: #f0f0f0; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>FacingTime Chat</h1>
        <div class="status">Connected to local server</div>
        <div id="messages"></div>
        <div class="input-group">
            <input type="text" id="username" placeholder="Your name" />
            <input type="text" id="message" placeholder="Type a message..." />
            <button onclick="sendMessage()">Send</button>
        </div>
    </div>
    <script>
        const ws = new WebSocket(`ws://${window.location.host}/ws`);
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            addMessage(data.username, data.content, new Date(data.timestamp).toLocaleTimeString());
        };
        ws.onopen = () => console.log('Connected to chat');
        ws.onclose = () => console.log('Disconnected from chat');

        function addMessage(username, content, time) {
            const div = document.createElement('div');
            div.className = 'message';
            div.innerHTML = `<span class="username">${username}</span> <span class="time">${time}</span><br>${content}`;
            document.getElementById('messages').appendChild(div);
            document.getElementById('messages').scrollTop = document.getElementById('messages').scrollHeight;
        }

        async function sendMessage() {
            const username = document.getElementById('username').value || 'Anonymous';
            const message = document.getElementById('message').value;
            if (!message) return;
            await fetch('/api/messages', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({username, content: message})
            });
            document.getElementById('message').value = '';
        }

        document.getElementById('message').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });
    </script>
</body>
</html>"#.to_string();
        HttpResponse::new(200).with_body(html, "text/html")
    }

    fn handle_chat(_req: &HttpRequest) -> Self::Output {
        Self::handle_index(_req)
    }

    fn handle_status(_req: &HttpRequest) -> HttpResponse {
        let status = serde_json::json!({
            "status": "running",
            "service": "FacingTime WebServer",
            "version": "1.0.0"
        });
        HttpResponse::new(200).json(&status)
    }

    fn handle_get_messages(req: &HttpRequest) -> HttpResponse {
        let limit = req.headers.get("X-Limit")
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(50);
        let messages = vec![];
        HttpResponse::new(200).json(&messages)
    }

    fn handle_post_message(req: &HttpRequest) -> HttpResponse {
        HttpResponse::new(200).json(&serde_json::json!({"status": "ok"}))
    }
}

pub struct HttpServer {
    router: Arc<Router>,
}

impl HttpServer {
    pub fn new() -> Self {
        Self {
            router: Arc::new(Router::new()),
        }
    }

    pub fn handle_request(&self, method: &str, path: &str, headers: &str, body: Option<&str>) -> Vec<u8> {
        let req = HttpRequest {
            method: method.to_string(),
            path: path.to_string(),
            headers: Self::parse_headers(headers),
            body: body.map(|s| s.to_string()),
        };

        let response = self.router.route(&req);
        Self::serialize_response(&response)
    }

    fn parse_headers(header_str: &str) -> HashMap<String, String> {
        let mut headers = HashMap::new();
        for line in header_str.lines() {
            if let Some(pos) = line.find(':') {
                let key = line[..pos].trim().to_string();
                let value = line[pos+1..].trim().to_string();
                headers.insert(key, value);
            }
        }
        headers
    }

    fn serialize_response(resp: &HttpResponse) -> Vec<u8> {
        let status_text = match resp.status_code {
            200 => "OK",
            400 => "Bad Request",
            404 => "Not Found",
            500 => "Internal Server Error",
            _ => "Unknown",
        };

        let mut output = format!(
            "HTTP/1.1 {} {}\r\nContent-Length: {}\r\nConnection: close\r\n",
            resp.status_code,
            status_text,
            resp.body.as_ref().map_or(0, |b| b.len())
        );

        for (k, v) in &resp.headers {
            output.push_str(&format!("{}: {}\r\n", k, v));
        }
        output.push_str("\r\n");

        let mut result = output.into_bytes();
        if let Some(body) = &resp.body {
            result.extend(body.as_bytes());
        }

        result
    }
}

// FFI functions for Swift
#[no_mangle]
pub extern "C" fn ft_http_server_new() -> *mut HttpServer {
    Box::into_raw(Box::new(HttpServer::new()))
}

#[no_mangle]
pub extern "C" fn ft_http_server_free(ptr: *mut HttpServer) {
    if !ptr.is_null() {
        unsafe { Box::from_raw(ptr); }
    }
}

#[no_mangle]
pub extern "C" fn ft_http_server_handle_request(
    server: *mut HttpServer,
    method: *const libc::c_char,
    path: *const libc::c_char,
    headers: *const libc::c_char,
    body: *const libc::c_char,
) -> *mut libc::c_char {
    unsafe {
        if server.is_null() {
            return std::ptr::null_mut();
        }

        let method = std::ffi::CStr::from_ptr(method).to_string_lossy().into_owned();
        let path = std::ffi::CStr::from_ptr(path).to_string_lossy().into_owned();
        let headers = std::ffi::CStr::from_ptr(headers).to_string_lossy().into_owned();
        let body_ptr = if body.is_null() { None } else {
            Some(std::ffi::CStr::from_ptr(body).to_string_lossy().into_owned())
        };

        let response = (*server).handle_request(
            &method,
            &path,
            &headers,
            body_ptr.as_deref(),
        );

        let c_string = std::ffi::CString::new(response).unwrap();
        c_string.into_raw()
    }
}

#[no_mangle]
pub extern "C" fn ft_http_server_free_response(ptr: *mut libc::c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = std::ffi::CString::from_raw(ptr);
        }
    }
}
