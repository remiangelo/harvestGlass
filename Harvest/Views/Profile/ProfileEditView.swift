import SwiftUI

struct ProfileEditView: View {
    let authViewModel: AuthViewModel
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var didInitializeEditing = false

    private let lookingForOptions = [
        ("Dating", "dating"),
        ("Relationship", "relationship"),
        ("Long-term Commitment", "long_term_commitment"),
        ("Marriage", "marriage")
    ]
    private let smokingOptions = [
        ("Never", "never"),
        ("Sometimes", "sometimes"),
        ("Regularly", "regularly"),
        ("Prefer not to say", "prefer_not_to_say")
    ]
    private let drinkingOptions = [
        ("Never", "never"),
        ("Socially", "socially"),
        ("Regularly", "regularly"),
        ("Prefer not to say", "prefer_not_to_say")
    ]
    private let cannabisOptions = [
        ("Never", "never"),
        ("Sometimes", "sometimes"),
        ("Regularly", "regularly"),
        ("Prefer not to say", "prefer_not_to_say")
    ]
    private let spiritualOptions = [
        ("Spiritual, not religious", "spiritual_not_religious"),
        ("Christian", "christian"),
        ("Catholic", "catholic"),
        ("Jewish", "jewish"),
        ("Muslim", "muslim"),
        ("Hindu", "hindu"),
        ("Buddhist", "buddhist"),
        ("Atheist", "atheist"),
        ("Agnostic", "agnostic"),
        ("Other", "other"),
        ("Prefer not to say", "prefer_not_to_say")
    ]
    private let childrenOptions = [
        ("Have and want more", "have_and_want_more"),
        ("Have and don't want more", "have_and_dont_want_more"),
        ("Want kids", "want_kids"),
        ("Open to kids", "open_to_kids"),
        ("Don't want kids", "dont_want_kids"),
        ("Prefer not to say", "prefer_not_to_say")
    ]

    private var valuesBroughtCount: Int {
        viewModel.valuesBrought?.count ?? 0
    }

    private var valuesSoughtCount: Int {
        viewModel.valuesSought?.count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                sectionTitle("Photos")
                GlassCard(style: .light) {
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                        ProfilePhotoGrid(
                            photoUrls: viewModel.editPhotoUrls,
                            maxPhotos: 6,
                            onAdd: { data in
                                if let userId = authViewModel.currentUserId {
                                    Task {
                                        await viewModel.uploadPhoto(userId: userId, imageData: data)
                                    }
                                }
                            },
                            onRemove: { index in
                                viewModel.deletePhoto(at: index)
                            }
                        )

                        if let error = viewModel.error {
                            Text(error)
                                .font(HarvestTheme.Typography.bodySmall)
                                .foregroundStyle(HarvestTheme.Colors.error)
                        }
                    }
                }

                sectionTitle("Basic Info")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        textFieldRow(title: "Nickname", placeholder: "Nickname", text: $viewModel.editNickname)
                        dividerRow()
                        HStack {
                            Text("Age")
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                            Spacer()
                            StepperCapsuleRow(title: "\(viewModel.editAge)", value: $viewModel.editAge, range: 18...100)
                                .frame(maxWidth: 220)
                        }
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                        dividerRow()
                        textFieldRow(title: "Location", placeholder: "City", text: $viewModel.editLocation)
                    }
                }

                sectionTitle("About Me")
                GlassCard(style: .light) {
                    TextEditor(text: $viewModel.editBio)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                }

                sectionTitle("Lifestyle & Intentions")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        pickerRow(
                            title: "Looking For",
                            selection: $viewModel.editLookingFor,
                            options: lookingForOptions
                        )
                        dividerRow()
                        HStack {
                            Text("Height")
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                            Spacer()
                            StepperCapsuleRow(
                                title: HeightFormatter.string(from: viewModel.editHeightCm),
                                value: $viewModel.editHeightCm,
                                range: 100...250
                            )
                            .frame(maxWidth: 220)
                        }
                        .padding(.vertical, HarvestTheme.Spacing.sm)
                        dividerRow()
                        pickerRow(title: "Smoking", selection: $viewModel.editSmoking, options: smokingOptions)
                        dividerRow()
                        pickerRow(title: "Drinking", selection: $viewModel.editDrinking, options: drinkingOptions)
                        dividerRow()
                        pickerRow(title: "Cannabis", selection: $viewModel.editCannabis, options: cannabisOptions)
                        dividerRow()
                        pickerRow(title: "Spiritual Orientation", selection: $viewModel.editSpiritualOrientation, options: spiritualOptions)
                        dividerRow()
                        pickerRow(title: "Children", selection: $viewModel.editChildrenStatus, options: childrenOptions)
                    }
                }

                sectionTitle("Values")
                GlassCard(style: .light) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            ValuesQuestionnaireView(authViewModel: authViewModel, initialTab: 0)
                        } label: {
                            navRow(title: "What I Bring", subtitle: valuesBroughtCount > 0 ? "\(valuesBroughtCount) selected" : "Select up to 5")
                        }
                        .buttonStyle(.plain)

                        dividerRow()

                        NavigationLink {
                            ValuesQuestionnaireView(authViewModel: authViewModel, initialTab: 1)
                        } label: {
                            navRow(title: "What I Need", subtitle: valuesSoughtCount > 0 ? "\(valuesSoughtCount) selected" : "Select up to 5")
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionTitle("Interests")
                GlassCard(style: .light) {
                    NavigationLink {
                        InterestPickerView(selectedInterests: $viewModel.editHobbies)
                    } label: {
                        navRow(
                            title: "Edit Interests",
                            subtitle: viewModel.editHobbies.isEmpty ? "Select your interests" : "\(viewModel.editHobbies.count) selected"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let userId = authViewModel.currentUserId {
                        Task {
                            if await viewModel.saveChanges(userId: userId) {
                                dismiss()
                            }
                        }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            }
        }
        .onAppear {
            guard !didInitializeEditing else { return }
            viewModel.startEditing()
            didInitializeEditing = true
        }
        .toolbarBackground(HarvestTheme.Colors.formBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HarvestTheme.Typography.h4)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
    }

    private func dividerRow() -> some View {
        Divider().overlay(HarvestTheme.Colors.formBorder)
    }

    private func textFieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            Spacer()
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .tint(HarvestTheme.Colors.formAccent)
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
    }

    private func pickerRow(title: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            Spacer()
            Picker(title, selection: selection) {
                Text("Select").tag("")
                ForEach(options, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .labelsHidden()
            .tint(HarvestTheme.Colors.formAccent)
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
    }

    private func navRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
        .padding(.vertical, HarvestTheme.Spacing.sm)
    }
}
