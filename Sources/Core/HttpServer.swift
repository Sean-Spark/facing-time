import Foundation
import Network

// MARK: - HTTP Request

struct HttpRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?

    init(method: String, path: String, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    var bodyString: String? { body.flatMap { String(data: $0, encoding: .utf8) } }
}

// MARK: - HTTP Response

struct HttpResponse {
    var statusCode: Int
    var headers: [String: String]
    var body: Data?

    static func ok(html: String) -> HttpResponse {
        var resp = HttpResponse(statusCode: 200, headers: ["Content-Type": "text/html; charset=utf-8"])
        resp.body = html.data(using: .utf8)
        return resp
    }

    static func ok(json: [String: Any]) -> HttpResponse {
        var resp = HttpResponse(statusCode: 200, headers: ["Content-Type": "application/json"])
        resp.body = try? JSONSerialization.data(withJSONObject: json, options: [])
        return resp
    }

    static func notFound() -> HttpResponse {
        HttpResponse(statusCode: 404, headers: [:], body: "Not Found".data(using: .utf8))
    }

    static func badRequest() -> HttpResponse {
        HttpResponse(statusCode: 400, headers: [:], body: "Bad Request".data(using: .utf8))
    }

    var serialized: Data {
        var output = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        output += "Content-Length: \(body?.count ?? 0)\r\n"
        output += "Connection: close\r\n"
        headers.forEach { output += "\($0.key): \($0.value)\r\n" }
        output += "\r\n"

        var data = output.data(using: .utf8) ?? Data()
        if let body = body { data.append(body) }
        return data
    }

    private var statusText: String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

// MARK: - Chat Room

final class ChatRoom {
    private(set) var messages: [ChatMessage] = []
    private let maxMessages = 100

    func addMessage(username: String, content: String) -> ChatMessage {
        let message = ChatMessage(username: username, content: content)
        messages.append(message)
        if messages.count > maxMessages { messages.removeFirst(messages.count - maxMessages) }
        return message
    }

    func getMessages(limit: Int? = nil) -> [ChatMessage] {
        guard let limit = limit else { return messages }
        return Array(messages.suffix(limit))
    }
}

// MARK: - Chat Message

struct ChatMessage {
    let id: String
    let username: String
    let content: String
    let timestamp: UInt64

    init(username: String, content: String) {
        self.id = UUID().uuidString
        self.username = username
        self.content = content
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Router

final class Router {
    private var routes: [String: (HttpRequest) -> HttpResponse] = [:]
    private let chatRoom = ChatRoom()

    init() { setupRoutes() }

    private func setupRoutes() {
        routes["GET:/"] = { _ in self.handleIndex() }
        routes["GET:/chat"] = { _ in self.handleIndex() }
        routes["GET:/api/status"] = { _ in self.handleStatus() }
        routes["GET:/api/messages"] = { [weak self] req in self?.handleGetMessages(req) ?? .notFound() }
        routes["POST:/api/messages"] = { [weak self] req in self?.handlePostMessage(req) ?? .notFound() }
    }

    func route(request: HttpRequest) -> HttpResponse {
        let key = "\(request.method):\(request.path)"
        return routes[key]?(request) ?? .notFound()
    }

    private func handleIndex() -> HttpResponse { .ok(html: StaticContent.chatHTML) }

    private func handleStatus() -> HttpResponse {
        .ok(json: ["status": "running", "service": "FacingTime WebServer", "version": "1.0.0"])
    }

    private func handleGetMessages(_ request: HttpRequest) -> HttpResponse {
        let limit = request.headers["X-Limit"].flatMap(Int.init) ?? 50
        let messages = chatRoom.getMessages(limit: limit)
        let encodable = messages.map { ["id": $0.id, "username": $0.username, "content": $0.content, "timestamp": $0.timestamp] }
        return .ok(json: ["messages": encodable])
    }

    private func handlePostMessage(_ request: HttpRequest) -> HttpResponse {
        guard let body = request.bodyString,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let username = json["username"] as? String,
              let content = json["content"] as? String else {
            return .badRequest()
        }
        let message = chatRoom.addMessage(username: username, content: content)
        return .ok(json: ["status": "ok", "id": message.id])
    }
}

// MARK: - HTTP Server

final class HttpServer {
    let port: UInt16
    private let router = Router()
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let queue = DispatchQueue(label: "com.facingtime.httpserver")

    init(port: UInt16) { self.port = port }

    func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        listener = try await withCheckedThrowingContinuation { continuation in
            guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!) else {
                continuation.resume(throwing: ServerError.failedToStart)
                return
            }
            continuation.resume(returning: listener)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                print("Server failed: \(error)")
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
        print("HTTP server listening on port \(port)")
    }

    func stop() {
        listener?.cancel()
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func handleConnection(_ connection: NWConnection) {
        let id = UUID()
        connections[id] = connection

        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.connections.removeValue(forKey: id)
            }
        }

        connection.start(queue: queue)
        receiveData(connection: connection, id: id)
    }

    private func receiveData(connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data = data, !data.isEmpty {
                self.processRequest(data: data, connection: connection)
            }
            if isComplete || error != nil {
                connection.cancel()
                self.connections.removeValue(forKey: id)
            } else {
                self.receiveData(connection: connection, id: id)
            }
        }
    }

    private func processRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8),
              let requestLine = requestString.components(separatedBy: "\r\n").first else { return }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return }

        let method = String(parts[0])
        let path = String(parts[1].split(separator: "?").first ?? parts[1])

        // Parse headers
        var headers: [String: String] = [:]
        let headerLines = requestString.components(separatedBy: "\r\n").dropFirst()
        for line in headerLines.prefix(while: { !$0.isEmpty }) {
            if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Parse body
        var body: Data?
        if let range = requestString.range(of: "\r\n\r\n") {
            body = String(requestString[range.upperBound...]).data(using: .utf8)
        }

        let request = HttpRequest(method: method, path: path, headers: headers, body: body)
        let response = router.route(request: request)
        connection.send(content: response.serialized, completion: .idempotent)
    }
}

enum ServerError: Error {
    case failedToStart
}
