import SwiftUI

/// The curated/passive tab: personalized suggestion feed only, driven by the
/// Suggestion Engine (see REQUIREMENTS.md / SYSTEM_DESIGN.md). Search lives
/// in its own tab now — Learn keeps a small shortcut icon for convenience.
struct LearnView: View {
    @EnvironmentObject private var appState: AppState

    private var due: [Suggestion] { appState.suggestions.filter { $0.kind == .due } }
    private var newToExplore: [Suggestion] { appState.suggestions.filter { [.gap, .related, .practice].contains($0.kind) } }
    private var specialtyFocus: [Suggestion] { appState.suggestions.filter { $0.kind == .core } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Good morning, Jamie")
                            .font(Theme.Font.heading(25))
                        Spacer()
                        NavigationLink(destination: SearchView()) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.Color.sub)
                                .frame(width: 40, height: 40)
                                .background(SwiftUI.Color.white)
                                .overlay(Circle().stroke(Theme.Color.line, lineWidth: 1.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 8)

                    Text("🔥 \(appState.streakDays)-day streak")
                        .font(Theme.Font.body(13, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                        .padding(.top, 6)
                        .padding(.bottom, 14)

                    if appState.suggestions.isEmpty {
                        ProgressView().padding(.top, 20)
                    } else {
                        suggestionSection(title: "Due for review", items: due)
                        suggestionSection(title: "New to explore", items: newToExplore)
                        suggestionSection(title: "Specialty focus · Telemetry", items: specialtyFocus)
                    }
                }
                .padding(24)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .task { await appState.loadSuggestions() }
        }
    }

    @ViewBuilder
    private func suggestionSection(title: String, items: [Suggestion]) -> some View {
        if !items.isEmpty {
            SectionLabel(text: title).padding(.top, 8).padding(.bottom, 8)
            VStack(spacing: 12) {
                ForEach(items) { SuggestionRow(suggestion: $0) }
            }
            .padding(.bottom, 8)
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(suggestion.title).font(Theme.Font.heading(16.5))
                Spacer()
                SuggestionBadge(kind: suggestion.kind)
            }
            Text(suggestion.reason)
                .font(Theme.Font.body(13.5))
                .foregroundStyle(Theme.Color.sub)
        }
        .padding(16)
        .background(SwiftUI.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 2)
    }
}

#Preview {
    LearnView().environmentObject(AppState())
}
