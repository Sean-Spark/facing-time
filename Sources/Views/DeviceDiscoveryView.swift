import SwiftUI

struct DeviceDiscoveryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            headerView
            Divider()

            // Content
            if appState.discoveredServers.isEmpty {
                emptyStateView
            } else {
                serverListView
            }
        }
        .navigationTitle("发现设备")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.isRunning ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                .font(.title2)
                .foregroundColor(appState.isRunning ? .green : .secondary)

            Text(appState.isRunning ? "正在搜索附近服务器..." : "未开始搜索")
                .font(.headline)

            Spacer()

            Button(action: toggleSearch) {
                HStack(spacing: 5) {
                    Image(systemName: appState.isRunning ? "xmark.circle.fill" : "magnifyingglass")
                    Text(appState.isRunning ? "取消" : "搜索")
                }
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.isRunning ? .red : .blue)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Spacer()

            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("未发现服务器")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("确保设备在同一局域网中\n并点击搜索按钮开始发现")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Server List

    private var serverListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(appState.discoveredServers) { server in
                    ServerRowView(server: server)
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func toggleSearch() {
        if appState.isRunning {
            appState.stopServices()
        } else {
            appState.startServices()
        }
    }
}

struct ServerRowView: View {
    let server: ServerInfo

    var body: some View {
        HStack(spacing: 15) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 50, height: 50)

                Text(String(server.name.prefix(2)))
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)

                HStack {
                    Text("端口: \(server.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(server.isReachable ? "在线" : "离线")
                        .font(.caption)
                        .foregroundColor(server.isReachable ? .green : .orange)
                }
            }

            Spacer()

            // Open button
            Button(action: openServer) {
                HStack(spacing: 5) {
                    Image(systemName: "safari")
                    Text("访问")
                }
                .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func openServer() {
        let urlString = "http://\(server.host):\(server.port)"
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

#Preview {
    NavigationStack {
        DeviceDiscoveryView()
            .environmentObject(AppState(networkService: NetworkService.shared))
    }
}
