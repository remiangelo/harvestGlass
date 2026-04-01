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
                        let isSelected = viewModel.resolvedLocation == suggestion
                        Button {
                            viewModel.selectLocationSuggestion(suggestion)
                            validationTask?.cancel()
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.white)
                                }
                            }
                            .padding(.horizontal, HarvestTheme.Spacing.md)
                            .padding(.vertical, HarvestTheme.Spacing.sm)
                            .background(isSelected ? HarvestTheme.Colors.redSurface : Color(.secondarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                    .stroke(isSelected ? HarvestTheme.Colors.redSurface : Color(.separator), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.xl)
            } else if let resolved = viewModel.resolvedLocation {
                Button {
                    viewModel.selectLocationSuggestion(resolved)
                    validationTask?.cancel()
                } label: {
                    HStack {
                        Text(resolved)
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(Color.white)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.md)
                    .padding(.vertical, HarvestTheme.Spacing.sm)
                    .background(HarvestTheme.Colors.redSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                            .stroke(HarvestTheme.Colors.redSurface, lineWidth: 1)
                        }
                    .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .onChange(of: viewModel.location) {
            if viewModel.location == viewModel.resolvedLocation {
                return
            }
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
