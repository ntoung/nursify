import SwiftUI

/// The single watch entry point: one mic, then a scrolling record of recent
/// captures. Tap to record, tap to stop; a row appears immediately as
/// "sending…" and fills in once the phone reports back whether it saved a note
/// or answered a question. See WatchCaptureStore / WatchConnectivityManager.
struct WatchCaptureView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var store = WatchCaptureStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Button {
                        Task { await toggleRecording() }
                    } label: {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                    }
                    .buttonStyle(.plain)

                    Text(recorder.isRecording ? "Recording… tap to stop" : "Tap to capture")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if store.records.isEmpty {
                        Text("Say a note, or ask “what is…”.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    } else {
                        ForEach(store.records) { record in
                            NavigationLink {
                                WatchCaptureDetailView(record: record)
                            } label: {
                                WatchCaptureRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)
            }
            .navigationTitle("Nursify")
            .navigationBarTitleDisplayMode(.inline)
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

    private func toggleRecording() async {
        if recorder.isRecording {
            guard let url = recorder.stop() else { return }
            let id = store.addSending()
            WatchConnectivityManager.shared.send(fileAt: url, captureId: id)
        } else {
            await recorder.start()
        }
    }
}

/// One row in the capture list.
struct WatchCaptureRow: View {
    let record: WatchCaptureRecord

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(record.title)
                    .font(.caption)
                    .lineLimit(1)
                if record.status == .sending {
                    Text("sending…").font(.caption2).foregroundStyle(.secondary)
                } else if !record.detail.isEmpty {
                    Text(record.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if record.phiFlagged {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch record.status {
        case .sending: return "arrow.up.circle"
        case .failed: return "exclamationmark.triangle.fill"
        case .done:
            switch record.kind {
            case .definition: return "book.fill"
            case .note, .pending: return "note.text"
            }
        }
    }

    private var tint: Color {
        switch record.status {
        case .sending: return .secondary
        case .failed: return .red
        case .done: return record.kind == .definition ? .accentColor : .green
        }
    }
}

/// Full text for a tapped capture: the whole note transcript or definition.
struct WatchCaptureDetailView: View {
    let record: WatchCaptureRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.title)
                    .font(.headline)

                if record.phiFlagged {
                    Label("Possible patient info", systemImage: "exclamationmark.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if !record.detail.isEmpty {
                    Text(record.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

#Preview {
    WatchCaptureView()
}
