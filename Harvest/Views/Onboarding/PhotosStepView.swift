import SwiftUI

struct PhotosStepView: View {
    let viewModel: OnboardingViewModel
    let userId: String

    var body: some View {
        VStack(spacing: HarvestTheme.Spacing.xl) {
            Spacer(minLength: HarvestTheme.Spacing.lg)

            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundStyle(HarvestTheme.Colors.primary)

            Text("Add your photos")
                .font(HarvestTheme.Typography.h2)

            Text("Add at least 1 photo (up to 6)")
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textOnWhiteSecondary)

            ProfilePhotoGrid(
                photoUrls: viewModel.photoUrls,
                maxPhotos: 6,
                onAdd: { data in
                    Task {
                        await viewModel.uploadPhoto(userId: userId, imageData: data)
                    }
                },
                onRemove: { index in
                    viewModel.removePhoto(userId: userId, at: index)
                }
            )
            .padding(.horizontal, HarvestTheme.Spacing.lg)

            if viewModel.isLoading {
                ProgressView("Uploading...")
                    .tint(HarvestTheme.Colors.primary)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.error)
            }

            Spacer(minLength: HarvestTheme.Spacing.lg)
        }
    }
}
