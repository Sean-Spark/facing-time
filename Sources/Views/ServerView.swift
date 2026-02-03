import SwiftUI

struct ServerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var portInput: String = ""
    @State private var showingPortAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    serverStatusCard
                    portConfigSection
                    quickActionsSection
                    chatRoomSection
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Web 服务器")
            .onAppear { portInput = String(appState.serverPort) }
            .alert("端口设置", isPresented: $showingPortAlert) {
                TextField("端口号", text: $portInput)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                Button("取消", role: .cancel) {}
                Button("确定") { updatePort() }
            } message: {
                Text("请输入1-65535之间的端口号")
            }
        }
    }

    private var serverStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: appState.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(appState.isRunning ? .green : .red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.isRunning ? "运行中" : "已停止")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if appState.isRunning {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本机: http://localhost:\(appState.localPort)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !appState.localIPAddress.isEmpty {
                                Text("局域网: http://\(appState.localIPAddress):\(appState.localPort)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 8) {
                            Button { copyLANURL() } label: {
                                Label("复制局域网地址", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            #if os(iOS)
                            Button { openInBrowser() } label: {
                                Label("打开", systemImage: "safari")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            #endif
                        }
                    }
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 16) {
                if appState.isRunning {
                    Button { appState.stopServer() } label: {
                        Label("停止服务器", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button { appState.startServer() } label: {
                        Label("启动服务器", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var portConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("端口设置")
                .font(.headline)

            HStack {
                Image(systemName: "network.port")
                    .foregroundStyle(.secondary)

                Text("服务器端口: \(appState.serverPort)")
                    .font(.body)

                Spacer()

                Button("修改") {
                    showingPortAlert = true
                }
                .buttonStyle(.bordered)
                .disabled(appState.isRunning)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷操作")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "link",
                    title: "查看聊天",
                    subtitle: "访问 /chat",
                    action: { openURL(path: "/chat") }
                )

                QuickActionButton(
                    icon: "chart.bar",
                    title: "服务器状态",
                    subtitle: "访问 /api/status",
                    action: { openURL(path: "/api/status") }
                )
            }
        }
    }

    private var chatRoomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("聊天室")
                .font(.headline)

            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.blue)

                Text("通过浏览器访问 /chat 页面即可参与实时聊天")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func copyLANURL() {
        let lanURL = "http://\(appState.localIPAddress):\(appState.localPort)"
        #if os(iOS)
        UIPasteboard.general.string = lanURL
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lanURL, forType: .string)
        #endif
    }

    private func openInBrowser() {
        let lanURL = "http://\(appState.localIPAddress):\(appState.localPort)"
        guard let url = URL(string: lanURL) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func openURL(path: String) {
        let lanURL = "http://\(appState.localIPAddress):\(appState.localPort)\(path)"
        guard let url = URL(string: lanURL) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func updatePort() {
        if let port = Int(portInput), port > 0 && port <= 65535 {
            appState.updateServerPort(port)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ServerView()
        .environmentObject(AppState(networkService: NetworkService.shared))
}
