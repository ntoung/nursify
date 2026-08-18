import SwiftUI
import UIKit

/// The "Report a problem" drawer opened by shaking the phone (see `.onShake`
/// in ContentView). A short description + Submit that posts to the backend
/// (`POST /reports`). Device/app context is attached automatically so a report
/// is actionable without asking the nurse for version numbers.
struct ReportProblemView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    @State private var message = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorText: String?

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Group {
                if didSubmit {
                    successState
                } else {
                    formState
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("Report a problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Color.sub)
                }
            }
        }
        // Half-height only — this is a quick report, not a full-screen form.
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var formState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Found a bug or something confusing? Tell us what happened and we'll take a look.")
                .font(Theme.Font.body(14.5))
                .foregroundStyle(Theme.Color.sub)

            TextField("Describe the problem…", text: $message, axis: .vertical)
                .font(Theme.Font.body(15))
                .lineLimit(4...10)
                .focused($fieldFocused)
                .padding(13)
                .background(SwiftUI.Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Color.line, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if let errorText {
                Text(errorText)
                    .font(Theme.Font.body(13, weight: .semibold))
                    .foregroundStyle(Theme.Color.warnInk)
            }

            Spacer()

            PrimaryButton(title: isSubmitting ? "Submitting…" : "Submit") {
                Task { await submit() }
            }
            .opacity(trimmed.isEmpty || isSubmitting ? 0.5 : 1)
            .disabled(trimmed.isEmpty || isSubmitting)
        }
        .padding(24)
        .onAppear { fieldFocused = true }
    }

    private var successState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Color.accent)
            Text("Thanks for the report")
                .font(Theme.Font.heading(18))
                .foregroundStyle(Theme.Color.ink)
            Text("We got it and we'll look into it.")
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.Color.sub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func submit() async {
        errorText = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await APIClient.shared.submitReport(message: trimmed, context: Self.deviceContext)
            didSubmit = true
            // Auto-dismiss shortly after showing the confirmation.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            errorText = "Couldn't send that report. Check your connection and try again."
        }
    }

    /// App + device info attached to the report so it's actionable.
    private static var deviceContext: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current.model
        let os = UIDevice.current.systemVersion
        return "Nursify \(version) (\(build)) · \(device) · iOS \(os)"
    }
}

#Preview {
    ReportProblemView()
}
