import SwiftUI

/// Every concept type renders from this one view — common structure (tags,
/// disclaimer, short explanation, related concepts, citation) plus
/// type-specific sections. See REQUIREMENTS.md "Concept detail pages".
///
/// Takes an id rather than a full Concept: search/category-browse only
/// return the lightweight ConceptSummary shape, so full detail (sections,
/// related concepts, citation) is fetched by id when this view appears.
struct ConceptDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let conceptId: UUID

    @State private var concept: Concept?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let concept {
                content(for: concept)
            } else if let loadError {
                VStack(spacing: 12) {
                    Text("Couldn't load this concept.")
                        .font(Theme.Font.heading(15))
                    Text(loadError)
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.Color.sub)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await load() } }
                        .font(Theme.Font.body(14, weight: .semibold))
                }
                .padding(32)
            } else {
                ProgressView().padding(40)
            }
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: conceptId) { await load() }
    }

    private func load() async {
        loadError = nil
        do {
            let loaded = try await appState.fetchConcept(id: conceptId)
            concept = loaded
            await appState.recordConceptView(conceptId: conceptId)
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func content(for concept: Concept) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Back chevron sits in line with the title (no wasted nav-bar
                // space), title + aliases read as one unit beside it.
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.Color.ink)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(concept.name)
                            .font(Theme.Font.heading(26, weight: .bold))
                            .foregroundStyle(Theme.Color.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if !concept.aliases.isEmpty {
                            Text(concept.aliases.map(\.text).joined(separator: " · "))
                                .font(Theme.Font.body(12.5, weight: .semibold))
                                .foregroundStyle(Theme.Color.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Tap-to-hear pronunciation, with the written respelling
                        // beside it when one exists.
                        HStack(spacing: 6) {
                            Button { Pronouncer.shared.speak(concept.name) } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.Color.accentInk)

                            if let pronunciation = concept.pronunciation {
                                Text(pronunciation)
                                    .font(Theme.Font.body(12.5))
                                    .italic()
                                    .foregroundStyle(Theme.Color.sub)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                if !concept.tags.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(concept.tags, id: \.self) { tag in
                            Text(tag)
                                .font(Theme.Font.heading(12))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Theme.Color.tagBackground)
                                .foregroundStyle(Theme.Color.sub)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                Text(concept.shortExplanation)
                    .font(Theme.Font.body(15.5))
                    .foregroundStyle(Theme.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if concept.type == .assessmentTool, let assessment = concept.assessment {
                    // Structured tools get the Learn/Score experience; tools
                    // without scoring data fall through to the text sections.
                    AssessmentToolBody(scoring: assessment)
                } else {
                    ForEach(typeSpecificSections(for: concept), id: \.label) { section in
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
                }

                if !concept.relatedConceptIds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Related concepts")
                        FlowLayout(spacing: 8) {
                            ForEach(concept.relatedConceptIds, id: \.self) { relatedId in
                                NavigationLink(destination: ConceptDetailView(conceptId: relatedId)) {
                                    RelatedConceptChip(id: relatedId)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        // Hidden nav bar: the in-content header carries the back button + title
        // in line, so there's no separate nav-bar row taking vertical space.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
    private func typeSpecificSections(for concept: Concept) -> [DetailSection] {
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
            if let v = s.purpose { sections.append(.init(label: "Role in the body", content: v, isHighlighted: true)) }
            if let v = s.careConsiderations { sections.append(.init(label: "Clinical relevance", content: v, isHighlighted: true)) }
        case .assessmentTool:
            if let v = s.purpose { sections.append(.init(label: "What it measures", content: v, isHighlighted: true)) }
            if let v = s.steps { sections.append(.init(label: "How it's scored", content: v, isHighlighted: true)) }
            if let v = s.abnormalMeaning { sections.append(.init(label: "Interpreting the score", content: v, isHighlighted: true)) }
        }
        return sections
    }
}

/// A related-concept chip only has an id up front — it shows a placeholder
/// label until its own lightweight lookup resolves, rather than requiring
/// the parent to have preloaded every related concept's name.
private struct RelatedConceptChip: View {
    @EnvironmentObject private var appState: AppState
    let id: UUID
    @State private var name: String?

    var body: some View {
        Text(name ?? "...")
            .font(Theme.Font.body(13.5, weight: .bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.Color.card)
            .foregroundStyle(Theme.Color.accentInk)
            .overlay(Capsule().stroke(Theme.Color.line, lineWidth: 1.5))
            .clipShape(Capsule())
            .task {
                if let concept = try? await appState.fetchConcept(id: id) {
                    name = concept.name
                }
            }
    }
}

#Preview {
    NavigationStack {
        ConceptDetailView(conceptId: ConceptLibrary.shared.concepts.first?.id ?? UUID())
    }
    .environmentObject(AppState())
}
