import SwiftUI
import WatchConnectivity

/// A note built from one or more recordings, in progress on the watch.
/// `id` ties every clip transferred for this note together on the phone side
/// (WatchConnectivityReceiver groups by it); `clipCount` is both the display
/// count and the sequence number for the next recording.
private struct WatchNoteDraft {
    let id = UUID()
    var clipCount = 0
    var pendingTransfers: [WCSessionFileTransfer] = []
}

struct WatchCaptureView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var draft: WatchNoteDraft?

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let draft {
                    Text(draft.clipCount == 1 ? "1 recording added" : "\(draft.clipCount) recordings added")
                        .font(.caption2)
                        .foregroundStyle(.primary)
                } else {
                    Text("Nursify")
                        .font(.headline)
                }

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                }
                .buttonStyle(.plain)

                Text(statusCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let draft, !recorder.isRecording {
                    HStack(spacing: 16) {
                        Button {
                            Task { await toggleRecording() }
                        } label: {
                            Label("Add more", systemImage: "plus.circle.fill")
                        }
                        .tint(.accentColor)

                        Button {
                            finishNote(draft)
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 18))

                    Button {
                        discardNote(draft)
                    } label: {
                        Text("Discard")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
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

    private var statusCaption: String {
        if recorder.isRecording { return "Recording... tap to stop" }
        if draft != nil { return "Add more or finish" }
        return "Tap to start a note"
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            guard let url = recorder.stop() else { return }
            var current = draft ?? WatchNoteDraft()
            current.clipCount += 1
            let transfer = connectivity.send(fileAt: url, sessionId: current.id, sequence: current.clipCount)
            if let transfer { current.pendingTransfers.append(transfer) }
            draft = current
        } else {
            await recorder.start()
        }
    }

    private func finishNote(_ draft: WatchNoteDraft) {
        connectivity.finishSession(id: draft.id, clipCount: draft.clipCount)
        self.draft = nil
    }

    /// Best-effort: cancels any clip transfers still in flight. A transfer
    /// that already reached the phone can't be recalled — the phone simply
    /// never receives a "session complete" marker for this session, so its
    /// buffered clips are never surfaced for review either. See
    /// WatchConnectivityReceiver.
    private func discardNote(_ draft: WatchNoteDraft) {
        draft.pendingTransfers.forEach { $0.cancel() }
        self.draft = nil
    }
}

#Preview {
    WatchCaptureView()
}
