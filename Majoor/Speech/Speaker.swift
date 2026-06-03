import Foundation

/// macOS TTS via /usr/bin/say. Single swappable function; replace with OpenAI TTS later.
@MainActor
enum Speaker {
    private static var current: Process?

    /// Speak the given text and resume only after the speech finishes.
    /// Any in-progress utterance is cancelled first.
    static func speak(_ text: String, voice: String? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/say")

            var args: [String] = []
            if let voice { args.append(contentsOf: ["-v", voice]) }
            args.append(trimmed)
            task.arguments = args

            task.terminationHandler = { _ in
                continuation.resume()
            }

            do {
                try task.run()
                current = task
                Log.info("Speaking: \(trimmed)")
            } catch {
                Log.error("/usr/bin/say failed: \(error.localizedDescription)")
                continuation.resume()
            }
        }

        current = nil
    }

    static func stop() {
        if let t = current, t.isRunning {
            t.terminate()
        }
        current = nil
    }
}
