import Foundation
import SwiftUI

/// Capture tab: notes list is primary; record control is a small, bottom-
/// anchored bar (per the "shrink 50%, move to bottom" revision). Voice
/// capture uses on-device transcription (SpeechCapture); the draft review
/// step runs an on-device heuristic PHI scan (PHIScreener, REQUIREMENTS.md
/// "Privacy guardrail") and requires the nurse to acknowledge any flagged
/// content before saving.
struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var speech = SpeechCapture()
    @State private var isComposing = false
    @State private var draftText = ""
    @State private var isSaving = false
    @State private var phiFindings: [PHIFinding] = []
    @State private var phiAcknowledged = false
    @State private var draftDevice: CaptureDevice = .phone

    private var todayNotes: [Note] { appState.notes.filter { Calendar.current.isDateInToday($0.createdAt) } }
    private var earlierNotes: [Note] { appState.notes.filter { !Calendar.current.isDateInToday($0.createdAt) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if appState.notes.isEmpty {
                            EmptyStateView(
                                icon: "mic.circle",
                                title: "No notes yet",
                                message: "Tap the mic to record a voice note, or the keyboard to type one. Your notes show up here."
                            )
                            .padding(.top, 40)
                        } else {
                            Text("Tap a note to see everything it mentions.")
                                .font(Theme.Font.body(15.5))
                                .foregroundStyle(Theme.Color.sub)
                                .padding(.top, 4)
                                .padding(.bottom, 4)

                            if !todayNotes.isEmpty {
                                SectionLabel(text: "Today").padding(.top, 12).padding(.bottom, 2)
                                ForEach(todayNotes) { note in
                                    NavigationLink(destination: NoteDetailView(note: note)) {
                                        NoteRow(note: note, isPendingSync: appState.pendingNoteIds.contains(note.id))
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            if !earlierNotes.isEmpty {
                                SectionLabel(text: "Yesterday").padding(.top, 18).padding(.bottom, 2)
                                ForEach(earlierNotes) { note in
                                    NavigationLink(destination: NoteDetailView(note: note)) {
                                        NoteRow(note: note, isPendingSync: appState.pendingNoteIds.contains(note.id))
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
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
            .alert(
                "Couldn't save note",
                isPresented: Binding(get: { appState.errorMessage != nil }, set: { if !$0 { appState.errorMessage = nil } })
            ) {
                Button("OK") { appState.errorMessage = nil }
            } message: {
                Text(appState.errorMessage ?? "Something went wrong.")
            }
            .onChange(of: appState.pendingWatchDrafts.count) { _, _ in
                openNextWatchDraftIfAvailable()
            }
            .onAppear {
                openNextWatchDraftIfAvailable()
            }
        }
    }

    /// Opens the review sheet with the oldest queued watch note, unless one's
    /// already open — never interrupts a note the nurse is mid-reviewing.
    /// Called on appear, whenever a new watch note finishes, and after
    /// Save/Cancel so a backlog gets worked through one at a time.
    private func openNextWatchDraftIfAvailable() {
        guard !isComposing, let next = appState.popNextPendingWatchDraft() else { return }
        draftText = next
        draftDevice = .watch
        isComposing = true
    }

    private var idleBar: some View {
        HStack(spacing: 14) {
            Button {
                isComposing = true
                draftText = ""
                draftDevice = .phone
            } label: {
                Image(systemName: "keyboard")
                    .foregroundStyle(Theme.Color.sub)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Text(speech.isCallActive ? "Recording unavailable during a call" : "Tap to add a note")
                .font(Theme.Font.heading(13))
                .foregroundStyle(speech.isCallActive ? Theme.Color.sub : Theme.Color.ink)
            Spacer()
            Button {
                Task { await speech.start() }
            } label: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        speech.isCallActive
                            ? AnyShapeStyle(Theme.Color.sub)
                            : AnyShapeStyle(LinearGradient(colors: [Color(hex: "F0917A"), Color(hex: "DE7259")], startPoint: .top, endPoint: .bottom))
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(speech.isCallActive)
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
                    let transcript = speech.liveTranscript
                    speech.stop()
                    draftText = transcript
                    draftDevice = .phone
                    if PHIScreener.scan(transcript).isEmpty {
                        // Nothing to review — Done is enough, no separate
                        // manual Save tap for the common case.
                        Task { await save() }
                    } else {
                        // Flagged content still requires the nurse to review
                        // and acknowledge before it's saved (REQUIREMENTS.md
                        // "Privacy guardrail") — reviewBar's onAppear re-scans.
                        isComposing = true
                    }
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
            Text("Note")
                .font(Theme.Font.body(11.5))
                .foregroundStyle(Theme.Color.sub)
            TextField("What do you want to remember?", text: $draftText, axis: .vertical)
                .font(Theme.Font.body(14.5))
                .lineLimit(2...5)
                .padding(12)
                .background(Theme.Color.background)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: draftText) { _, newValue in
                    let newFindings = PHIScreener.scan(newValue)
                    if newFindings != phiFindings {
                        phiFindings = newFindings
                        phiAcknowledged = false
                    }
                }

            if !phiFindings.isEmpty {
                phiWarningCard
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    isComposing = false
                    draftText = ""
                    phiFindings = []
                    phiAcknowledged = false
                    openNextWatchDraftIfAvailable()
                }
                .font(Theme.Font.body(14, weight: .bold))
                .foregroundStyle(Theme.Color.sub)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(SwiftUI.Color.white)
                .overlay(Capsule().stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(Capsule())
                Spacer()
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await save() }
                }
                .font(Theme.Font.body(14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(Theme.Color.accent)
                .clipShape(Capsule())
                .opacity(
                    draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || isSaving
                        || (!phiFindings.isEmpty && !phiAcknowledged)
                        ? 0.4 : 1
                )
                .disabled(
                    draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || isSaving
                        || (!phiFindings.isEmpty && !phiAcknowledged)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(SwiftUI.Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Color.line), alignment: .top)
        .onAppear {
            phiFindings = PHIScreener.scan(draftText)
            phiAcknowledged = false
        }
    }

    private var phiWarningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Possible patient-identifying details found")
                    .font(Theme.Font.heading(12.5))
            }
            .foregroundStyle(Theme.Color.warnInk)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(phiFindings) { finding in
                    Text("\(finding.category): \u{201C}\(finding.matchedText)\u{201D}")
                        .font(Theme.Font.body(12))
                        .foregroundStyle(Theme.Color.warnInk)
                }
            }

            Button {
                phiAcknowledged.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: phiAcknowledged ? "checkmark.square.fill" : "square")
                    Text("I've reviewed this and removed any PHI")
                        .font(Theme.Font.body(12, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Color.warnInk)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Theme.Color.warnBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Color.warnLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func save() async {
        isSaving = true
        // phiReviewed: true - reachable only when the Save button is
        // enabled, i.e. either the on-device PHIScreener found nothing, or
        // the nurse explicitly acknowledged reviewing the flagged content.
        await appState.createNote(transcript: draftText, device: draftDevice, phiReviewed: true)
        isSaving = false
        draftText = ""
        isComposing = false
        phiFindings = []
        phiAcknowledged = false
        draftDevice = .phone
        openNextWatchDraftIfAvailable()
    }
}

private struct NoteRow: View {
    let note: Note
    var isPendingSync: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(note.transcript)
                .font(Theme.Font.body(14.5))
                .foregroundStyle(Theme.Color.ink)
                .lineLimit(3)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if isPendingSync {
                    // Captured offline; will sync when the backend is reachable.
                    Label("Pending sync", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                        .accessibilityLabel("Pending sync")
                }
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
