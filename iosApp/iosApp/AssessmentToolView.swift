import SwiftUI

/// Learn/Score body for ASSESSMENT_TOOL concepts (GCS, NIHSS, Braden, …). The
/// "Learn" tab is a reference (component ranges + colour-coded interpretation
/// bands); the "Score" tab is an interactive calculator that tallies the
/// selected component points and maps the total to its band. Rendered inside
/// ConceptDetailView when a concept carries structured `assessment` scoring.
struct AssessmentToolBody: View {
    let scoring: AssessmentScoring

    private enum Mode: String, CaseIterable { case learn = "Learn", score = "Score" }
    @State private var mode: Mode = .learn
    /// component name -> selected option points
    @State private var selection: [String: Int] = [:]

    private var total: Int { scoring.components.reduce(0) { $0 + (selection[$1.name] ?? 0) } }
    private var scoredCount: Int { scoring.components.filter { selection[$0.name] != nil }.count }
    private var complete: Bool { scoredCount == scoring.components.count }
    private var currentBand: AssessmentBand? { scoring.bands.first { total >= $0.min && total <= $0.max } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            toggle
            if mode == .learn { learn } else { score }
            if let note = scoring.criticalNote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(note).font(Theme.Font.body(13, weight: .semibold))
                }
                .foregroundStyle(Theme.Color.warnInk)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Color.warnBackground)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Color.warnLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Segmented toggle

    private var toggle: some View {
        HStack(spacing: 3) {
            ForEach(Mode.allCases, id: \.self) { m in
                Text(m.rawValue)
                    .font(Theme.Font.body(14, weight: .bold))
                    .foregroundStyle(mode == m ? Theme.Color.ink : Theme.Color.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(mode == m ? Theme.Color.card : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .shadow(color: mode == m ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { mode = m } }
            }
        }
        .padding(3)
        .background(Theme.Color.tagBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Learn

    private var learn: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Components & scoring")
                VStack(spacing: 0) {
                    ForEach(scoring.components) { component in
                        HStack {
                            Text(component.name).font(Theme.Font.body(14.5))
                            Spacer()
                            Text(range(component))
                                .font(Theme.Font.body(12.5, weight: .bold))
                                .foregroundStyle(Theme.Color.accentInk)
                                .padding(.horizontal, 9).padding(.vertical, 2)
                                .background(Theme.Color.accentSoftBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.vertical, 10)
                        if component.id != scoring.components.last?.id {
                            Divider()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Interpreting the score")
                ForEach(scoring.bands) { band in
                    let c = colors(band.severity)
                    HStack(spacing: 10) {
                        Text(scoreLabel(band)).font(Theme.Font.body(13.5, weight: .bold)).frame(minWidth: 58, alignment: .leading)
                        Text(band.label).font(Theme.Font.body(13.5))
                    }
                    .foregroundStyle(c.fg)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(c.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Score

    private var score: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(total)").font(Theme.Font.heading(26, weight: .bold)).foregroundStyle(Theme.Color.ink)
                        Text("/ \(maxTotal)").font(Theme.Font.body(14, weight: .bold)).foregroundStyle(Theme.Color.sub)
                    }
                    Text(complete ? "Total score" : "\(scoredCount) of \(scoring.components.count) scored")
                        .font(Theme.Font.body(11, weight: .bold)).foregroundStyle(Theme.Color.sub)
                }
                Spacer()
                if complete, let band = currentBand {
                    let c = colors(band.severity)
                    Text(band.label)
                        .font(Theme.Font.body(13, weight: .bold))
                        .foregroundStyle(c.fg)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(c.bg)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.Color.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Color.accentBorder, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            ForEach(scoring.components) { component in
                VStack(alignment: .leading, spacing: 7) {
                    Text(component.name).font(Theme.Font.body(13.5, weight: .bold)).foregroundStyle(Theme.Color.ink)
                    FlowLayout(spacing: 7) {
                        ForEach(component.options) { option in
                            let selected = selection[component.name] == option.points
                            Text("\(option.label) · \(option.points)")
                                .font(Theme.Font.body(13, weight: .semibold))
                                .foregroundStyle(selected ? .white : Theme.Color.ink)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selected ? Theme.Color.accent : Theme.Color.card)
                                .overlay(Capsule().stroke(selected ? Theme.Color.accent : Theme.Color.line, lineWidth: 1.5))
                                .clipShape(Capsule())
                                .contentShape(Capsule())
                                .onTapGesture { selection[component.name] = option.points }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !selection.isEmpty {
                Button("Reset") { selection = [:] }
                    .font(Theme.Font.body(13, weight: .bold))
                    .foregroundStyle(Theme.Color.sub)
                    .frame(maxWidth: .infinity)
            }

            Text("Educational reference, not clinical decision support.")
                .font(Theme.Font.body(11.5))
                .foregroundStyle(Theme.Color.sub)
        }
    }

    // MARK: - Helpers

    private var maxTotal: Int {
        scoring.components.reduce(0) { $0 + ($1.options.map(\.points).max() ?? 0) }
    }

    private func range(_ component: AssessmentComponent) -> String {
        let pts = component.options.map(\.points)
        let lo = pts.min() ?? 0, hi = pts.max() ?? 0
        return lo == hi ? "\(lo)" : "\(lo)–\(hi)"
    }

    private func scoreLabel(_ band: AssessmentBand) -> String {
        band.min == band.max ? "\(band.min)" : "\(band.min)–\(band.max)"
    }

    private func colors(_ severity: String) -> (bg: Color, fg: Color) {
        switch severity.lowercased() {
        case "mild": return (Theme.Color.accentSoftBackground, Theme.Color.accentInk)
        case "moderate": return (Theme.Color.warnBackground, Theme.Color.warnInk)
        default: return (Theme.Color.badgeDueBackground, Theme.Color.badgeDueInk)
        }
    }
}
