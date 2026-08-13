import SwiftUI

struct WatchCaptureView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var sentCount = 0

    var body: some View {
        VStack(spacing: 10) {
            Text("Nursify")
                .font(.headline)

            Button {
                Task { await toggleRecording() }
            } label: {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(recorder.isRecording ? .red : .accentColor)
            }
            .buttonStyle(.plain)

            Text(recorder.isRecording ? "Recording... tap to stop" : "Tap to record a memo")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if connectivity.pendingTransferCount > 0 {
                Label("Syncing to phone", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if sentCount > 0 {
                Label("Sent to phone", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
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
            if let url = recorder.stop() {
                connectivity.send(fileAt: url)
                sentCount += 1
            }
        } else {
            await recorder.start()
        }
    }
}

#Preview {
    WatchCaptureView()
}
