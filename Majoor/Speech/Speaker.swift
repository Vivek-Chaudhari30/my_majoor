import Foundation

/// macOS TTS via /usr/bin/say. Single swappable function.
/// Phase A: macOS `say` only — no paid TTS providers.
@MainActor
enum Speaker {
    private static var currentProcess: Process?

    /// Speak the given text and resume only after the speech finishes.
    /// Any in-progress utterance is cancelled first.
    static func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()
        Log.info("Speaking: \(trimmed)")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            task.arguments = [trimmed]

            task.terminationHandler = { _ in
                continuation.resume()
            }

            do {
                try task.run()
                currentProcess = task
            } catch {
                Log.error("/usr/bin/say failed: \(error.localizedDescription)")
                continuation.resume()
            }
        }

        currentProcess = nil
    }

    static func stop() {
        if let t = currentProcess, t.isRunning {
            t.terminate()
        }
        currentProcess = nil
    }
}
