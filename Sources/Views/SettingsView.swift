import SwiftUI

#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var showResetAlert: Bool = false
    @State private var showDebugLog = false

    var body: some View {
        Form {
            Section("个人信息") {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 60, height: 60)

                        Text(String((appState.currentUser.name.isEmpty ? "?" : appState.currentUser.name).prefix(2)))
                            .font(.title.bold())
                            .foregroundColor(.white)
                    }

                    TextField("用户名", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: username) { newValue in
                            appState.updateUsername(newValue)
                        }
                }
                .padding(.vertical, 8)
            }

            Section("设备信息") {
                LabeledContent("设备ID", value: appState.currentUser.id)
                #if os(macOS)
                LabeledContent("设备名称", value: Host.current().localizedName ?? "Unknown")
                #else
                LabeledContent("设备名称", value: UIDevice.current.name)
                #endif
            }

            Section("网络状态") {
                LabeledContent("发现状态", value: appState.isRunning ? "运行中" : "已停止")
                LabeledContent("本地端口", value: "\(appState.localPort)")
                LabeledContent("已发现服务器", value: "\(appState.discoveredServers.count) 个")
            }

            Section("服务器信息") {
                if !appState.localURL.isEmpty {
                    LabeledContent("服务器地址", value: appState.localURL)
                }
            }

            Section("调试") {
                Button {
                    showDebugLog = true
                } label: {
                    Label("查看调试日志", systemImage: "doc.text.magnifyingglass")
                }
            }

            Section("关于") {
                LabeledContent("版本", value: "1.0.0")
                LabeledContent("技术支持", value: "局域网Web服务器 + 聊天室")
            }

            Section {
                Button("重置所有设置", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .onAppear {
            username = appState.currentUser.name
        }
        .alert("确认重置", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("这将清除所有本地设置")
        }
        .sheet(isPresented: $showDebugLog) {
            NavigationStack {
                DebugLogView()
            }
        }
    }

    private func resetSettings() {
        appState.updateUsername("")
        username = ""
        appState.stopServices()
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AppState(networkService: NetworkService.shared))
    }
}
