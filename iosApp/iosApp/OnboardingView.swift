import SwiftUI

/// Multi-page onboarding: a welcome/logo page followed by one question per
/// page (name, experience, specialties), each with its own Continue action.
/// Replaces the earlier single-page specialty+experience form.
private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case name
    case experience
    case specialties
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step: OnboardingStep = .welcome
    @State private var name = ""
    @State private var selectedExperience: ExperienceLevel?
    @State private var selectedSpecialties: Set<Specialty> = []
    @State private var specialtyQuery = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var specialtySearchFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var filteredSpecialties: [Specialty] {
        let query = specialtyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Specialty.allCases }
        return Specialty.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                progressHeader
            }

            switch step {
            case .welcome: welcomePage
            case .name: namePage
            case .experience: experiencePage
            case .specialties: specialtiesPage
            }
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Chrome

    private var progressHeader: some View {
        HStack {
            Button { back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.card)
                    .overlay(Circle().stroke(Theme.Color.line, lineWidth: 1.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases.dropFirst(), id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.Color.accent : Theme.Color.line)
                        .frame(width: s == step ? 22 : 8, height: 8)
                }
            }

            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func back() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    private func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    // MARK: - Page 1: Welcome / logo

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Color.accentSoftBackground)
                    .frame(width: 112, height: 112)
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
            }

            VStack(spacing: 8) {
                Text("Nursify")
                    .font(Theme.Font.heading(40))
                    .foregroundStyle(Theme.Color.ink)
                Text("A quick reference built for the bedside.")
                    .font(Theme.Font.body(15.5))
                    .foregroundStyle(Theme.Color.sub)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()

            PrimaryButton(title: "Get Started") { advance() }
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Page 2: Name

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What's your name?")
                    .font(Theme.Font.heading(28))
                Text("We'll use this to personalize the app.")
                    .font(Theme.Font.body(15))
                    .foregroundStyle(Theme.Color.sub)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            TextField("Your name", text: $name)
                .font(Theme.Font.body(17, weight: .semibold))
                .padding(16)
                .background(Theme.Color.card)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .focused($nameFieldFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit(continueFromName)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            PrimaryButton(title: "Continue", action: continueFromName)
                .padding(24)
                .opacity(trimmedName.isEmpty ? 0.4 : 1)
                .disabled(trimmedName.isEmpty)
        }
        .onAppear { nameFieldFocused = true }
    }

    private func continueFromName() {
        guard !trimmedName.isEmpty else { return }
        nameFieldFocused = false
        advance()
    }

    // MARK: - Page 3: Years of experience

    private var experiencePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How many years of experience do you have?")
                    .font(Theme.Font.heading(26))
                Text("This helps us tune how much detail to show in explanations.")
                    .font(Theme.Font.body(15))
                    .foregroundStyle(Theme.Color.sub)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(ExperienceLevel.allCases) { level in
                        SelectableChip(text: level.rawValue, isSelected: selectedExperience == level)
                            .onTapGesture { selectedExperience = level }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }

            PrimaryButton(title: "Continue") { advance() }
                .padding(24)
                .opacity(selectedExperience == nil ? 0.4 : 1)
                .disabled(selectedExperience == nil)
        }
    }

    // MARK: - Page 4: Specialties

    private var specialtiesPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's your specialty?")
                        .font(Theme.Font.heading(28))
                    Text("Select all that apply — you can change this anytime in Settings. This just helps us prioritize suggestions, nothing is locked in or hidden.")
                        .font(Theme.Font.body(15))
                        .foregroundStyle(Theme.Color.sub)
                        .padding(.bottom, 8)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.sub)
                        TextField("Search specialties...", text: $specialtyQuery)
                            .font(Theme.Font.body(15, weight: .semibold))
                            .focused($specialtySearchFocused)
                            .autocorrectionDisabled()
                        if !specialtyQuery.isEmpty {
                            Button {
                                specialtyQuery = ""
                                specialtySearchFocused = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Color.sub)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(13)
                    .background(SwiftUI.Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.bottom, 4)

                    if filteredSpecialties.isEmpty {
                        Text("No specialties match \u{201C}\(specialtyQuery)\u{201D}.")
                            .font(Theme.Font.body(13.5))
                            .foregroundStyle(Theme.Color.sub)
                            .padding(.vertical, 8)
                    } else {
                        FlowLayout(spacing: 10) {
                            ForEach(filteredSpecialties) { specialty in
                                SelectableChip(text: specialty.rawValue, isSelected: selectedSpecialties.contains(specialty))
                                    .onTapGesture { toggle(specialty) }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
            }

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                    Text("Used only to personalize your suggestions and explanation depth — never shared, and nothing is hidden based on your picks.")
                        .font(Theme.Font.body(13.5))
                }
                .foregroundStyle(Theme.Color.accentInk)
                .padding(14)
                .background(Theme.Color.accentSoftBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                PrimaryButton(title: "Continue") {
                    appState.completeOnboarding(
                        name: trimmedName,
                        specialties: selectedSpecialties,
                        experience: selectedExperience
                    )
                }

                Text("\(selectedSpecialties.count) specialties · \(selectedExperience?.rawValue ?? "not set")")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.Color.sub)
            }
            .padding(24)
        }
    }

    private func toggle(_ specialty: Specialty) {
        if selectedSpecialties.contains(specialty) {
            selectedSpecialties.remove(specialty)
        } else {
            selectedSpecialties.insert(specialty)
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
