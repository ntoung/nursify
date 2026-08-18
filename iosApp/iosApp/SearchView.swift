import SwiftUI

/// The utility-focused tab: relevance-ranked, typo-tolerant search with
/// alias-aware autocomplete and category browse, served from the offline
/// ConceptLibrary. (Viewed concepts are tracked by the gamification usage
/// summary on Home - there's no separate search-history list here.)
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
                                // Always visible — with nothing typed, it's the
                                // only way to dismiss the keyboard without
                                // hitting Return, so it just resigns focus
                                // instead of having nothing to clear.
                                Button {
                                    if query.isEmpty {
                                        searchFieldFocused = false
                                    } else {
                                        query = ""
                                        results = []
                                        searchFieldFocused = false
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.Color.sub)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(13)
                            .background(Theme.Color.card)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
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
                    }
                    .animation(.easeInOut(duration: 0.25), value: activeCategory)
                    .padding(24)
                }
                // Drag-to-dismiss (the keyboard follows the scroll like
                // Messages/Mail), plus a plain tap anywhere else on screen —
                // .simultaneous so it doesn't swallow taps meant for buttons/
                // NavigationLinks underneath.
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { searchFieldFocused = false })
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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

    private func selectCategory(_ type: ConceptType) {
        searchFieldFocused = false
        activeCategory = (activeCategory == type) ? nil : type
    }

    /// Fetches results for the current query + topic scope. With a query, it
    /// searches (debounced) and filters to the active topic if one is set;
    /// with no query it browses the active topic, or clears the results.
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

#Preview {
    SearchView().environmentObject(AppState())
}
