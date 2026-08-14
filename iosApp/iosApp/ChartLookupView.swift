import Foundation
import SwiftUI

/// Charts tab root: a list of this shift's past lookups, shift-scoped and,
/// per SYSTEM_DESIGN.md, living only in AppState/on-device — never synced.
/// "New Chart" presents ChartLookupInputView as a sheet, always starting
/// empty; tapping a past chart pushes straight to its stored results.
struct ChartsListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isPresentingNewChart = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.lookupSessions.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.clipboard",
                        title: "No charts yet",
                        message: "Look up a chief complaint and medications to see why each drug is prescribed. Tap New Chart to get started."
                    )
                } else {
                    List {
                        ForEach(appState.lookupSessions) { session in
                            NavigationLink(destination: ChartLookupResultsView(session: session)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.chiefComplaints.joined(separator: ", "))
                                        .font(Theme.Font.heading(14.5))
                                    Text("\(session.medications.count) medications · \(session.createdAt.relativeDescription)")
                                        .font(Theme.Font.body(12.5))
                                        .foregroundStyle(Theme.Color.sub)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Charts")
            .toolbar {
                if !appState.lookupSessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { appState.clearLookupHistory() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    PrimaryButton(title: "New Chart") {
                        isPresentingNewChart = true
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Kept for this shift only — no patient identifiers ever stored")
                    }
                    .font(Theme.Font.body(12.5, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Theme.Color.background)
            }
            .sheet(isPresented: $isPresentingNewChart) {
                ChartLookupInputView()
            }
        }
    }
}

/// New-chart entry sheet: input (chief complaints + medications as editable
/// chips) -> results (tap-to-expand ConceptCards). Always opens empty —
/// ChartsListView presents a fresh instance each time.
struct ChartLookupInputView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var complaints: [String] = []
    @State private var medications: [String] = []
    @State private var currentSession: LookupSession?
    @State private var isLoading = false
    @State private var isAddingComplaint = false
    @State private var isAddingMedication = false
    @State private var newComplaintText = ""
    @State private var newMedicationText = ""
    @FocusState private var addFieldFocused: Bool

    private let quickComplaints = ["COPD flare", "Post-op pain", "Sepsis workup", "Chest pain"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing patient-identifiable is ever saved — for your reference only.")
                        .font(Theme.Font.body(15))
                        .foregroundStyle(Theme.Color.sub)
                        .padding(.top, 4)
                        .padding(.bottom, 4)

                    editableChipSection(
                        title: "Chief complaints",
                        placeholder: "Add complaint",
                        items: $complaints,
                        isAdding: $isAddingComplaint,
                        draftText: $newComplaintText
                    )
                    editableChipSection(
                        title: "Medications",
                        placeholder: "Add drug",
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
                }
                .padding(24)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    PrimaryButton(title: isLoading ? "Looking up..." : "Get explanations") {
                        guard !isLoading else { return }
                        Task { await performLookup() }
                    }
                    .disabled(isLoading || medications.isEmpty)
                    .opacity(medications.isEmpty ? 0.5 : 1)
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Kept for this shift only — no patient identifiers ever stored")
                    }
                    .font(Theme.Font.body(12.5, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Theme.Color.background)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("New Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // If a complaint/medication text field is focused, a
                        // toolbar tap can otherwise just dismiss the keyboard
                        // instead of triggering the button — resigning focus
                        // explicitly here means one tap always closes this.
                        addFieldFocused = false
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
            .navigationDestination(item: $currentSession) { session in
                ChartLookupResultsView(session: session)
            }
        }
    }

    private func performLookup() async {
        isLoading = true
        defer { isLoading = false }
        // Served from the offline concept library — no network, so this can't fail.
        currentSession = appState.performChartLookup(chiefComplaints: complaints, medicationNames: medications)
    }

    @ViewBuilder
    private func editableChipSection(
        title: String,
        placeholder: String,
        items: Binding<[String]>,
        isAdding: Binding<Bool>,
        draftText: Binding<String>
    ) -> some View {
        SectionLabel(text: title).padding(.top, 14).padding(.bottom, 8)
        FlowLayout(spacing: 9) {
            ForEach(items.wrappedValue, id: \.self) { item in
                HStack(spacing: 8) {
                    Text(item).font(Theme.Font.body(14, weight: .bold))
                    Button {
                        items.wrappedValue.removeAll { $0 == item }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.Color.sub)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(SwiftUI.Color.white)
                .overlay(Capsule().stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(Capsule())
            }

            if isAdding.wrappedValue {
                HStack(spacing: 6) {
                    TextField(placeholder, text: draftText)
                        .font(Theme.Font.body(14, weight: .semibold))
                        .frame(minWidth: 100)
                        .focused($addFieldFocused)
                        .onSubmit { commitAdd(items: items, draftText: draftText, isAdding: isAdding) }
                    Button {
                        commitAdd(items: items, draftText: draftText, isAdding: isAdding)
                    } label: {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Color.accentInk)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(SwiftUI.Color.white)
                .overlay(Capsule().stroke(Theme.Color.accent, lineWidth: 1.5))
                .clipShape(Capsule())
            } else {
                Button {
                    isAdding.wrappedValue = true
                    addFieldFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text(placeholder)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commitAdd(items: Binding<[String]>, draftText: Binding<String>, isAdding: Binding<Bool>) {
        let trimmed = draftText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !items.wrappedValue.contains(trimmed) {
            items.wrappedValue.append(trimmed)
        }
        draftText.wrappedValue = ""
        isAdding.wrappedValue = false
    }
}

struct ChartLookupResultsView: View {
    let session: LookupSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EducationalDisclaimerBanner()
                Text("Short version always shown — tap a medication for mechanism, side effects & nursing implications.")
                    .font(Theme.Font.body(15.5))
                    .foregroundStyle(Theme.Color.sub)

                ForEach(session.medications) { med in
                    ConceptCard(
                        title: med.name,
                        tags: med.relatedComplaints,
                        shortText: med.shortExplanation,
                        longTitle: "Mechanism & side effects",
                        longText: med.longExplanation
                    )
                }
            }
            .padding(24)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ChartsListView().environmentObject(AppState())
}
