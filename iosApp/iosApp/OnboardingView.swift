import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSpecialties: Set<Specialty> = [.telemetry, .medSurg]
    @State private var selectedExperience: ExperienceLevel? = .fourToSeven

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's your specialty?")
                        .font(Theme.Font.heading(28))
                    Text("Select all that apply — you can change this anytime in Settings. This just helps us prioritize suggestions, nothing is locked in or hidden.")
                        .font(Theme.Font.body(15))
                        .foregroundStyle(Theme.Color.sub)
                        .padding(.bottom, 8)

                    FlowLayout(spacing: 10) {
                        ForEach(Specialty.allCases) { specialty in
                            SelectableChip(text: specialty.rawValue, isSelected: selectedSpecialties.contains(specialty))
                                .onTapGesture { toggle(specialty) }
                        }
                    }

                    SectionLabel(text: "Years of experience")
                        .padding(.top, 22)
                        .padding(.bottom, 6)

                    FlowLayout(spacing: 10) {
                        ForEach(ExperienceLevel.allCases) { level in
                            SelectableChip(text: level.rawValue, isSelected: selectedExperience == level)
                                .onTapGesture { selectedExperience = level }
                        }
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
                    appState.completeOnboarding(specialties: selectedSpecialties, experience: selectedExperience)
                }

                Text("\(selectedSpecialties.count) specialties · \(selectedExperience?.rawValue ?? "not set")")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.Color.sub)
            }
            .padding(24)
        }
        .background(Theme.Color.background.ignoresSafeArea())
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
