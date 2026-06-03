import Foundation
import AVFoundation

final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    static func requestPermission(_ callback: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { callback(granted) }
        }
    }

    @discardableResult
    func start() throws -> URL {
        let url = makeTempURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw NSError(domain: "Majoor.AudioRecorder",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "AVAudioRecorder.record() returned false"])
        }
        self.recorder = recorder
        self.currentURL = url
        Log.info("Recording started → \(url.path)")
        return url
    }

    @discardableResult
    func stop() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        let url = currentURL
        self.recorder = nil
        return url
    }

    private func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        return dir.appendingPathComponent("majoor-\(ts).m4a")
    }
}
