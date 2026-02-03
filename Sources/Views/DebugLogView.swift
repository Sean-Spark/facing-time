import SwiftUI

struct DebugLogView: View {
    @StateObject private var logger = Logger.shared
    @State private var selectedLevel: LogLevel?
    @State private var searchText: String = ""
    @State private var isAutoScrollEnabled = true
    @State private var showExportSheet = false

    var filteredLogs: [LogEntry] {
        var logs = logger.getRecentLogs()

        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }

        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return Array(logs.reversed())
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logList
            statusBar
        }
        .navigationTitle("调试日志")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索日志")
        #endif
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Menu {
                Button("全部") {
                    selectedLevel = nil
                }
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Button(level.rawValue) {
                        selectedLevel = level
                    }
                }
            } label: {
                Label(selectedLevel?.rawValue ?? "级别", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.bordered)

            #if os(macOS)
            TextField("搜索...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            #endif

            Spacer()

            Toggle("自动滚动", isOn: $isAutoScrollEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            Button(action: exportLogs) {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: clearLogs) {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredLogs) { log in
                        LogRowView(log: log)
                            .id(log.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: filteredLogs.count) { _ in
                if isAutoScrollEnabled, let first = filteredLogs.first {
                    withAnimation {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text("共 \(filteredLogs.count) 条日志")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text("内存: \(logger.recentLogs.count) 条")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
    }

    private func exportLogs() {
        let logs = logger.exportLogs()
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [logs], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #else
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FacingTime_Logs.log"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? logs.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }

    private func clearLogs() {
        logger.clearLogs()
    }
}

struct LogRowView: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString)
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(log.level.rawValue)
                .font(.caption.bold())
                .foregroundColor(levelColor)
                .frame(width: 50)

            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: log.timestamp)
    }

    private var levelColor: Color {
        switch log.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    NavigationStack {
        DebugLogView()
    }
}
