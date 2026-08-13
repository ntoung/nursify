import AVFoundation
import Foundation
import Speech

/// Real mic capture + on-device transcription for Capture (REQUIREMENTS.md
/// "Capture" / "Privacy guardrail" - on-device transcription so the
/// transcript stays local until it passes the on-device PHIScreener heuristic
/// check and nurse review in CaptureView's draft step, before anything is
/// sent to the backend).
@MainActor
final class SpeechCapture: ObservableObject {
    enum CaptureError: LocalizedError {
        case micDenied
        case speechDenied
        case onDeviceUnavailable
        case audioSessionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .micDenied:
                return "Microphone access is off. Enable it in Settings to record voice notes."
            case .speechDenied:
                return "Speech recognition access is off. Enable it in Settings to transcribe voice notes."
            case .onDeviceUnavailable:
                return "On-device transcription isn't available for the current language on this device."
            case .audioSessionFailed(let error):
                return "Couldn't start recording: \(error.localizedDescription)"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var liveTranscript = ""
    @Published var captureError: CaptureError?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        guard !isRecording else { return }
        captureError = nil

        guard await requestMicPermission() else {
            captureError = .micDenied
            return
        }
        guard await requestSpeechPermission() else {
            captureError = .speechDenied
            return
        }
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            captureError = .onDeviceUnavailable
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            captureError = .audioSessionFailed(error)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        liveTranscript = ""
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            captureError = .audioSessionFailed(error)
            return
        }

        isRecording = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.teardownAudio()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        request?.endAudio()
        teardownAudio()
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// One-shot, on-device transcription of a pre-recorded audio file — used
    /// for Watch-recorded memos (WatchConnectivityReceiver), as opposed to the
    /// live mic transcription above used for phone dictation. Requires speech
    /// permission to already be granted (the phone's Capture flow requests it
    /// on first live dictation; a watch-only user who's never dictated on the
    /// phone hits `.speechDenied` here and the memo transcription silently
    /// fails — an accepted v1 gap called out in WatchConnectivityReceiver).
    static func transcribeFile(at url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.supportsOnDeviceRecognition else {
            throw CaptureError.onDeviceUnavailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw CaptureError.speechDenied
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        // One-shot only: a URL request's callback can otherwise fire more than
        // once (partial results before the final one), which would resume this
        // continuation twice and crash.
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
