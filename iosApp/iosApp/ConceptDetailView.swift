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
            await appState.recordSearchHistory(conceptId: conceptId)
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func content(for concept: Concept) -> some View {
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
        .navigationTitle(concept.name)
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
            break
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
            .background(SwiftUI.Color.white)
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
        ConceptDetailView(conceptId: MockData.concepts[0].id)
    }
    .environmentObject(AppState())
}
