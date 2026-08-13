import SwiftUI

/// Reusable pieces shared across screens, matching mockups/v4/screens.html.

struct SelectableChip: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(Theme.Font.body(14.5, weight: .bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.Color.accent : SwiftUI.Color.white)
            .foregroundStyle(isSelected ? .white : Theme.Color.ink)
            .overlay(
                Capsule().stroke(isSelected ? Theme.Color.accent : Theme.Color.line, lineWidth: 1.5)
            )
            .clipShape(Capsule())
    }
}

struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Font.heading(11))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.Color.accentSoftBackground)
            .foregroundStyle(Theme.Color.accentInk)
            .clipShape(Capsule())
    }
}

struct SuggestionBadge: View {
    let kind: SuggestionKind

    private var label: String {
        switch kind {
        case .due: return "Due"
        case .gap: return "Gap"
        case .related: return "Related"
        case .practice: return "Practice"
        case .core: return "Core"
        }
    }

    private var colors: (bg: Color, fg: Color) {
        switch kind {
        case .due: return (Theme.Color.badgeDueBackground, Theme.Color.badgeDueInk)
        case .gap, .related: return (Theme.Color.badgeNewBackground, Theme.Color.badgeNewInk)
        case .practice: return (Theme.Color.badgePracticeBackground, Theme.Color.badgePracticeInk)
        case .core: return (Theme.Color.badgeCoreBackground, Theme.Color.badgeCoreInk)
        }
    }

    var body: some View {
        Text(label.uppercased())
            .font(Theme.Font.heading(11))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(colors.bg)
            .foregroundStyle(colors.fg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Font.heading(13))
            .foregroundStyle(Theme.Color.sub)
            .tracking(0.5)
    }
}

struct EducationalDisclaimerBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
            Text("Educational reference — not clinical decision support")
                .font(Theme.Font.heading(12.5))
        }
        .foregroundStyle(Theme.Color.accentInk)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Theme.Color.accentSoftBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "CFE6DB"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.heading(16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Theme.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
        .buttonStyle(.plain)
    }
}

/// Tap-to-expand card: short version always visible, tap reveals the long
/// version in place. Reused for Chart Lookup results and Note Detail's
/// "mentioned in this note" list — same interaction pattern everywhere,
/// per the "short always visible, tap for long" decision in REQUIREMENTS.md.
struct ConceptCard: View {
    let title: String
    let tags: [String]
    let shortText: String
    let longTitle: String
    let longText: String?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title).font(Theme.Font.heading(17))
                Spacer()
                if longText != nil {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(isExpanded ? Theme.Color.accentInk : Theme.Color.sub)
                }
            }
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { TagPill(text: $0) }
                }
            }
            Text(shortText)
                .font(Theme.Font.body(14.5))
                .foregroundStyle(Theme.Color.ink)

            if let longText {
                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                        Text(longTitle.uppercased())
                            .font(Theme.Font.heading(11.5))
                            .foregroundStyle(Theme.Color.sub)
                        Text(longText)
                            .font(Theme.Font.body(13.5))
                            .foregroundStyle(Theme.Color.ink)
                    }
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.down").font(.system(size: 11))
                        Text("Tap for \(longTitle.lowercased())")
                            .font(Theme.Font.body(12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Color.sub)
                }
            }
        }
        .padding(16)
        .background(Theme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard longText != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
    }
}

/// Shared empty-state placeholder — an icon, a title, and a short explanation.
/// Used wherever a list starts out with nothing to show (Capture notes, Learn
/// feed) so those screens read as intentionally empty rather than broken.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Theme.Color.sub)
            Text(title)
                .font(Theme.Font.heading(18))
                .foregroundStyle(Theme.Color.ink)
            Text(message)
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.Color.sub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }
}
