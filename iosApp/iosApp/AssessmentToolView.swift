import SwiftUI
import UIKit

/// Learn/Score body for ASSESSMENT_TOOL concepts (GCS, NIHSS, Braden, …). The
/// "Learn" tab is a reference (component ranges + colour-coded interpretation
/// bands); the "Score" tab is an interactive calculator - tapping a component
/// slides up a bottom drawer with a haptic slider, an N/A button, and a
/// close/clear control.
struct AssessmentToolBody: View {
    let scoring: AssessmentScoring

    enum CompValue: Equatable { case value(Int), na }

    private enum Mode: String, CaseIterable { case learn = "Learn", score = "Score" }
    @State private var mode: Mode = .learn
    /// component name -> chosen value (absent = not scored yet)
    @State private var selection: [String: CompValue] = [:]
    /// The component whose scoring drawer is open, if any.
    @State private var activeComponent: AssessmentComponent?

    private var total: Int {
        scoring.components.reduce(0) { acc, c in
            if case .value(let p)? = selection[c.name] { return acc + p }
            return acc
        }
    }
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
                        if component.id != scoring.components.last?.id { Divider() }
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

            Text("Tap a component to score it")
                .font(Theme.Font.body(11.5, weight: .semibold))
                .foregroundStyle(Theme.Color.sub)

            ForEach(scoring.components) { component in
                ComponentRow(component: component, value: selection[component.name]) {
                    activeComponent = component
                }
            }

            if !selection.isEmpty {
                Button("Reset") { withAnimation { selection = [:] } }
                    .font(Theme.Font.body(13, weight: .bold))
                    .foregroundStyle(Theme.Color.sub)
                    .frame(maxWidth: .infinity)
            }

            Text("Educational reference, not clinical decision support.")
                .font(Theme.Font.body(11.5))
                .foregroundStyle(Theme.Color.sub)
        }
        .sheet(item: $activeComponent) { component in
            ComponentScorerSheet(
                component: component,
                value: Binding(
                    get: { selection[component.name] },
                    set: { selection[component.name] = $0 }
                )
            )
        }
    }

    // MARK: - Helpers

    private var maxTotal: Int { scoring.components.reduce(0) { $0 + ($1.options.map(\.points).max() ?? 0) } }
    private func range(_ c: AssessmentComponent) -> String {
        let pts = c.options.map(\.points); let lo = pts.min() ?? 0, hi = pts.max() ?? 0
        return lo == hi ? "\(lo)" : "\(lo)–\(hi)"
    }
    private func scoreLabel(_ b: AssessmentBand) -> String { b.min == b.max ? "\(b.min)" : "\(b.min)–\(b.max)" }
    private func colors(_ severity: String) -> (bg: Color, fg: Color) {
        switch severity.lowercased() {
        case "mild": return (Theme.Color.accentSoftBackground, Theme.Color.accentInk)
        case "moderate": return (Theme.Color.warnBackground, Theme.Color.warnInk)
        default: return (Theme.Color.badgeDueBackground, Theme.Color.badgeDueInk)
        }
    }
}

/// One component's row in the Score tab: shows the component name, the current
/// selection, and its point value; tapping anywhere opens the scoring drawer.
private struct ComponentRow: View {
    let component: AssessmentComponent
    let value: AssessmentToolBody.CompValue?
    let onTap: () -> Void

    private var options: [AssessmentOption] { component.options }
    private var isSet: Bool { value != nil }

    private var subLabel: String {
        switch value {
        case .some(.value(let p)): return options.first { $0.points == p }?.label ?? "\(p)"
        case .some(.na): return "Not applicable"
        case nil: return "Tap to score"
        }
    }

    private var displayNumber: String {
        switch value {
        case .some(.value(let p)): return "\(p)"
        case .some(.na): return "N/A"
        case nil: return "—"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name).font(Theme.Font.body(13.5, weight: .bold)).foregroundStyle(Theme.Color.ink)
                    Text(subLabel).font(Theme.Font.body(12)).foregroundStyle(Theme.Color.sub).lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(displayNumber)
                    .font(Theme.Font.heading(value == .na ? 15 : 19, weight: .bold))
                    .foregroundStyle(isSet ? .white : Theme.Color.sub)
                    .frame(minWidth: 60, minHeight: 44)
                    .background(isSet ? Theme.Color.accent : Theme.Color.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSet ? Theme.Color.accent : Theme.Color.line, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Color.sub)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.Color.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Color.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// Bottom drawer for scoring one component: a discrete haptic slider across the
/// component's options, an N/A button, and an X that clears the selection and
/// closes. Sliding gives a selection tick per step; N/A and Clear give a firmer
/// bump. The number/label above the slider tracks the current position live.
private struct ComponentScorerSheet: View {
    let component: AssessmentComponent
    @Binding var value: AssessmentToolBody.CompValue?
    @Environment(\.dismiss) private var dismiss

    /// Live slider position (option index). Kept distinct from `value` so the
    /// drawer can preview an option before the user has committed anything.
    @State private var index: Double
    /// Whether the user has actually engaged the slider this session - so a
    /// freshly opened drawer for an unscored component doesn't auto-commit 0.
    @State private var touched: Bool
    @State private var showingNA: Bool
    /// The last discrete detent we fired a haptic for. A stepped Slider can emit
    /// the same (or sub-step) value repeatedly during a drag, so we only tick
    /// when the integer step actually changes - otherwise it machine-guns the
    /// Taptic engine, worst at the ends where you drag against the stop.
    @State private var lastStep: Int

    private let tick = UISelectionFeedbackGenerator()
    private let bump = UIImpactFeedbackGenerator(style: .medium)

    private var options: [AssessmentOption] { component.options }

    init(component: AssessmentComponent, value: Binding<AssessmentToolBody.CompValue?>) {
        self.component = component
        self._value = value
        switch value.wrappedValue {
        case .some(.value(let p)):
            let i = component.options.firstIndex { $0.points == p } ?? 0
            _index = State(initialValue: Double(i))
            _touched = State(initialValue: true)
            _showingNA = State(initialValue: false)
            _lastStep = State(initialValue: i)
        case .some(.na):
            _index = State(initialValue: 0)
            _touched = State(initialValue: false)
            _showingNA = State(initialValue: true)
            _lastStep = State(initialValue: 0)
        case nil:
            _index = State(initialValue: 0)
            _touched = State(initialValue: false)
            _showingNA = State(initialValue: false)
            _lastStep = State(initialValue: 0)
        }
    }

    private var currentOption: AssessmentOption { options[Int(index.rounded())] }
    private var bigNumber: String { showingNA ? "N/A" : (touched ? "\(currentOption.points)" : "—") }
    private var bigLabel: String {
        if showingNA { return "Not applicable" }
        return touched ? currentOption.label : "Slide to score"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                // X (left) clears the selection and closes.
                Button {
                    value = nil
                    bump.impactOccurred()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.Color.sub.opacity(0.5))
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name)
                        .font(Theme.Font.heading(19, weight: .bold))
                        .foregroundStyle(Theme.Color.ink)
                    Text(range)
                        .font(Theme.Font.body(12.5, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                }
                Spacer()
            }

            VStack(spacing: 4) {
                Text(bigNumber)
                    .font(Theme.Font.heading(showingNA ? 30 : 44, weight: .bold))
                    .foregroundStyle(showingNA ? Theme.Color.sub : Theme.Color.accentInk)
                    .contentTransition(.numericText())
                Text(bigLabel)
                    .font(Theme.Font.body(14, weight: .semibold))
                    .foregroundStyle(Theme.Color.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                DiscreteSlider(index: $index, count: options.count, onStep: handleStep)
                    .disabled(options.count < 2)
                HStack {
                    Text("\(options.first?.points ?? 0)")
                    Spacer()
                    Text("\(options.last?.points ?? 0)")
                }
                .font(Theme.Font.body(11, weight: .bold))
                .foregroundStyle(Theme.Color.sub)
            }

            HStack(spacing: 12) {
                Button {
                    showingNA = true
                    touched = false
                    value = .na
                    bump.impactOccurred()
                } label: {
                    Text("N/A")
                        .font(Theme.Font.body(15, weight: .bold))
                        .foregroundStyle(showingNA ? .white : Theme.Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(showingNA ? Theme.Color.accent : Theme.Color.tagBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(Theme.Font.body(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .onAppear { tick.prepare(); bump.prepare() }
    }

    private var range: String {
        let pts = options.map(\.points); let lo = pts.min() ?? 0, hi = pts.max() ?? 0
        return lo == hi ? "Score \(lo)" : "Score \(lo)–\(hi)"
    }

    /// Commits the value for a step the track reports (tap or drag). Always
    /// commits (so a first tap on the current step still registers), but ticks
    /// only when the detent actually changes - one tap per step, no machine-gun.
    private func handleStep(_ step: Int) {
        let firstTouch = !touched
        touched = true
        showingNA = false
        value = .value(options[step].points)
        if step != lastStep || firstTouch {
            lastStep = step
            tick.selectionChanged()
            tick.prepare()
        }
    }
}

/// A discrete slider you can tap anywhere on (not just the thumb) to jump to a
/// value, and also drag - built on a zero-distance drag gesture over the whole
/// track, which the native SwiftUI `Slider` doesn't offer. Reports the touched
/// step to `onStep` on every change; the caller gates haptics/commit.
private struct DiscreteSlider: View {
    @Binding var index: Double
    let count: Int
    let onStep: (Int) -> Void

    private let thumb: CGFloat = 28
    private let trackHeight: CGFloat = 6
    private var maxIndex: Int { max(count - 1, 1) }

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumb, 1)
            let x = CGFloat(index / Double(maxIndex)) * usable
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Color.tagBackground)
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Theme.Color.accent)
                    .frame(width: x + thumb / 2, height: trackHeight)
                Circle()
                    .fill(.white)
                    .frame(width: thumb, height: thumb)
                    .overlay(Circle().stroke(Theme.Color.line, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .offset(x: x)
            }
            .frame(height: thumb)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let ratio = min(max((g.location.x - thumb / 2) / usable, 0), 1)
                        let step = Int((ratio * Double(maxIndex)).rounded())
                        index = Double(step)
                        onStep(step)
                    }
            )
        }
        .frame(height: 36)
    }
}
