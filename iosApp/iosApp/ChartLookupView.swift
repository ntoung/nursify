import Foundation
import SwiftUI

/// Chart tab: input (chief complaints + medications as editable chips) ->
/// results (tap-to-expand ConceptCards). History is shift-scoped and,
/// per SYSTEM_DESIGN.md, lives only in AppState/on-device — never synced.
struct ChartLookupInputView: View {
    @EnvironmentObject private var appState: AppState
    @State private var complaints: [String] = ["CHF exacerbation", "Shortness of breath"]
    @State private var medications: [String] = ["Furosemide", "Metoprolol", "Lisinopril"]
    @State private var currentSession: LookupSession?

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

                    editableChipSection(title: "Chief complaints", items: $complaints)
                    editableChipSection(title: "Medications", items: $medications)

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
                }
                .padding(24)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    PrimaryButton(title: "Get explanations") {
                        let session = makeSession()
                        appState.addLookupSession(session)
                        currentSession = session
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
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Chart Lookup")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ChartLookupHistoryView()) {
                        Image(systemName: "clock")
                    }
                }
            }
            .navigationDestination(item: $currentSession) { session in
                ChartLookupResultsView(session: session)
            }
        }
    }

    private func makeSession() -> LookupSession {
        let meds = medications.map { appState.medicationExplanation(for: $0, complaints: complaints) }
        return LookupSession(
            id: UUID(),
            chiefComplaints: complaints,
            medications: meds,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        )
    }

    @ViewBuilder
    private func editableChipSection(title: String, items: Binding<[String]>) -> some View {
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
        }
    }
}

struct ChartLookupHistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
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
        .overlay {
            if appState.lookupSessions.isEmpty {
                Text("No lookups yet this shift.")
                    .font(Theme.Font.body(14))
                    .foregroundStyle(Theme.Color.sub)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.background)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { appState.clearLookupHistory() }
            }
        }
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
    ChartLookupInputView().environmentObject(AppState())
}
