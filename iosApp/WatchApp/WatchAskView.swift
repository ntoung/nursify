import SwiftUI

/// Ask mode: a single spoken term, answered immediately — distinct from
/// Capture mode (WatchCaptureView), which builds a note for later review on
/// the phone rather than answering anything live. See WatchRootView for how
/// the two modes are reached.
private enum AskState {
    case idle
    case recording
    case asking
    case result(AskResponse)
    case failed(String)
}

struct WatchAskView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var state: AskState = .idle
    @State private var showingMore = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                switch state {
                case .idle:
                    Text("Ask Nursify")
                        .font(.headline)
                    micButton
                    Text("Tap and say a term")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                case .recording:
                    micButton
                    Text("Listening... tap to stop")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                case .asking:
                    ProgressView()
                    Text("Thinking...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                case .result(let response):
                    resultView(response)

                case .failed(let message):
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { state = .idle }
                        .font(.caption2)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .alert(
            "Recording issue",
            isPresented: Binding(get: { recorder.recordingError != nil }, set: { if !$0 { recorder.recordingError = nil } }),
            presenting: recorder.recordingError
        ) { _ in
            Button("OK") { recorder.recordingError = nil }
        } message: { error in
            Text(error.errorDescription ?? "Something went wrong.")
        }
    }

    private var micButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(recorder.isRecording ? .red : .accentColor)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultView(_ response: AskResponse) -> some View {
        if response.found {
            Text(response.termName ?? "")
                .font(.subheadline.bold())
            Text(response.shortExplanation ?? "")
                .font(.caption2)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if response.longExplanation != nil {
                    Button {
                        showingMore.toggle()
                    } label: {
                        Label("More", systemImage: showingMore ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    }
                    .tint(.accentColor)
                }

                Button {
                    showingMore = false
                    state = .idle
                } label: {
                    Label("Ask again", systemImage: "arrow.counterclockwise.circle.fill")
                }
                .tint(.secondary)
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 20))
            .padding(.top, 2)

            if showingMore, let long = response.longExplanation {
                Divider()
                Text(long)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else {
            Text("Couldn't find a match for that")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") { state = .idle }
                .font(.caption2)
        }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            guard let url = recorder.stop() else {
                state = .idle
                return
            }
            state = .asking
            do {
                let response = try await connectivity.ask(fileAt: url)
                state = .result(response)
            } catch {
                state = .failed(error.localizedDescription)
            }
        } else {
            state = .recording
            await recorder.start()
            // start() can fail (denied permission, etc.) without ever
            // flipping isRecording — fall back to idle rather than being
            // stuck showing "Listening..." with nothing actually recording.
            if !recorder.isRecording {
                state = .idle
            }
        }
    }
}

#Preview {
    WatchAskView()
}
