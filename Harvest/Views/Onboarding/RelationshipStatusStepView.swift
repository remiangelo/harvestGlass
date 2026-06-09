import SwiftUI

struct RelationshipStatusStepView: View {
    let viewModel: OnboardingViewModel

    private let options: [(value: String, label: String)] = [
        ("single", "Single"),
        ("dating", "Dating / exploring connections"),
        ("in_relationship", "In a relationship"),
        ("engaged", "Engaged"),
        ("married", "Married")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What is your current relationship status?")
                .font(.title2.bold())

            Text("Harvest communities are built around trust and intentional connection. Please select your current relationship status honestly so you enter the spaces designed for your current season.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(options, id: \.value) { option in
                    Button {
                        viewModel.relationshipStatus = option.value
                    } label: {
                        HStack {
                            Text(option.label)
                            Spacer()
                            if viewModel.relationshipStatus == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.relationshipStatus == option.value
                                        ? HarvestTheme.Colors.primary : Color.gray.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding()
    }
}
