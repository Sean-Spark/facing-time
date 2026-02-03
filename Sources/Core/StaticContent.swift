import Foundation

// MARK: - Static Content Loader

enum StaticContent {
    static var chatHTML: String {
        guard let url = Bundle.main.url(forResource: "chat", withExtension: "html"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return defaultChatHTML
        }
        return content
    }

    static let defaultChatHTML = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>FacingTime Chat</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; margin-top: 0; }
        #messages { height: 300px; overflow-y: auto; border: 1px solid #ddd; border-radius: 8px; padding: 10px; margin-bottom: 15px; }
        .message { padding: 8px 12px; margin: 5px 0; border-radius: 8px; background: #e8f4fc; }
        .message .username { font-weight: bold; color: #0066cc; }
        .message .time { color: #999; font-size: 0.8em; }
        .input-group { display: flex; gap: 10px; flex-wrap: wrap; }
        input { flex: 1; min-width: 120px; padding: 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 16px; }
        button { padding: 12px 24px; background: #0066cc; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 16px; }
        button:hover { background: #0055aa; }
        .status { color: #666; margin-bottom: 15px; padding: 10px; background: #f0f0f0; border-radius: 8px; }
        @media (max-width: 480px) { .container { padding: 15px; } input { min-width: 100%; } }
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
        let shownMessages = new Set();
        function addMessage(msg) {
            if (shownMessages.has(msg.id)) return;
            shownMessages.add(msg.id);
            const div = document.createElement('div');
            div.className = 'message';
            div.innerHTML = '<span class="username">' + msg.username + '</span> <span class="time">' + new Date(msg.timestamp).toLocaleTimeString() + '</span><br>' + msg.content;
            const container = document.getElementById('messages');
            container.appendChild(div);
            container.scrollTop = container.scrollHeight;
        }
        async function sendMessage() {
            const username = document.getElementById('username').value || 'Anonymous';
            const message = document.getElementById('message').value;
            if (!message) return;
            await fetch('/api/messages', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({username, content: message}) });
            document.getElementById('message').value = '';
        }
        document.getElementById('message').addEventListener('keypress', (e) => { if (e.key === 'Enter') sendMessage(); });
        async function fetchMessages() {
            try {
                const resp = await fetch('/api/messages');
                const data = await resp.json();
                data.messages.forEach(addMessage);
            } catch (e) {}
        }
        setInterval(fetchMessages, 1000);
        fetchMessages();
    </script>
</body>
</html>
"""
}
