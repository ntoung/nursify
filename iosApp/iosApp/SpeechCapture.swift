import AVFoundation
import CallKit
import Foundation
import Speech

/// Real mic capture + on-device transcription for Capture (REQUIREMENTS.md
/// "Capture" / "Privacy guardrail" - on-device transcription so the
/// transcript stays local until it passes the on-device PHIScreener heuristic
/// check and nurse review in CaptureView's draft step, before anything is
/// sent to the backend).
@MainActor
final class SpeechCapture: NSObject, ObservableObject {
    enum CaptureError: LocalizedError {
        case micDenied
        case speechDenied
        case onDeviceUnavailable
        case callInProgress
        case audioSessionFailed(Error)
        case recognitionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .micDenied:
                return "Microphone access is off. Enable it in Settings to record voice notes."
            case .speechDenied:
                return "Speech recognition access is off. Enable it in Settings to transcribe voice notes."
            case .onDeviceUnavailable:
                return "On-device transcription isn't available for the current language on this device."
            case .callInProgress:
                // No third-party app can take over the microphone from an
                // active call — that's an intentional OS-level boundary, not
                // something to work around. Typed notes are the fallback.
                return "Recording isn't available during a call. End your call, then try again — or tap the keyboard icon to type your note instead."
            case .audioSessionFailed(let error):
                return "Couldn't start recording: \(error.localizedDescription). Try again — if it keeps happening, another app may be using the microphone."
            case .recognitionFailed(let error):
                return "Recording stopped unexpectedly: \(error.localizedDescription)"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var liveTranscript = ""
    @Published var captureError: CaptureError?
    /// Whether a phone/FaceTime call is currently active — CaptureView uses
    /// this to disable the record button and explain why up front, rather
    /// than letting the nurse tap it and hit a bare "Session activation
    /// failed" with no context.
    @Published private(set) var isCallActive: Bool

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let callObserver = CXCallObserver()
    /// Guards against a rapid double-tap on the record button re-entering
    /// `start()` while the first call is still mid-flight: without this, the
    /// second call's `captureError = nil` at the top would silently wipe out
    /// an error alert the first call had just shown, making it look like the
    /// alert "flashes and disappears" rather than a real failure happening.
    private var isStarting = false
    /// Text finalized from completed recognition segments during the
    /// current recording. On-device dictation auto-finalizes (`isFinal`)
    /// after a few seconds of silence, not only at `endAudio()` — so a
    /// pause mid-recording ends the current segment on its own, and the
    /// next segment's `bestTranscription` only covers what's said after
    /// that point. Without stitching segments together here, a pause would
    /// silently drop everything said before it instead of one continuous
    /// recording lasting until the nurse taps Done.
    private var committedTranscript = ""

    override init() {
        isCallActive = callObserver.calls.contains { !$0.hasEnded }
        super.init()
        callObserver.setDelegate(self, queue: .main)
    }

    func start() async {
        await start(isRetry: false)
    }

    /// `isRetry` marks the one silent automatic retry below — kept as a call
    /// argument rather than stored state so every fresh top-level `start()`
    /// gets its own retry chance, instead of a device that needed one retry
    /// once never getting another for the rest of the app's lifetime.
    private func start(isRetry: Bool) async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        if !isRetry {
            captureError = nil
        }

        // Defensive reset: guarantees a clean engine/session slate even if a
        // previous attempt left things partially set up (e.g. backgrounded
        // mid-recording, or a prior setActive succeeded but a later step
        // failed) — stale state here is a real cause of "Session activation
        // failed" on the next attempt.
        teardownAudio()

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
        guard !isCallActive else {
            captureError = .callInProgress
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            // Deactivate first to release any stale route before requesting a
            // fresh activation — activating directly over a lingering session
            // is a real cause of setActive(true) intermittently throwing
            // "Session activation failed".
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // A call that started in the moment between the guard above and
            // this activation attempt is the single most common real-world
            // cause of this failing — worth re-checking so the error is
            // still specific rather than a generic "Session activation
            // failed" in that narrow race window.
            captureError = isCallActive ? .callInProgress : .audioSessionFailed(error)
            return
        }

        liveTranscript = ""
        committedTranscript = ""
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Reads self.request each call (rather than capturing the request
        // instance up front) so buffers keep flowing to whichever segment's
        // request is current once beginSegment(...) below swaps it out —
        // the mic and engine only start once per recording, segments chain
        // underneath without a restart.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
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
        beginSegment(recognizer: recognizer, isRetry: isRetry)
    }

    /// Starts one recognition segment against the already-running audio
    /// engine. When the segment auto-finalizes (silence-triggered `isFinal`,
    /// not the nurse tapping Done), its text is folded into
    /// `committedTranscript` and a fresh segment starts immediately —
    /// stitching what would otherwise look like the transcript resetting
    /// after every pause into one continuous recording.
    private func beginSegment(recognizer: SFSpeechRecognizer, isRetry: Bool) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        // Biases recognition toward the curated corpus's medical vocabulary
        // (drug names, brand names, abbreviations) — see ConceptLibrary.
        request.contextualStrings = ConceptLibrary.shared.contextualStrings
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                // stop() (Done/Cancel) already ran teardownAudio() synchronously,
                // which cancels `task` and sets isRecording false before this
                // async callback gets a chance to run. Cancelling a task that
                // was mid-recognition commonly surfaces here as a spurious
                // "No speech detected" error — trailing noise from our own
                // deliberate teardown, not a real failure. The transcript was
                // already captured from liveTranscript before stop() was
                // called, so there's nothing left to do if we're here late.
                guard self.isRecording else { return }

                if let result {
                    let segmentText = result.bestTranscription.formattedString
                    if segmentText.isEmpty {
                        self.liveTranscript = self.committedTranscript
                    } else if self.committedTranscript.isEmpty {
                        self.liveTranscript = segmentText
                    } else {
                        self.liveTranscript = self.committedTranscript + " " + segmentText
                    }
                }
                if let error {
                    // The on-device recognizer can transiently fail to attach
                    // right as the audio session activates — most visible on
                    // the very first recording after a fresh install/launch.
                    // If we never got so much as a partial result before this
                    // error, treat it as that transient init failure and
                    // retry once, silently, rather than surfacing it — a real
                    // failure (denied permission mid-flight, interruption
                    // partway through real speech) will have produced at
                    // least some transcript first, so this won't mask those.
                    let neverGotAnyTranscript = self.liveTranscript.isEmpty
                    self.teardownAudio()
                    if !isRetry && neverGotAnyTranscript {
                        Task { await self.start(isRetry: true) }
                    } else {
                        self.captureError = .recognitionFailed(error)
                    }
                } else if result?.isFinal == true {
                    // Auto-finalized from silence, not a real stop: fold this
                    // segment's text into the running total and immediately
                    // chain into a new segment on the same still-running
                    // audio engine, instead of tearing the recording down.
                    self.committedTranscript = self.liveTranscript
                    self.request = nil
                    self.task = nil
                    self.beginSegment(recognizer: recognizer, isRetry: isRetry)
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

    /// Primes speech-recognition permission on app launch (see ContentView),
    /// so a nurse who records on the Watch before ever dictating on the phone
    /// still gets a working transcription — without this, `transcribeFile`
    /// below would only ever see permission granted after a first *live*
    /// phone dictation, since that's the only other place it's requested.
    /// A no-op if already determined (granted or denied): this never
    /// re-prompts, it only covers the still-undetermined case.
    static func requestSpeechPermissionIfNeeded() async {
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
        }
    }

    /// Transcription of a pre-recorded audio file — used for Watch-recorded
    /// clips (WatchConnectivityReceiver, both note capture and Ask mode), as
    /// opposed to the live mic transcription above used for phone dictation.
    static func transcribeFile(at url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.supportsOnDeviceRecognition else {
            throw CaptureError.onDeviceUnavailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw CaptureError.speechDenied
        }

        // Same transient on-device-recognizer-init failure as the live path
        // in `start()` above can happen here too (a fresh SFSpeechRecognizer
        // instance is created per call) — one silent retry before giving up.
        do {
            return try await attemptTranscribeFile(at: url, recognizer: recognizer)
        } catch {
            return try await attemptTranscribeFile(at: url, recognizer: recognizer)
        }
    }

    private static func attemptTranscribeFile(at url: URL, recognizer: SFSpeechRecognizer) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        // Same medical-vocabulary bias as the live path in start() — see
        // ConceptLibrary.contextualStrings.
        request.contextualStrings = ConceptLibrary.shared.contextualStrings
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

extension SpeechCapture: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        Task { @MainActor in
            self.isCallActive = callObserver.calls.contains { !$0.hasEnded }
        }
    }
}
