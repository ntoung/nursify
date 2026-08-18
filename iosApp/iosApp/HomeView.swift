import SwiftUI

/// Home tab (renamed from Learn) — greeting, level/points, badge shelf, and
/// usage summary. See GAMIFICATION_ADR.md. The "learning tidbit" card that
/// used to live here moved to the top of the Journal tab.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var summaryPeriod: SummaryPeriod = .week
    @State private var selectedBadge: BadgeDefinition?

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
            VStack(alignment: .leading, spacing: 0) {
                Text(greeting)
                    .font(Theme.Font.heading(28, weight: .bold))
                    .foregroundStyle(Theme.Color.ink)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        levelCard

                        usageSummarySection

                        badgeShelf
                    }
                    .padding(24)
                    .padding(.bottom, 70)
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Level

    private var levelCard: some View {
        let progress = GamificationLevels.progress(for: appState.gamification.snapshot.totalPoints)
        let fraction = progress.pointsForNextLevel > 0
            ? Double(progress.pointsIntoLevel) / Double(progress.pointsForNextLevel)
            : 1

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(progress.level)")
                    .font(Theme.Font.heading(19))
                    .foregroundStyle(Theme.Color.ink)
                Spacer()
                Text("\(progress.pointsIntoLevel)/\(progress.pointsForNextLevel) to next level")
                    .font(Theme.Font.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Color.sub)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Color.line)
                    Capsule().fill(Theme.Color.accent)
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(Theme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Usage summary

    private var usageSummarySection: some View {
        let summary = appState.gamification.usageSummary(for: summaryPeriod)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Your activity")
                Spacer()
                Picker("Period", selection: $summaryPeriod) {
                    ForEach(SummaryPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryStat("Concepts viewed", value: summary.conceptsViewed)
                summaryStat("Searches", value: summary.searchesPerformed)
                summaryStat("Notes captured", value: summary.notesCaptured)
                summaryStat("Medication lookups", value: summary.chartLookupSessions)
                summaryStat("Active time", value: summary.activeMinutes, display: activeTimeLabel(summary.activeMinutes))
            }
        }
    }

    private func activeTimeLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func summaryStat(_ label: String, value: Int, display: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(display ?? "\(value)")
                .font(Theme.Font.heading(20))
                .foregroundStyle(Theme.Color.ink)
            Text(label)
                .font(Theme.Font.body(12, weight: .semibold))
                .foregroundStyle(Theme.Color.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Badge shelf

    private var badgeShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Badges")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 14)], spacing: 16) {
                ForEach(BadgeCatalog.all) { badge in
                    Button {
                        selectedBadge = badge
                    } label: {
                        BadgeMedallionView(badge: badge, isUnlocked: appState.gamification.unlockedBadgeIds.contains(badge.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(
                badge: badge,
                isUnlocked: appState.gamification.unlockedBadgeIds.contains(badge.id),
                progress: badge.progress(appState.gamification.snapshot)
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.Color.background)
        }
    }
}

/// Tapping a badge opens this - shows the badge, what it takes to earn, and
/// current progress toward it (a filled progress bar + "current / target").
private struct BadgeDetailSheet: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool
    let progress: BadgeProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badge.accentColor.opacity(0.15) : Theme.Color.line)
                    .frame(width: 92, height: 92)
                Image(systemName: isUnlocked ? badge.symbolName : "lock.fill")
                    .font(.system(size: isUnlocked ? 38 : 26, weight: .bold))
                    .foregroundStyle(isUnlocked ? badge.accentColor : Theme.Color.sub.opacity(0.6))
            }
            .padding(.top, 12)

            VStack(spacing: 6) {
                Text(badge.name)
                    .font(Theme.Font.heading(22, weight: .bold))
                    .foregroundStyle(Theme.Color.ink)
                Text(badge.description)
                    .font(Theme.Font.body(14))
                    .foregroundStyle(Theme.Color.sub)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(isUnlocked ? "Complete" : "Progress")
                        .font(Theme.Font.body(13, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                    Spacer()
                    Text(progress.label)
                        .font(Theme.Font.body(13, weight: .bold))
                        .foregroundStyle(isUnlocked ? badge.accentColor : Theme.Color.ink)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Color.line).frame(height: 9)
                        Capsule().fill(badge.accentColor)
                            .frame(width: max(9, geo.size.width * progress.fraction), height: 9)
                    }
                }
                .frame(height: 9)
            }

            HStack(spacing: 6) {
                Image(systemName: isUnlocked ? "checkmark.seal.fill" : "sparkles")
                Text(isUnlocked ? "Earned +\(badge.pointBonus) points" : "Worth +\(badge.pointBonus) points")
            }
            .font(Theme.Font.body(13, weight: .semibold))
            .foregroundStyle(isUnlocked ? badge.accentColor : Theme.Color.sub)

            Spacer(minLength: 0)

            PrimaryButton(title: "Done") { dismiss() }
        }
        .padding(24)
    }
}

private struct BadgeMedallionView: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badge.accentColor.opacity(0.15) : Theme.Color.line)
                    .frame(width: 64, height: 64)
                Image(systemName: isUnlocked ? badge.symbolName : "lock.fill")
                    .font(.system(size: isUnlocked ? 26 : 18, weight: .bold))
                    .foregroundStyle(isUnlocked ? badge.accentColor : Theme.Color.sub.opacity(0.6))
            }
            Text(badge.name)
                .font(Theme.Font.body(11, weight: .semibold))
                .foregroundStyle(isUnlocked ? Theme.Color.ink : Theme.Color.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28)
        }
    }
}

#Preview {
    HomeView().environmentObject(AppState())
}
