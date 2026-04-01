import SwiftUI

struct LocationStepView: View {
    let viewModel: OnboardingViewModel

    @State private var validationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("Where are you located?")
                .font(HarvestTheme.Typography.h2)

            Text("Enter your city name")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(.secondary)

            TextField("City name", text: Bindable(viewModel).location)
                .font(HarvestTheme.Typography.bodyLarge)
                .foregroundStyle(.primary)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(Color(.separator), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
                .padding(.horizontal, HarvestTheme.Spacing.xl)

            if viewModel.isValidatingLocation {
                ProgressView()
                    .tint(HarvestTheme.Colors.primary)
            } else if !viewModel.locationSuggestions.isEmpty {
                VStack(spacing: HarvestTheme.Spacing.xs) {
                    ForEach(viewModel.locationSuggestions, id: \.self) { suggestion in
                        Button {
                            viewModel.selectLocationSuggestion(suggestion)
                            validationTask?.cancel()
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, HarvestTheme.Spacing.md)
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                            .background(Color(.secondarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                    .stroke(Color(.separator), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
                        }
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.xl)
            } else if let resolved = viewModel.resolvedLocation {
                Button {
                    viewModel.selectLocationSuggestion(resolved)
                    validationTask?.cancel()
                } label: {
                    Text(resolved)
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, HarvestTheme.Spacing.md)
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                        .background(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                .stroke(Color(.separator), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
                }
            }

            Spacer()
        }
        .onChange(of: viewModel.location) {
            viewModel.resolvedLocation = nil
            viewModel.locationSuggestions = []
            validationTask?.cancel()
            validationTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                await viewModel.validateLocation()
            }
        }
    }
}
