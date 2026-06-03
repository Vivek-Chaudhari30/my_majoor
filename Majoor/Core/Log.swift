import Foundation
import OSLog

enum Log {
    private static let osLog = os.Logger(subsystem: "com.majoor.app", category: "Majoor")

    static func info(_ message: String) {
        osLog.info("\(message, privacy: .public)")
        print("[Majoor] \(message)")
    }

    static func warn(_ message: String) {
        osLog.warning("\(message, privacy: .public)")
        print("[Majoor WARN] \(message)")
    }

    static func error(_ message: String) {
        osLog.error("\(message, privacy: .public)")
        print("[Majoor ERROR] \(message)")
    }
}
