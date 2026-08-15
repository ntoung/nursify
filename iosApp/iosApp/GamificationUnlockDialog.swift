import SwiftUI

/// Transient modal dialog for a badge unlock or level-up — see
/// GAMIFICATION_ADR.md "UI treatment". Never fires for a plain point gain;
/// only these two milestone moments. Presented app-wide (ContentView), not
/// per-screen, since an unlock can happen while the nurse is anywhere in
/// the app.
extension View {
    func gamificationUnlockDialog(_ engine: GamificationEngine) -> some View {
        modifier(GamificationUnlockDialogModifier(engine: engine))
    }
}

private struct GamificationUnlockDialogModifier: ViewModifier {
    @ObservedObject var engine: GamificationEngine

    func body(content: Content) -> some View {
        content.overlay {
            if let unlock = engine.unlockQueue.first {
                UnlockDialogView(unlock: unlock) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        engine.dismissCurrentUnlock()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.unlockQueue.first?.id)
    }
}

private struct UnlockDialogView: View {
    let unlock: GamificationUnlock
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            SwiftUI.Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                medallion

                VStack(spacing: 6) {
                    Text(eyebrow)
                        .font(Theme.Font.heading(12))
                        .tracking(1.2)
                        .foregroundStyle(Theme.Color.sub)
                    Text(title)
                        .font(Theme.Font.heading(24))
                        .foregroundStyle(Theme.Color.ink)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(Theme.Font.body(14.5))
                        .foregroundStyle(Theme.Color.sub)
                        .multilineTextAlignment(.center)
                }

                PrimaryButton(title: "Nice!", action: onDismiss)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(SwiftUI.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
            .padding(.horizontal, 32)
        }
    }

    private var medallion: some View {
        ZStack {
            Circle().fill(medallionColor.opacity(0.15)).frame(width: 108, height: 108)
            Circle().stroke(medallionColor, lineWidth: 3).frame(width: 108, height: 108)
            Image(systemName: symbolName)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(medallionColor)
        }
    }

    private var symbolName: String {
        switch unlock {
        case .badge(let badge): return badge.symbolName
        case .levelUp: return "arrow.up.circle.fill"
        }
    }

    private var medallionColor: Color {
        switch unlock {
        case .badge(let badge): return badge.accentColor
        case .levelUp: return Theme.Color.accent
        }
    }

    private var eyebrow: String {
        switch unlock {
        case .badge: return "BADGE UNLOCKED"
        case .levelUp: return "LEVEL UP"
        }
    }

    private var title: String {
        switch unlock {
        case .badge(let badge): return badge.name
        case .levelUp(let level): return "Level \(level)"
        }
    }

    private var subtitle: String {
        switch unlock {
        case .badge(let badge): return "\(badge.description) +\(badge.pointBonus) points"
        case .levelUp: return "Keep it up."
        }
    }
}
