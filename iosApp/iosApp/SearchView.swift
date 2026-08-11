import SwiftUI

/// The utility-focused tab: search + alias-aware autocomplete + category
/// browse + recent/history. Deliberately has no suggestion feed — that's
/// Learn's job. See REQUIREMENTS.md "Learn page — search, browse & history".
struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = "furosemide"

    private var matchingConcepts: [Concept] {
        guard !query.isEmpty else { return [] }
        return appState.concepts.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.aliases.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.sub)
                            TextField("Medications, procedures, conditions, TAVR...", text: $query)
                                .font(Theme.Font.body(15, weight: .semibold))
                        }
                        .padding(13)
                        .background(SwiftUI.Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        NavigationLink(destination: SearchHistoryView()) {
                            Image(systemName: "clock")
                                .foregroundStyle(Theme.Color.sub)
                                .frame(width: 48, height: 48)
                                .background(SwiftUI.Color.white)
                                .overlay(Circle().stroke(Theme.Color.line, lineWidth: 1.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 8)

                    if !matchingConcepts.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(matchingConcepts) { concept in
                                NavigationLink(destination: ConceptDetailView(concept: concept)) {
                                    AutocompleteRow(concept: concept)
                                }
                                .buttonStyle(.plain)
                                if concept.id != matchingConcepts.last?.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(SwiftUI.Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1))
                        .padding(.top, 10)
                    }

                    SectionLabel(text: "Browse by topic")
                        .padding(.top, 22)
                        .padding(.bottom, 6)

                    FlowLayout(spacing: 8) {
                        ForEach(ConceptType.allCases) { type in
                            SelectableChip(text: type.rawValue, isSelected: false)
                        }
                    }

                    SectionLabel(text: "Recent")
                        .padding(.top, 22)
                        .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        ForEach(appState.searchHistory.prefix(4)) { entry in
                            if let concept = appState.concept(id: entry.conceptID) {
                                NavigationLink(destination: ConceptDetailView(concept: concept)) {
                                    RecentRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                if entry.id != appState.searchHistory.prefix(4).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Search")
        }
    }
}

private struct AutocompleteRow: View {
    let concept: Concept

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(concept.name).font(Theme.Font.heading(14.5)).foregroundStyle(Theme.Color.ink)
                Spacer()
                Text(concept.type.rawValue).font(Theme.Font.body(11, weight: .bold)).foregroundStyle(Theme.Color.sub)
            }
            if let sideEffects = concept.sections.sideEffects {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                    Text(sideEffects).font(Theme.Font.body(12, weight: .semibold)).lineLimit(1)
                }
                .foregroundStyle(Theme.Color.warnInk)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}

private struct RecentRow: View {
    let entry: SearchHistoryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.conceptName).font(Theme.Font.heading(14.5)).foregroundStyle(Theme.Color.ink)
                Text(entry.type.rawValue).font(Theme.Font.body(12, weight: .semibold)).foregroundStyle(Theme.Color.sub)
            }
            Spacer()
            Text(entry.viewedAt.relativeDescription).font(Theme.Font.body(12, weight: .semibold)).foregroundStyle(Theme.Color.sub)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct SearchHistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            ForEach(appState.searchHistory) { entry in
                if let concept = appState.concept(id: entry.conceptID) {
                    NavigationLink(destination: ConceptDetailView(concept: concept)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.conceptName).font(Theme.Font.heading(15))
                            Text("\(entry.type.rawValue) · \(entry.viewedAt.relativeDescription)")
                                .font(Theme.Font.body(12))
                                .foregroundStyle(Theme.Color.sub)
                        }
                    }
                }
            }
        }
        .overlay {
            if appState.searchHistory.isEmpty {
                Text("No search history yet.")
                    .font(Theme.Font.body(14))
                    .foregroundStyle(Theme.Color.sub)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.background)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { appState.clearSearchHistory() }
            }
        }
    }
}

#Preview {
    SearchView().environmentObject(AppState())
}
