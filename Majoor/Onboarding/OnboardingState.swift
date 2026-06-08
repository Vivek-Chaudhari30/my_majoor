import Foundation
import AVFoundation
import AppKit

@MainActor
final class OnboardingState: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case microphone
        case accessibility
        case apiKey
        case demo

        var title: String {
            switch self {
            case .welcome:       return "Welcome to Majoor"
            case .microphone:    return "Microphone access"
            case .accessibility: return "Accessibility access"
            case .apiKey:        return "OpenAI API key"
            case .demo:          return "Try Majoor"
            }
        }
    }

    @Published var step: Step = .welcome
    @Published var keyInput: String = ""
    @Published var hotkeyFiredOnce: Bool = false
    @Published var lastError: String = ""

    static let shared = OnboardingState()
    private init() {}

    // MARK: - Onboarded sentinel

    private static var sentinelURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".majoor/.onboarded")
    }

    static var isOnboarded: Bool {
        FileManager.default.fileExists(atPath: sentinelURL.path)
    }

    static func markOnboarded() {
        let url = sentinelURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        try? Data().write(to: url)
        Log.info("Onboarding sentinel written → \(url.path)")
    }

    // MARK: - Per-step status

    var micGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    var apiKeyConfigured: Bool {
        guard let key = Config.openAIKey else { return false }
        return key.hasPrefix("sk-") && key.count >= 20
    }

    // MARK: - Navigation

    func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

    func reset() {
        step = .welcome
        keyInput = ""
        hotkeyFiredOnce = false
        lastError = ""
    }
}
