import Foundation
import SwiftUI

/// Journal tab: one chronological record of the shift, merging voice/text
/// notes and chart lookups (previously separate Capture/Charts tabs). "New
/// Entry" opens one composer where both a note and a chief-complaint/
/// medication lookup are optional fields on the same entry.
///
/// Hard constraint preserved from before the merge (REQUIREMENTS.md /
/// SYSTEM_DESIGN.md): notes and chart lookups still have completely
/// different privacy/retention rules under the hood. A note is PHI-screened,
/// then synced to the backend and persists. A chart lookup never leaves the
/// device and hard-expires after 24 hours so patient-identifying complaints
/// never accumulate anywhere. Saving "one entry" with both fields filled in
/// creates two separate records (Note + LookupSession) that merely share a
/// local-only `entryGroupId` so they render as one card here — it does not
/// merge their sync/retention behavior.
struct JournalView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isPresentingNewEntry = false
    @State private var prefillNoteText = ""
    @State private var prefillDevice: CaptureDevice = .phone

    /// Notes and lookup sessions sharing an `entryGroupId` become one group;
    /// everything else (including every entry created before this merge)
    /// renders as its own solo group, same as it always did.
    private var groups: [JournalEntryGroup] {
        var byGroupId: [UUID: (note: Note?, lookup: LookupSession?)] = [:]
        var solo: [JournalEntryGroup] = []

        for note in appState.notes {
            if let groupId = note.entryGroupId {
                byGroupId[groupId, default: (nil, nil)].note = note
            } else {
                solo.append(JournalEntryGroup(id: "note-\(note.id)", date: note.createdAt, note: note, lookupSession: nil))
            }
        }
        for session in appState.lookupSessions {
            if let groupId = session.entryGroupId {
                byGroupId[groupId, default: (nil, nil)].lookup = session
            } else {
                solo.append(JournalEntryGroup(id: "lookup-\(session.id)", date: session.createdAt, note: nil, lookupSession: session))
            }
        }
        let grouped = byGroupId.map { groupId, pair in
            JournalEntryGroup(
                id: "group-\(groupId.uuidString)",
                date: pair.note?.createdAt ?? pair.lookup?.createdAt ?? Date(),
                note: pair.note,
                lookupSession: pair.lookup
            )
        }
        return (solo + grouped).sorted { $0.date > $1.date }
    }

    private var todayGroups: [JournalEntryGroup] { groups.filter { Calendar.current.isDateInToday($0.date) } }
    private var earlierGroups: [JournalEntryGroup] { groups.filter { !Calendar.current.isDateInToday($0.date) } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Journal")
                            .font(Theme.Font.heading(28, weight: .bold))
                            .foregroundStyle(Theme.Color.ink)
                        Spacer()
                        if !appState.lookupSessions.isEmpty {
                            Button("Clear charts") { appState.clearLookupHistory() }
                                .font(Theme.Font.body(15, weight: .semibold))
                                .foregroundStyle(Theme.Color.accentInk)
                        }
                    }
                    Text("Notes are saved. Chart lookups are cleared after 24 hours for patient confidentiality.")
                        .font(Theme.Font.body(13.5))
                        .foregroundStyle(Theme.Color.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)

                if groups.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        title: "No entries yet",
                        message: "Tap New Entry to record a note, look up a chief complaint and medications, or both. Your entries show up here."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !todayGroups.isEmpty {
                            Section {
                                ForEach(todayGroups) { journalRow($0) }
                            } header: {
                                SectionLabel(text: "Today")
                            }
                        }
                        if !earlierGroups.isEmpty {
                            Section {
                                ForEach(earlierGroups) { journalRow($0) }
                            } header: {
                                SectionLabel(text: "Earlier")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "New Entry") {
                    prefillNoteText = ""
                    prefillDevice = .phone
                    isPresentingNewEntry = true
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Theme.Color.background)
            }
            .sheet(isPresented: $isPresentingNewEntry, onDismiss: { openNextWatchDraftIfAvailable() }) {
                NewEntryView(prefillNote: prefillNoteText, draftDevice: prefillDevice)
            }
            .alert(
                "Couldn't save note",
                isPresented: Binding(get: { appState.errorMessage != nil }, set: { if !$0 { appState.errorMessage = nil } })
            ) {
                Button("OK") { appState.errorMessage = nil }
            } message: {
                Text(appState.errorMessage ?? "Something went wrong.")
            }
            .onAppear {
                appState.purgeExpiredLookups()
                openNextWatchDraftIfAvailable()
            }
            .onChange(of: appState.pendingWatchDrafts.count) { _, _ in
                openNextWatchDraftIfAvailable()
            }
        }
    }

    private func journalRow(_ group: JournalEntryGroup) -> some View {
        NavigationLink(destination: JournalEntryDetailView(noteId: group.note?.id, lookupSessionId: group.lookupSession?.id)) {
            JournalRow(
                group: group,
                isPendingSync: group.note.map { appState.pendingNoteIds.contains($0.id) } ?? false
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Only the chart-lookup half of an entry is ever swipe-deletable
            // here — matches Charts' existing behavior exactly, and a note
            // was never swipe-deletable before this merge either, so this
            // isn't a new capability, just the same one carried forward.
            if let session = group.lookupSession {
                Button(role: .destructive) {
                    appState.removeLookupSession(session)
                } label: {
                    Label(group.note != nil ? "Remove chart" : "Remove", systemImage: "trash")
                }
                // Explicit red — the ambient .tint(Theme.Color.accentInk) on
                // the root TabView otherwise bleeds into swipe-action
                // buttons too, making "destructive" look like the app's
                // ordinary accent green instead of a clear delete signal.
                .tint(.red)
            }
        }
    }

    /// Opens New Entry pre-filled with the oldest queued watch note, unless
    /// one's already open — never interrupts a note the nurse is
    /// mid-reviewing. Called on appear, whenever a new watch note finishes,
    /// and after New Entry closes so a backlog gets worked through one at a
    /// time.
    private func openNextWatchDraftIfAvailable() {
        guard !isPresentingNewEntry, let next = appState.popNextPendingWatchDraft() else { return }
        prefillNoteText = next
        prefillDevice = .watch
        isPresentingNewEntry = true
    }
}

/// Display-only union of a Note and/or a LookupSession sharing an
/// `entryGroupId` — never persisted itself, purely a JournalView rendering
/// concern computed fresh from `appState.notes`/`lookupSessions`.
private struct JournalEntryGroup: Identifiable {
    let id: String
    let date: Date
    let note: Note?
    let lookupSession: LookupSession?
}

private struct JournalRow: View {
    let group: JournalEntryGroup
    var isPendingSync: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let note = group.note {
                    Text(note.transcript)
                        .font(Theme.Font.body(14.5))
                        .foregroundStyle(Theme.Color.ink)
                        .lineLimit(group.lookupSession != nil ? 2 : 3)
                }
                if let session = group.lookupSession {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(session.chiefComplaints.joined(separator: ", ")) · \(session.medications.count) medications")
                            .font(Theme.Font.body(group.note == nil ? 14.5 : 12.5, weight: group.note == nil ? .semibold : .regular))
                    }
                    .foregroundStyle(group.note == nil ? Theme.Color.ink : Theme.Color.sub)
                }
            }
            Spacer(minLength: 8)
            // Compact trailing column, top-aligned beside the content — not a
            // full-width row of its own, which was pushing the timestamp far
            // from the title and inflating each row's height.
            VStack(alignment: .trailing, spacing: 3) {
                if isPendingSync {
                    Label("Pending sync", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                        .accessibilityLabel("Pending sync")
                }
                Text(group.date.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Font.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
            }
            // No manual chevron here — List already draws its own
            // NavigationLink disclosure indicator on the trailing edge;
            // adding a second one produced two chevrons per row.
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// New-entry composer: a Note (voice/keyboard, PHI-screened) and a Chart
/// Lookup (chief complaints + medications) as independently optional
/// sections of one form. Saving creates whichever underlying record(s) were
/// filled in — see the privacy-boundary note on JournalView above.
struct NewEntryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechCapture()

    @State private var noteText: String
    @State private var complaints: [String] = []
    @State private var medications: [String] = []
    @State private var phiFindings: [PHIFinding] = []
    @State private var phiAcknowledged = false
    @State private var isAddingComplaint = false
    @State private var isAddingMedication = false
    @State private var newComplaintText = ""
    @State private var newMedicationText = ""
    @State private var isSaving = false
    @FocusState private var addFieldFocused: Bool

    private let draftDevice: CaptureDevice
    /// Generated once per composer session; only actually attached to the
    /// saved records if both a note and a lookup end up being saved
    /// together (see `save()`) — a solo note or solo lookup needs no group.
    private let entryGroupId = UUID()

    private let quickComplaints = ["COPD flare", "Post-op pain", "Sepsis workup", "Chest pain"]

    init(prefillNote: String = "", draftDevice: CaptureDevice = .phone) {
        _noteText = State(initialValue: prefillNote)
        self.draftDevice = draftDevice
    }

    private var hasNote: Bool { !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasLookup: Bool { !medications.isEmpty }
    private var canSave: Bool {
        guard hasNote || hasLookup else { return false }
        if hasNote, !phiFindings.isEmpty, !phiAcknowledged { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Chart lookup")
                        .padding(.bottom, 6)

                    editableChipSection(
                        title: "Chief complaints (optional)",
                        addLabel: "Add complaint",
                        searchPlaceholder: "Search or type a complaint",
                        suggestType: .condition,
                        items: $complaints,
                        isAdding: $isAddingComplaint,
                        draftText: $newComplaintText
                    )
                    editableChipSection(
                        title: "Medications (optional)",
                        addLabel: "Add drug",
                        searchPlaceholder: "Search a medication",
                        suggestType: .medication,
                        items: $medications,
                        isAdding: $isAddingMedication,
                        draftText: $newMedicationText
                    )

                    SectionLabel(text: "Quick picks · common on Telemetry")
                        .padding(.top, 18)
                        .padding(.bottom, 8)
                    FlowLayout(spacing: 9) {
                        ForEach(quickComplaints, id: \.self) { pick in
                            Button {
                                if !complaints.contains(pick) { complaints.append(pick) }
                            } label: {
                                Text(pick)
                                    .font(Theme.Font.body(14, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(SwiftUI.Color.white)
                                    .foregroundStyle(Theme.Color.accentInk)
                                    .overlay(Capsule().stroke(Color(hex: "CFE6DB"), lineWidth: 1.5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().padding(.vertical, 14)

                    // Last in the form, right above Save Entry — the most
                    // frequently-used field sits closest to the thumb/button.
                    noteSection
                }
                .padding(24)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isSaving ? "Saving..." : "Save Entry") {
                    guard !isSaving else { return }
                    Task { await save() }
                }
                .disabled(!canSave || isSaving)
                .opacity(canSave && !isSaving ? 1 : 0.5)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Theme.Color.background)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        addFieldFocused = false
                        if speech.isRecording { speech.stop() }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Color.sub)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            .alert(
                "Recording issue",
                isPresented: Binding(get: { speech.captureError != nil }, set: { if !$0 { speech.captureError = nil } }),
                presenting: speech.captureError
            ) { _ in
                Button("OK") { speech.captureError = nil }
            } message: { error in
                Text(error.errorDescription ?? "Something went wrong.")
            }
            .onDisappear {
                if speech.isRecording { speech.stop() }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Note")

            HStack(alignment: .top, spacing: 10) {
                TextField("What do you want to remember?", text: $noteText, axis: .vertical)
                    .font(Theme.Font.body(14.5))
                    .lineLimit(2...6)
                    .padding(12)
                    .background(Theme.Color.background)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(speech.isRecording)

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
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

            if speech.isRecording {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: "DE7259")).frame(width: 8, height: 8)
                    Text("Listening...")
                        .font(Theme.Font.body(12, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                }
            } else if speech.isCallActive {
                Text("Recording unavailable during a call")
                    .font(Theme.Font.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
            }

            if !phiFindings.isEmpty {
                PHIWarningCard(findings: phiFindings, acknowledged: $phiAcknowledged)
            }
        }
        .onChange(of: speech.liveTranscript) { _, newValue in
            guard speech.isRecording else { return }
            noteText = newValue
        }
        .onChange(of: noteText) { _, newValue in
            let newFindings = PHIScreener.scan(newValue)
            if newFindings != phiFindings {
                phiFindings = newFindings
                phiAcknowledged = false
            }
        }
        .onAppear {
            phiFindings = PHIScreener.scan(noteText)
        }
    }

    private func toggleRecording() async {
        if speech.isRecording {
            speech.stop()
        } else {
            await speech.start()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        // Only actually group the two records if both are being created —
        // see JournalView's privacy-boundary note: this is UI-level linking
        // only, each record still goes through its own existing pipeline.
        let groupId = (hasNote && hasLookup) ? entryGroupId : nil

        if hasNote {
            // phiReviewed: true - reachable only when Save is enabled, i.e.
            // either PHIScreener found nothing, or the nurse explicitly
            // acknowledged reviewing the flagged content.
            await appState.createNote(
                transcript: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
                device: draftDevice,
                phiReviewed: true,
                entryGroupId: groupId
            )
        }
        if hasLookup {
            _ = appState.performChartLookup(chiefComplaints: complaints, medicationNames: medications, entryGroupId: groupId)
        }
        dismiss()
    }

    private func editableChipSection(
        title: String,
        addLabel: String,
        searchPlaceholder: String,
        suggestType: ConceptType,
        items: Binding<[String]>,
        isAdding: Binding<Bool>,
        draftText: Binding<String>
    ) -> some View {
        let query = draftText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestions: [ConceptSummary] = query.isEmpty ? [] : Array(
            appState.library.search(query)
                .filter { $0.type == suggestType && !items.wrappedValue.contains($0.name) }
                .prefix(6)
        )

        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title).padding(.top, 14)

            if isAdding.wrappedValue {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.sub)
                        TextField(searchPlaceholder, text: draftText)
                            .font(Theme.Font.body(15, weight: .semibold))
                            .focused($addFieldFocused)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { add(draftText.wrappedValue, to: items, draftText: draftText) }
                        if !draftText.wrappedValue.isEmpty {
                            Button { draftText.wrappedValue = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Color.sub)
                            }
                            .buttonStyle(.plain)
                        }
                        Button("Done") {
                            addFieldFocused = false
                            isAdding.wrappedValue = false
                            draftText.wrappedValue = ""
                        }
                        .font(Theme.Font.body(13, weight: .bold))
                        .foregroundStyle(Theme.Color.accentInk)
                    }
                    .padding(13)
                    .background(SwiftUI.Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.accent, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    if !suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(suggestions) { suggestion in
                                Button {
                                    add(suggestion.name, to: items, draftText: draftText)
                                } label: {
                                    HStack {
                                        Text(suggestion.matchedAlias ?? suggestion.name)
                                            .font(Theme.Font.body(14.5, weight: .semibold))
                                            .foregroundStyle(Theme.Color.ink)
                                        Spacer()
                                        Text(suggestion.type.displayName)
                                            .font(Theme.Font.body(11, weight: .bold))
                                            .foregroundStyle(Theme.Color.sub)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if suggestion.id != suggestions.last?.id {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(SwiftUI.Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Color.line, lineWidth: 1))
                    }
                }
            } else {
                Button {
                    isAdding.wrappedValue = true
                    addFieldFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text(addLabel)
                    }
                    .font(Theme.Font.body(14, weight: .bold))
                    .foregroundStyle(Theme.Color.sub)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .overlay(Capsule().stroke(Color(hex: "C9BFAD"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if !items.wrappedValue.isEmpty {
                FlowLayout(spacing: 9) {
                    ForEach(items.wrappedValue, id: \.self) { item in
                        HStack(spacing: 8) {
                            Text(item).font(Theme.Font.body(14, weight: .bold))
                            Button {
                                items.wrappedValue.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.Color.sub)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(SwiftUI.Color.white)
                        .overlay(Capsule().stroke(Theme.Color.line, lineWidth: 1.5))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Adds an item and keeps the search field open/focused so several can be
    /// added in a row; the "Done" button closes it.
    private func add(_ text: String, to items: Binding<[String]>, draftText: Binding<String>) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !items.wrappedValue.contains(trimmed) {
            items.wrappedValue.append(trimmed)
        }
        draftText.wrappedValue = ""
        addFieldFocused = true
    }
}

/// Merged detail view for a Journal entry — shows the note's mentioned
/// concepts and/or the chart lookup's medication explanations, whichever
/// parts the entry actually has. Looks up the live note/session by id
/// (rather than taking a value snapshot) so adding/removing a medication
/// here updates immediately instead of showing stale content.
struct JournalEntryDetailView: View {
    @EnvironmentObject private var appState: AppState
    let noteId: UUID?
    let lookupSessionId: UUID?
    @State private var isPresentingAddMedication = false

    private var note: Note? {
        guard let noteId else { return nil }
        return appState.notes.first { $0.id == noteId }
    }
    private var lookupSession: LookupSession? {
        guard let lookupSessionId else { return nil }
        return appState.lookupSessions.first { $0.id == lookupSessionId }
    }

    private var title: String {
        switch (note != nil, lookupSession != nil) {
        case (true, true): return "Entry"
        case (true, false): return "Note"
        default: return "Results"
        }
    }

    var body: some View {
        List {
            if let note {
                Section {
                    noteCard(note)
                    if note.mentionedConcepts.isEmpty {
                        Text("No concepts identified in this note yet.")
                            .font(Theme.Font.body(14))
                            .foregroundStyle(Theme.Color.sub)
                            .plainRow()
                    } else {
                        ForEach(note.mentionedConcepts) { mention in
                            ConceptCard(
                                title: mention.conceptName,
                                tags: [mention.type.displayName],
                                shortText: mention.shortExplanation,
                                longTitle: "Details",
                                longText: mention.longExplanation
                            )
                            .plainRow()
                        }
                    }
                } header: {
                    SectionLabel(text: "Note")
                }
            }
            if let lookupSession {
                Section {
                    Text("Short version always shown — tap a medication for mechanism, side effects & nursing implications.")
                        .font(Theme.Font.body(13.5))
                        .foregroundStyle(Theme.Color.sub)
                        .plainRow()
                    ForEach(lookupSession.medications) { med in
                        ConceptCard(
                            title: med.name,
                            tags: med.relatedComplaints,
                            shortText: med.shortExplanation,
                            longTitle: "Mechanism & side effects",
                            longText: med.longExplanation
                        )
                        .plainRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                appState.removeMedication(med, from: lookupSession)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                    addMedicationRow
                        .plainRow()
                } header: {
                    SectionLabel(text: "Chart lookup · \(lookupSession.chiefComplaints.joined(separator: ", "))")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // The Journal list hides its nav bar; force this pushed view's bar
        // back so the system back button is present.
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $isPresentingAddMedication) {
            if let lookupSession {
                AddMedicationView(session: lookupSession)
            }
        }
    }

    private func noteCard(_ note: Note) -> some View {
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
        .plainRow()
    }

    /// Skeleton "add another item" row at the bottom of the medications
    /// list — tapping it opens a search sheet to append one more medication
    /// to this already-saved entry, rather than requiring a whole new entry.
    private var addMedicationRow: some View {
        Button {
            isPresentingAddMedication = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 19))
                Text("Add another medication")
                    .font(Theme.Font.heading(15))
                Spacer()
            }
            .foregroundStyle(Theme.Color.accentInk)
            .padding(16)
            .background(Theme.Color.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Color(hex: "C9BFAD"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }
}

/// Strips List's default row chrome (insets, separator, background) so
/// custom card content (ConceptCard, the note card, the add-medication
/// skeleton row) renders exactly as it does outside a List — needed here
/// only to get `.swipeActions` (a List-only modifier) on individual
/// medication rows within JournalEntryDetailView.
private extension View {
    func plainRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(SwiftUI.Color.clear)
    }
}

/// Search sheet for adding one more medication to an already-saved
/// LookupSession — reachable from JournalEntryDetailView's "Add another
/// medication" row.
private struct AddMedicationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let session: LookupSession
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var suggestions: [ConceptSummary] {
        guard !trimmedQuery.isEmpty else { return [] }
        let existing = Set(session.medications.map { $0.name.lowercased() })
        return appState.library.search(trimmedQuery)
            .filter { $0.type == .medication && !existing.contains($0.name.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.sub)
                    TextField("Search a medication", text: $query)
                        .font(Theme.Font.body(15, weight: .semibold))
                        .focused($searchFocused)
                        .autocorrectionDisabled()
                }
                .padding(13)
                .background(SwiftUI.Color.white)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(24)

                if trimmedQuery.isEmpty {
                    Text("Search for a medication to add to this entry.")
                        .font(Theme.Font.body(13.5))
                        .foregroundStyle(Theme.Color.sub)
                        .padding(.horizontal, 24)
                    Spacer()
                } else if suggestions.isEmpty {
                    Text("No matches.")
                        .font(Theme.Font.body(13.5))
                        .foregroundStyle(Theme.Color.sub)
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    List(suggestions) { suggestion in
                        Button {
                            appState.addMedication(suggestion.name, to: session)
                            dismiss()
                        } label: {
                            HStack {
                                Text(suggestion.matchedAlias ?? suggestion.name)
                                    .font(Theme.Font.body(14.5, weight: .semibold))
                                    .foregroundStyle(Theme.Color.ink)
                                Spacer()
                                Text(suggestion.type.displayName)
                                    .font(Theme.Font.body(11, weight: .bold))
                                    .foregroundStyle(Theme.Color.sub)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        searchFocused = false
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Color.sub)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            .onAppear { searchFocused = true }
        }
    }
}

#Preview {
    JournalView().environmentObject(AppState())
}
