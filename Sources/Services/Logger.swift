import Foundation
import os.log
import Combine

/// 日志级别
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

/// 日志系统
final class Logger: ObservableObject {
    static let shared = Logger()

    private let subsystem: String
    private let consoleLogger: OSLog
    private let fileLogger: FileLogger?
    private var logBuffer: [LogEntry] = []
    private let bufferLock = NSLock()

    @Published var recentLogs: [LogEntry] = []

    private init() {
        self.subsystem = "com.facingtime.app"
        self.consoleLogger = OSLog(subsystem: subsystem, category: "Network")
        self.fileLogger = FileLogger(subsystem: subsystem)
    }

    // MARK: - Public API

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }

    func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: "[NETWORK] \(message)", file: file, function: function, line: line)
    }

    func discovery(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: "[DISCOVERY] \(message)", file: file, function: function, line: line)
    }

    func connection(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: "[CONNECTION] \(message)", file: file, function: function, line: line)
    }

    func message(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: "[MESSAGE] \(message)", file: file, function: function, line: line)
    }

    // MARK: - Private Methods

    private func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line
        )

        // 1. 控制台输出
        os_log("%{public}@", log: consoleLogger, type: level.osLogType, message)

        // 2. 文件记录
        fileLogger?.write(entry)

        // 3. 内存缓存
        bufferLock.lock()
        logBuffer.append(entry)
        if logBuffer.count > 1000 {
            logBuffer.removeFirst(100)
        }
        recentLogs = Array(logBuffer.suffix(100))
        bufferLock.unlock()
    }

    // MARK: - Public Helpers

    func getRecentLogs(limit: Int = 100) -> [LogEntry] {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return Array(logBuffer.suffix(limit))
    }

    func getLogsByCategory(_ category: String) -> [LogEntry] {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return logBuffer.filter { $0.message.contains("[\(category)]") }
    }

    func clearLogs() {
        bufferLock.lock()
        logBuffer.removeAll()
        recentLogs.removeAll()
        bufferLock.unlock()
        fileLogger?.clear()
    }

    func exportLogs() -> String {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return logBuffer.map { $0.formatted }.joined(separator: "\n")
    }
}

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let file: String
    let function: String
    let line: Int

    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "\(formatter.string(from: timestamp)) [\(level.rawValue)] \(message)"
    }

    var shortDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(formatter.string(from: timestamp)) \(level.rawValue): \(message)"
    }
}

/// 文件日志记录器
final class FileLogger {
    private let fileURL: URL
    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.facingtime.logger.file", qos: .utility)

    init?(subsystem: String) {
        let logsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "FacingTime_\(dateFormatter.string(from: Date())).log"
        self.fileURL = logsDirectory.appendingPathComponent(fileName)

        // 创建或追加文件
        if FileManager.default.fileExists(atPath: fileURL.path) {
            self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        } else {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            self.fileHandle = try? FileHandle(forWritingAtPath: fileURL.path)
        }
    }

    func write(_ entry: LogEntry) {
        queue.async { [weak self] in
            guard let self = self,
                  let handle = self.fileHandle,
                  let data = "\(entry.formatted)\n".data(using: .utf8) else { return }

            handle.write(data)
        }
    }

    func clear() {
        queue.async { [weak self] in
            guard let self = self, let handle = self.fileHandle else { return }
            handle.truncateFile(atOffset: 0)
        }
    }
}
