import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: String = "server"

    var body: some View {
        #if os(iOS)
        TabView {
            ServerView()
                .tabItem {
                    Label("服务器", systemImage: "server.rack")
                }

            DeviceDiscoveryView()
                .tabItem {
                    Label("发现", systemImage: "antenna.radiowaves.left.and.right")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
        #else
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 500)
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case "server":
            ServerView()
        case "discover":
            DeviceDiscoveryView()
        case "settings":
            SettingsView()
        default:
            ServerView()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedTab) {
            NavigationLink(value: "server") {
                Label("服务器", systemImage: "server.rack")
            }

            NavigationLink(value: "discover") {
                Label("发现设备", systemImage: "antenna.radiowaves.left.and.right")
            }

            NavigationLink(value: "settings") {
                Label("设置", systemImage: "gear")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FacingTime")
    }
    #endif
}

#Preview {
    ContentView()
        .environmentObject(AppState(networkService: NetworkService.shared))
}
