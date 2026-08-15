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

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Combined key so the fetch re-runs when either the query or the active
    /// topic scope changes.
    private var searchKey: String { "\(trimmedQuery)|\(activeCategory?.rawValue ?? "")" }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Search")
                    .font(Theme.Font.heading(28, weight: .bold))
                    .foregroundStyle(Theme.Color.ink)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

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
                            .background(Theme.Color.card)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                            NavigationLink(destination: SearchHistoryView()) {
                                Image(systemName: "clock")
                                    .foregroundStyle(Theme.Color.sub)
                                    .frame(width: 48, height: 48)
                                    .background(Theme.Color.card)
                                    .overlay(Circle().stroke(Theme.Color.line, lineWidth: 1.5))
                                    .clipShape(Circle())
                            }
                        }

                        SectionLabel(text: "Browse by topic")
                            .padding(.top, 22)
                            .padding(.bottom, 8)

                        // Single-row carousel; bleeds to the screen edges past the
                        // parent's 24pt padding so chips scroll edge-to-edge.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ConceptType.allCases) { type in
                                    SelectableChip(text: type.displayName, isSelected: activeCategory == type)
                                        .onTapGesture { selectCategory(type) }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.horizontal, -24)

                        if !results.isEmpty {
                            resultsList
                        } else if !trimmedQuery.isEmpty || activeCategory != nil {
                            Text("No concepts found.")
                                .font(Theme.Font.body(13.5))
                                .foregroundStyle(Theme.Color.sub)
                                .padding(.vertical, 12)
                        }

                        if trimmedQuery.isEmpty && activeCategory == nil {
                            recentSection
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: activeCategory)
                    .padding(24)
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await appState.loadSearchHistory() }
            .task(id: searchKey) { await runSearch() }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
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
        .background(Theme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1))
        .padding(.top, 10)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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
    }

    private func selectCategory(_ type: ConceptType) {
        searchFieldFocused = false
        activeCategory = (activeCategory == type) ? nil : type
    }

    /// Fetches results for the current query + topic scope. With a query, it
    /// searches (debounced) and filters to the active topic if one is set;
    /// with no query it browses the active topic, or clears to show Recent.
    private func runSearch() async {
        if trimmedQuery.isEmpty {
            if let activeCategory {
                results = await appState.conceptsByCategory(activeCategory)
            } else {
                results = []
            }
            return
        }
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        let fetched = await appState.searchConcepts(query: trimmedQuery)
        if let activeCategory {
            results = fetched.filter { $0.type == activeCategory }
        } else {
            results = fetched
        }
    }
}

private struct AutocompleteRow: View {
    let item: ConceptSummary

    var body: some View {
        // Two lines: the exact match (alias if the search hit an alias, else the
        // name) as the title, then a lighter description line folding in the
        // canonical name (for alias hits), type, and any side-effect preview.
        VStack(alignment: .leading, spacing: 3) {
            Text(item.matchedAlias ?? item.name)
                .font(Theme.Font.heading(17, weight: .semibold))
                .foregroundStyle(Theme.Color.ink)
                .lineLimit(1)
            description.lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private var description: Text {
        let primary = item.matchedAlias != nil ? "\(item.name) · \(item.type.displayName)" : item.type.displayName
        var text = Text(primary)
            .font(Theme.Font.body(13.5))
            .foregroundColor(Theme.Color.sub)
        if let sideEffects = item.sideEffectsPreview {
            text = text
                + Text("  ·  ").font(Theme.Font.body(13.5)).foregroundColor(Theme.Color.sub)
                + Text(sideEffects).font(Theme.Font.body(12.5, weight: .semibold)).foregroundColor(Theme.Color.warnInk)
        }
        return text
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
                // List rows keep their own opaque system cell background
                // even with .scrollContentBackground(.hidden) on the List
                // itself — without clearing it per-row, rows render with
                // the system default (black in Dark Mode) instead of the
                // screen's actual background showing through.
                .listRowBackground(SwiftUI.Color.clear)
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
