import Foundation
import Network
import Darwin

// MARK: - Server Info

struct ServerInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let port: UInt16
    var isReachable: Bool

    init(name: String, host: String, port: UInt16) {
        self.id = UUID().uuidString
        self.name = name
        self.host = host
        self.port = port
        self.isReachable = false
    }
}

// MARK: - Network Service

final class NetworkService: NSObject, ObservableObject {
    static let shared = NetworkService()

    @Published private(set) var isRunning = false
    @Published private(set) var discoveredServers: [ServerInfo] = []
    @Published private(set) var localServerURL: URL?
    @Published private(set) var localIPAddress: String = ""

    private var httpServer: HttpServer?
    private var bonjourBrowser: NetServiceBrowser?
    private var bonjourServices: [String: NetService] = [:]

    private let bonjourType = "_facingtime._tcp."
    private let serverName = "FacingTime"
    private let defaultPort: UInt16 = 8080

    private override init() {
        super.init()
    }

    // MARK: - Start Server

    func startServer(port: UInt16? = nil) async throws -> UInt16 {
        let actualPort = port ?? defaultPort
        httpServer = HttpServer(port: actualPort)
        try await httpServer?.start()

        await MainActor.run {
            self.isRunning = true
            self.localIPAddress = self.getLANIPAddress()
            let lanURL = "http://\(self.localIPAddress):\(actualPort)"
            self.localServerURL = URL(string: lanURL)
            self.publishService(port: actualPort)
        }

        return actualPort
    }

    // MARK: - Private Methods

    private func getLANIPAddress() -> String {
        var address: String = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return address
        }

        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)

            // Skip loopback and inactive interfaces
            if name.hasPrefix("en") {  // Ethernet/Wi-Fi interfaces
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                              &hostname, socklen_t(hostname.count), nil, 0,
                              NI_NUMERICHOST) == 0 {
                    address = String(cString: hostname)
                    break
                }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }

        return address
    }

    func stopServer() {
        httpServer?.stop()
        httpServer = nil
        unpublishService()

        Task { @MainActor in
            self.isRunning = false
            self.localServerURL = nil
        }
    }

    // MARK: - Bonjour Service Publishing

    private func publishService(port: UInt16) {
        let service = NetService(domain: "local.", type: bonjourType, name: serverName, port: Int32(port))
        service.delegate = self
        service.publish()
    }

    private func unpublishService() {
        bonjourServices.values.forEach { $0.stop() }
        bonjourServices.removeAll()
    }

    // MARK: - Service Discovery

    func startDiscovery() {
        bonjourBrowser = NetServiceBrowser()
        bonjourBrowser?.delegate = self
        bonjourBrowser?.searchForServices(ofType: bonjourType, inDomain: "local.")
    }

    func stopDiscovery() {
        bonjourBrowser?.stop()
        bonjourBrowser = nil
        discoveredServers.removeAll()
    }
}

// MARK: - NetServiceDelegate

extension NetworkService: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour service published: \(sender.name)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: String]) {
        print("Failed to publish service: \(errorDict)")
    }

    func netServiceDidResolve(_ sender: NetService) {
        let server = ServerInfo(
            name: sender.name,
            host: sender.hostName ?? "localhost",
            port: UInt16(sender.port)
        )

        Task { @MainActor in
            if let index = self.discoveredServers.firstIndex(where: { $0.name == server.name }) {
                self.discoveredServers[index] = server
            } else {
                self.discoveredServers.append(server)
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: String]) {
        print("Failed to resolve service: \(errorDict)")
    }

    func netServiceDidStop(_ sender: NetService) {
        Task { @MainActor in
            self.discoveredServers.removeAll { $0.name == sender.name }
        }
    }
}

// MARK: - NetServiceBrowserDelegate

extension NetworkService: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        bonjourServices[service.name] = service
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        bonjourServices.removeValue(forKey: service.name)

        Task { @MainActor in
            self.discoveredServers.removeAll { $0.name == service.name }
        }
    }
}
