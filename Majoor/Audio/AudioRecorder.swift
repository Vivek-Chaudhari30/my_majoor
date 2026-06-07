import Foundation
import AVFoundation

final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?
    private var timer: Timer?
    private var maxPower: Float = -160.0
    private static let vadThreshold: Float = -40.0 // Threshold for discarding quiet audio

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
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw NSError(domain: "Majoor.AudioRecorder",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "AVAudioRecorder.record() returned false"])
        }
        self.recorder = recorder
        self.currentURL = url
        self.maxPower = -160.0
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            if power > self.maxPower {
                self.maxPower = power
            }
        }
        
        Log.info("Recording started → \(url.path)")
        return url
    }

    @discardableResult
    func stop() -> URL? {
        self.timer?.invalidate()
        self.timer = nil
        
        guard let recorder else { return nil }
        
        recorder.updateMeters()
        let peak = max(maxPower, recorder.averagePower(forChannel: 0))
        
        recorder.stop()
        let url = currentURL
        self.recorder = nil
        
        if peak < Self.vadThreshold {
            Log.info("Audio discarded due to low volume (peak: \(peak) dB)")
            return nil
        }
        
        return url
    }

    private func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        return dir.appendingPathComponent("majoor-\(ts).m4a")
    }
}
