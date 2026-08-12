import Foundation
import SwiftUI

/// Capture tab: notes list is primary; record control is a small, bottom-
/// anchored bar (per the "shrink 50%, move to bottom" revision). Voice
/// capture uses on-device transcription (SpeechCapture); capture-time PHI
/// screening (REQUIREMENTS.md "Privacy guardrail") is a separate follow-up —
/// notes still save with phiReviewed: false below.
struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var speech = SpeechCapture()
    @State private var isComposing = false
    @State private var draftText = ""
    @State private var isSaving = false

    private var todayNotes: [Note] { appState.notes.filter { Calendar.current.isDateInToday($0.createdAt) } }
    private var earlierNotes: [Note] { appState.notes.filter { !Calendar.current.isDateInToday($0.createdAt) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tap a note to see everything it mentions.")
                            .font(Theme.Font.body(15.5))
                            .foregroundStyle(Theme.Color.sub)
                            .padding(.top, 4)
                            .padding(.bottom, 4)

                        if !todayNotes.isEmpty {
                            SectionLabel(text: "Today").padding(.top, 12).padding(.bottom, 2)
                            ForEach(todayNotes) { note in
                                NavigationLink(destination: NoteDetailView(note: note)) {
                                    NoteRow(note: note)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        if !earlierNotes.isEmpty {
                            SectionLabel(text: "Yesterday").padding(.top, 18).padding(.bottom, 2)
                            ForEach(earlierNotes) { note in
                                NavigationLink(destination: NoteDetailView(note: note)) {
                                    NoteRow(note: note)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    .padding(24)
                }

                if speech.isRecording {
                    recordingBar
                } else if isComposing {
                    reviewBar
                } else {
                    idleBar
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Capture")
            .alert(
                "Recording issue",
                isPresented: Binding(get: { speech.captureError != nil }, set: { if !$0 { speech.captureError = nil } }),
                presenting: speech.captureError
            ) { _ in
                Button("OK") { speech.captureError = nil }
            } message: { error in
                Text(error.errorDescription ?? "Something went wrong.")
            }
        }
    }

    private var idleBar: some View {
        HStack(spacing: 14) {
            Button {
                isComposing = true
                draftText = ""
            } label: {
                Image(systemName: "keyboard")
                    .foregroundStyle(Theme.Color.sub)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Text("Tap to add a note")
                .font(Theme.Font.heading(13))
            Spacer()
            Button {
                Task { await speech.start() }
            } label: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(colors: [Color(hex: "F0917A"), Color(hex: "DE7259")], startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(SwiftUI.Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Color.line), alignment: .top)
    }

    private var recordingBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: "DE7259")).frame(width: 8, height: 8)
                Text("Listening...")
                    .font(Theme.Font.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
            }
            Text(speech.liveTranscript.isEmpty ? "Start speaking..." : speech.liveTranscript)
                .font(Theme.Font.body(14.5))
                .foregroundStyle(speech.liveTranscript.isEmpty ? Theme.Color.sub : Theme.Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.Color.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Cancel") {
                    speech.stop()
                    draftText = ""
                    isComposing = false
                }
                .font(Theme.Font.body(14, weight: .semibold))
                .foregroundStyle(Theme.Color.sub)
                Spacer()
                Button {
                    draftText = speech.liveTranscript
                    speech.stop()
                    isComposing = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                        Text("Done")
                    }
                }
                .font(Theme.Font.body(14, weight: .bold))
                .foregroundStyle(Theme.Color.accentInk)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(SwiftUI.Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Color.line), alignment: .top)
    }

    private var reviewBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review before saving. No PHI screening yet, so double-check for patient-identifying details.")
                .font(Theme.Font.body(11.5))
                .foregroundStyle(Theme.Color.sub)
            TextField("What's on your mind?", text: $draftText, axis: .vertical)
                .font(Theme.Font.body(14.5))
                .lineLimit(2...5)
                .padding(12)
                .background(Theme.Color.background)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Cancel") {
                    isComposing = false
                    draftText = ""
                }
                .font(Theme.Font.body(14, weight: .semibold))
                .foregroundStyle(Theme.Color.sub)
                Spacer()
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await save() }
                }
                .font(Theme.Font.body(14, weight: .bold))
                .foregroundStyle(Theme.Color.accentInk)
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(SwiftUI.Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Color.line), alignment: .top)
    }

    private func save() async {
        isSaving = true
        // phiReviewed: false — honestly reflects that no PHI screening has
        // run yet (REQUIREMENTS.md "Privacy guardrail" is not implemented),
        // not a real cleared/uncleared flag.
        await appState.createNote(transcript: draftText, device: .phone, phiReviewed: false)
        isSaving = false
        draftText = ""
        isComposing = false
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(note.transcript)
                .font(Theme.Font.body(14.5))
                .foregroundStyle(Theme.Color.ink)
                .lineLimit(3)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(note.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Font.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "C9C2B4"))
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct NoteDetailView: View {
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.transcript)
                        .font(Theme.Font.body(14, weight: .medium))
                        .italic()
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.Font.body(11.5, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SwiftUI.Color.white)
                .overlay(Rectangle().frame(width: 4).foregroundStyle(Theme.Color.accent), alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if note.mentionedConcepts.isEmpty {
                    Text("No concepts identified in this note yet.")
                        .font(Theme.Font.body(14))
                        .foregroundStyle(Theme.Color.sub)
                } else {
                    SectionLabel(text: "Mentioned in this note")
                    ForEach(note.mentionedConcepts) { mention in
                        ConceptCard(
                            title: mention.conceptName,
                            tags: [mention.type.displayName],
                            shortText: mention.shortExplanation,
                            longTitle: "Details",
                            longText: mention.longExplanation
                        )
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CaptureView().environmentObject(AppState())
}
