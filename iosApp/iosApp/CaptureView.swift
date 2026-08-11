import Foundation
import SwiftUI

/// Capture tab: notes list is primary; record control is a small, bottom-
/// anchored bar (per the "shrink 50%, move to bottom" revision). Real
/// on-device transcription + capture-time PHI screening (REQUIREMENTS.md)
/// aren't wired up yet — `isRecording` just toggles UI state for now.
struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
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

                if isComposing {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Voice capture isn't implemented yet — type your note instead. It's sent to the server as-is (no PHI screening yet either).")
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
                } else {
                    HStack(spacing: 14) {
                        Text("Tap to add a note")
                            .font(Theme.Font.heading(13))
                        Spacer()
                        Button {
                            isComposing = true
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
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Capture")
        }
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
