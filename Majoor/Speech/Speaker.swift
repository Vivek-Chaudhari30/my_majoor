import Foundation
import AVFoundation

/// macOS TTS via /usr/bin/say. Single swappable function; replace with OpenAI TTS later.
@MainActor
enum Speaker {
    private static var currentProcess: Process?
    private static var currentPlayer: AVAudioPlayer?
    private static var currentDelegate: AudioDelegate?
    
    class AudioDelegate: NSObject, AVAudioPlayerDelegate {
        let continuation: CheckedContinuation<Void, Never>
        init(continuation: CheckedContinuation<Void, Never>) {
            self.continuation = continuation
        }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            continuation.resume()
        }
    }

    /// Speak the given text and resume only after the speech finishes.
    /// Any in-progress utterance is cancelled first.
    static func speak(_ text: String, openAI: OpenAIClient? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()
        Log.info("Speaking: \(trimmed)")
        
        if let openAI = openAI {
            do {
                let data = try await openAI.speak(text: trimmed)
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    do {
                        let player = try AVAudioPlayer(data: data)
                        let delegate = AudioDelegate(continuation: continuation)
                        player.delegate = delegate
                        currentPlayer = player
                        currentDelegate = delegate
                        player.play()
                    } catch {
                        Log.error("AVAudioPlayer failed: \(error.localizedDescription)")
                        continuation.resume()
                    }
                }
                currentPlayer = nil
                currentDelegate = nil
                return
            } catch {
                Log.error("OpenAI TTS failed: \(error.localizedDescription), falling back to say")
            }
        }

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
        
        if let p = currentPlayer {
            p.stop()
        }
        currentPlayer = nil
        
        if let d = currentDelegate {
            currentDelegate = nil
            d.continuation.resume()
        }
    }
}
