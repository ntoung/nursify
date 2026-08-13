import AVFoundation
import Foundation

/// Records a short voice memo on-watch as a plain audio file — no on-watch
/// transcription. The phone finishes the job (transcribe, PHI-screen, review)
/// once the file arrives over Watch Connectivity; see REQUIREMENTS.md "short
/// memos captured on watch, queued and finished/transcribed on phone."
@MainActor
final class WatchAudioRecorder: NSObject, ObservableObject {
    enum RecorderError: LocalizedError {
        case micDenied
        case recordingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .micDenied:
                return "Microphone access is off. Enable it for Nursify in the Watch app on your phone."
            case .recordingFailed(let error):
                return "Couldn't record: \(error.localizedDescription)"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published var recordingError: RecorderError?

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    func start() async {
        guard !isRecording else { return }
        recordingError = nil

        guard await requestPermission() else {
            recordingError = .micDenied
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            recordingError = .recordingFailed(error)
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memo-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        // Modest quality/sample rate: this is a short spoken memo headed for
        // speech recognition, not archival audio, and keeps the watch->phone
        // file transfer fast.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            self.recorder = recorder
            self.currentURL = url
            isRecording = true
        } catch {
            recordingError = .recordingFailed(error)
        }
    }

    /// Stops recording and returns the recorded file's URL, if any.
    @discardableResult
    func stop() -> URL? {
        guard isRecording else { return nil }
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
        let url = currentURL
        recorder = nil
        currentURL = nil
        return url
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
