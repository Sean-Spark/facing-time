import Foundation
import SwiftUI
import Combine
import Network

#if os(iOS)
import UIKit
#endif

final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published var currentUser: User
    @Published var discoveredServers: [ServerInfo] = []
    @Published var isRunning: Bool = false
    @Published var localPort: Int = 0
    @Published var localURL: String = ""
    @Published var localIPAddress: String = ""
    @Published var serverPort: Int = 8080
    @Published var recentLogs: [LogEntry] = []

    // MARK: - Private Properties

    private let networkService: NetworkService
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(networkService: NetworkService) {
        self.networkService = networkService

        let logger = Logger.shared
        logger.info("AppState initializing...")

        let savedName = userDefaults.string(forKey: "username") ?? ""
        let savedPort = userDefaults.integer(forKey: "serverPort")

        #if os(macOS)
        let deviceName = (try? Host.current().localizedName) ?? "Mac"
        #else
        let deviceName = UIDevice.current.name
        #endif

        self.currentUser = User(id: UUID().uuidString, name: savedName.isEmpty ? deviceName : savedName)
        self.serverPort = savedPort > 0 ? savedPort : 8080
        logger.info("User initialized: \(self.currentUser.name)")

        setupBindings()

        DispatchQueue.main.async { [weak self] in
            self?.startServices()
        }
    }

    private func setupBindings() {
        networkService.$discoveredServers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] servers in
                self?.discoveredServers = servers
            }
            .store(in: &cancellables)

        networkService.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isRunning = running
                self?.localPort = Int(self?.networkService.localServerURL?.port ?? 0)
                self?.localURL = self?.networkService.localServerURL?.absoluteString ?? ""
                self?.localIPAddress = self?.networkService.localIPAddress ?? ""
            }
            .store(in: &cancellables)

        Logger.shared.$recentLogs
            .receive(on: DispatchQueue.main)
            .assign(to: &$recentLogs)
    }

    // MARK: - Public Methods

    func startServices() {
        networkService.startDiscovery()
    }

    func stopServices() {
        networkService.stopServer()
    }

    func startServer() {
        Task {
            do {
                let port = try await networkService.startServer(port: UInt16(serverPort))
                await MainActor.run {
                    self.localPort = Int(port)
                    self.localURL = "http://localhost:\(port)"
                }
            } catch {
                Logger.shared.error("Failed to start server: \(error.localizedDescription)")
            }
        }
    }

    func stopServer() {
        networkService.stopServer()
    }

    func updateUsername(_ name: String) {
        currentUser = User(id: currentUser.id, name: name)
        userDefaults.set(name, forKey: "username")
    }

    func updateServerPort(_ port: Int) {
        serverPort = port
        userDefaults.set(port, forKey: "serverPort")
    }

    func clearLogs() {
        Logger.shared.clearLogs()
    }
}

// MARK: - Supporting Types

struct User: Identifiable, Codable, Equatable {
    let id: String
    var name: String

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
