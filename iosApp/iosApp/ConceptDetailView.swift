import SwiftUI

/// Every concept type renders from this one view — common structure (tags,
/// disclaimer, short explanation, related concepts, citation) plus
/// type-specific sections. See REQUIREMENTS.md "Concept detail pages".
struct ConceptDetailView: View {
    @EnvironmentObject private var appState: AppState
    let concept: Concept

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !concept.tags.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(concept.tags, id: \.self) { tag in
                            Text(tag)
                                .font(Theme.Font.heading(12))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Color(hex: "F1ECE1"))
                                .foregroundStyle(Theme.Color.sub)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                EducationalDisclaimerBanner()

                if let alias = concept.aliases.first {
                    Text("Also known as: \(alias.text)")
                        .font(Theme.Font.body(12.5, weight: .semibold))
                        .foregroundStyle(Theme.Color.sub)
                }

                labeledParagraph("In short", concept.shortExplanation)

                ForEach(typeSpecificSections, id: \.label) { section in
                    if section.isHighlighted {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: section.label)
                            Text(section.content)
                                .font(Theme.Font.body(15))
                                .foregroundStyle(Theme.Color.ink)
                        }
                    } else {
                        labeledParagraph(section.label, section.content)
                    }
                }

                if !concept.relatedConceptIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Related concepts")
                        FlowLayout(spacing: 8) {
                            ForEach(concept.relatedConceptIDs, id: \.self) { id in
                                if let related = appState.concept(id: id) {
                                    NavigationLink(destination: ConceptDetailView(concept: related)) {
                                        Text(related.name)
                                            .font(Theme.Font.body(13.5, weight: .bold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(SwiftUI.Color.white)
                                            .foregroundStyle(Theme.Color.accentInk)
                                            .overlay(Capsule().stroke(Theme.Color.line, lineWidth: 1.5))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if let citation = concept.sourceCitation {
                    Divider()
                    Text(citation)
                        .font(Theme.Font.body(12))
                        .foregroundStyle(Theme.Color.sub)
                }
            }
            .padding(24)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle(concept.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appState.recordSearchHistory(for: concept) }
    }

    @ViewBuilder
    private func labeledParagraph(_ label: String, _ content: String) -> some View {
        (Text("\(label): ").font(Theme.Font.heading(15)) + Text(content).font(Theme.Font.body(15)))
            .foregroundStyle(Theme.Color.ink)
    }

    private struct DetailSection {
        let label: String
        let content: String
        let isHighlighted: Bool
    }

    /// Mirrors the type→sections table in REQUIREMENTS.md "Concept detail pages".
    private var typeSpecificSections: [DetailSection] {
        var sections: [DetailSection] = []
        let s = concept.sections
        switch concept.type {
        case .medication:
            if let v = s.nursingImplications { sections.append(.init(label: "Nursing implications", content: v, isHighlighted: false)) }
            if let v = s.sideEffects { sections.append(.init(label: "Side effects", content: v, isHighlighted: true)) }
            if let v = s.adverseEffects { sections.append(.init(label: "Adverse effects", content: v, isHighlighted: true)) }
            if let v = s.commonBrandName { sections.append(.init(label: "Common brand name", content: v, isHighlighted: false)) }
        case .procedure:
            if let v = s.targetConcern { sections.append(.init(label: "Target concern", content: v, isHighlighted: true)) }
            if let v = s.whatToMonitor { sections.append(.init(label: "What to monitor", content: v, isHighlighted: true)) }
            if let meds = s.medicationsUsed, !meds.isEmpty {
                sections.append(.init(label: "Medications typically used", content: meds.joined(separator: ", "), isHighlighted: true))
            }
        case .condition:
            if let v = s.presentation { sections.append(.init(label: "Presentation", content: v, isHighlighted: true)) }
            if let v = s.typicalTreatments { sections.append(.init(label: "Typical treatments", content: v, isHighlighted: true)) }
            if let v = s.riskFactors { sections.append(.init(label: "Risk factors", content: v, isHighlighted: true)) }
        case .labValue:
            if let v = s.normalRange { sections.append(.init(label: "Normal range", content: v, isHighlighted: true)) }
            if let v = s.abnormalMeaning { sections.append(.init(label: "What abnormal values mean", content: v, isHighlighted: true)) }
        case .equipment:
            if let v = s.purpose { sections.append(.init(label: "Purpose", content: v, isHighlighted: true)) }
            if let v = s.careConsiderations { sections.append(.init(label: "Care considerations", content: v, isHighlighted: true)) }
        case .protocolOrderSet:
            if let v = s.triggerCriteria { sections.append(.init(label: "Trigger criteria", content: v, isHighlighted: true)) }
            if let v = s.steps { sections.append(.init(label: "Steps", content: v, isHighlighted: true)) }
        case .anatomy:
            break
        }
        return sections
    }
}

#Preview {
    NavigationStack {
        ConceptDetailView(concept: MockData.concepts[0])
    }
    .environmentObject(AppState())
}
