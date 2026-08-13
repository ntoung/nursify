import SwiftUI

/// The curated/passive tab. The personalized suggestion feed (driven by the
/// Suggestion Engine in REQUIREMENTS.md / SYSTEM_DESIGN.md) isn't built yet, so
/// rather than show placeholder content this shows an honest empty state until
/// there's real activity to surface. Search lives in its own tab; Learn keeps a
/// small shortcut icon for convenience.
struct LearnView: View {
    @EnvironmentObject private var appState: AppState

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 0..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }
        let firstName = appState.userProfile.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
        guard let firstName, !firstName.isEmpty else { return timeGreeting }
        return "\(timeGreeting), Nurse \(firstName)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(greeting)
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

                    EmptyStateView(
                        icon: "sparkles",
                        title: "Nothing to review yet",
                        message: "As you capture notes and look concepts up, personalized suggestions and review reminders will show up here."
                    )
                    .padding(.top, 40)
                }
                .padding(24)
            }
            .background(Theme.Color.background.ignoresSafeArea())
        }
    }
}

#Preview {
    LearnView().environmentObject(AppState())
}
