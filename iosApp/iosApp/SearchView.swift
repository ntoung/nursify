import SwiftUI

/// The utility-focused tab: search + alias-aware autocomplete + category
/// browse + recent/history — all now backed by real calls to `backend/`
/// via AppState/APIClient. See REQUIREMENTS.md "Learn page — search,
/// browse & history".
struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var results: [ConceptSummary] = []
    @State private var activeCategory: ConceptType?
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.sub)
                            TextField("Medications, procedures, conditions, TAVR...", text: $query)
                                .font(Theme.Font.body(15, weight: .semibold))
                                .focused($searchFieldFocused)
                            if !query.isEmpty {
                                Button {
                                    query = ""
                                    results = []
                                    searchFieldFocused = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.Color.sub)
                                }
                                .buttonStyle(.plain)
                            }
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

                    if let activeCategory {
                        HStack {
                            Text("Category: \(activeCategory.displayName)")
                                .font(Theme.Font.body(12.5, weight: .semibold))
                                .foregroundStyle(Theme.Color.accentInk)
                            Spacer()
                            Button("Clear") {
                                self.activeCategory = nil
                                results = []
                            }
                            .font(Theme.Font.body(12.5, weight: .semibold))
                        }
                        .padding(.top, 10)
                    }

                    if !results.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(results) { item in
                                NavigationLink(destination: ConceptDetailView(conceptId: item.id)) {
                                    AutocompleteRow(item: item)
                                }
                                .buttonStyle(.plain)
                                if item.id != results.last?.id {
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
                            SelectableChip(text: type.displayName, isSelected: activeCategory == type)
                                .onTapGesture { selectCategory(type) }
                        }
                    }

                    SectionLabel(text: "Recent")
                        .padding(.top, 22)
                        .padding(.bottom, 4)

                    if appState.searchHistory.isEmpty {
                        Text("Nothing viewed yet.")
                            .font(Theme.Font.body(13.5))
                            .foregroundStyle(Theme.Color.sub)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(appState.searchHistory.prefix(4)) { entry in
                                NavigationLink(destination: ConceptDetailView(conceptId: entry.conceptId)) {
                                    RecentRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                if entry.id != appState.searchHistory.prefix(4).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(24)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Search")
            .task { await appState.loadSearchHistory() }
            .task(id: query) {
                guard !query.isEmpty else { return }
                activeCategory = nil
                do {
                    try await Task.sleep(nanoseconds: 300_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                results = await appState.searchConcepts(query: query)
            }
        }
    }

    private func selectCategory(_ type: ConceptType) {
        query = ""
        activeCategory = type
        Task {
            results = await appState.conceptsByCategory(type)
        }
    }
}

private struct AutocompleteRow: View {
    let item: ConceptSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name).font(Theme.Font.heading(14.5)).foregroundStyle(Theme.Color.ink)
                Spacer()
                Text(item.type.displayName).font(Theme.Font.body(11, weight: .bold)).foregroundStyle(Theme.Color.sub)
            }
            if let sideEffects = item.sideEffectsPreview {
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
                Text(entry.type.displayName).font(Theme.Font.body(12, weight: .semibold)).foregroundStyle(Theme.Color.sub)
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
                NavigationLink(destination: ConceptDetailView(conceptId: entry.conceptId)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.conceptName).font(Theme.Font.heading(15))
                        Text("\(entry.type.displayName) · \(entry.viewedAt.relativeDescription)")
                            .font(Theme.Font.body(12))
                            .foregroundStyle(Theme.Color.sub)
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
                Button("Clear") {
                    Task { await appState.clearSearchHistory() }
                }
            }
        }
        .task { await appState.loadSearchHistory() }
    }
}

#Preview {
    SearchView().environmentObject(AppState())
}
