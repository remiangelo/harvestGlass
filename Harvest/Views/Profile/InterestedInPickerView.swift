import SwiftUI

struct InterestedInPickerView: View {
    @Binding var selectedOptions: [String]

    private let options: [(label: String, value: String)] = [
        ("Men", "men"),
        ("Women", "women"),
        ("Non-binary", "non-binary"),
        ("Everyone", "everyone")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                Text("Choose who you want to match with")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                    ForEach(options, id: \.value) { option in
                        ChipView(
                            title: option.label,
                            isSelected: selectedOptions.contains(option.value),
                            lightStyle: true
                        ) {
                            toggleOption(option.value)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Interested In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleOption(_ value: String) {
        if value == "everyone" {
            if selectedOptions.contains("everyone") {
                selectedOptions.removeAll()
            } else {
                selectedOptions = ["everyone"]
            }
            return
        }

        selectedOptions.removeAll { $0 == "everyone" }

        if let index = selectedOptions.firstIndex(of: value) {
            selectedOptions.remove(at: index)
        } else {
            selectedOptions.append(value)
        }
    }
}
