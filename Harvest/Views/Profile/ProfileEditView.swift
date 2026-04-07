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

    var body: some View {
        Form {
            // Photos
            Section("Photos") {
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
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            // Basic Info
            Section("Basic Info") {
                HStack {
                    Text("Nickname")
                    Spacer()
                    TextField("Nickname", text: $viewModel.editNickname)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Age")
                    Spacer()
                    Stepper("\(viewModel.editAge)", value: $viewModel.editAge, in: 18...100)
                }

                HStack {
                    Text("Location")
                    Spacer()
                    TextField("City", text: $viewModel.editLocation)
                        .multilineTextAlignment(.trailing)
                }
            }

            // Bio
            Section("About Me") {
                TextEditor(text: $viewModel.editBio)
                    .frame(minHeight: 100)
            }

            // Hobbies
            Section("Interests") {
                NavigationLink("Edit Interests (\(viewModel.editHobbies.count) selected)") {
                    InterestPickerView(selectedInterests: $viewModel.editHobbies)
                }
            }

            // Values
            Section("Values") {
                NavigationLink("Edit My Values") {
                    ValuesQuestionnaireView(authViewModel: authViewModel)
                }
            }

            Section("Lifestyle & Intentions") {
                Picker("Looking For", selection: $viewModel.editLookingFor) {
                    Text("Select").tag("")
                    ForEach(lookingForOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Stepper("Height \(HeightFormatter.string(from: viewModel.editHeightCm))", value: $viewModel.editHeightCm, in: 100...250)

                Picker("Smoking", selection: $viewModel.editSmoking) {
                    Text("Select").tag("")
                    ForEach(smokingOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Picker("Drinking", selection: $viewModel.editDrinking) {
                    Text("Select").tag("")
                    ForEach(drinkingOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Picker("Cannabis", selection: $viewModel.editCannabis) {
                    Text("Select").tag("")
                    ForEach(cannabisOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Picker("Spiritual Orientation", selection: $viewModel.editSpiritualOrientation) {
                    Text("Select").tag("")
                    ForEach(spiritualOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Picker("Children", selection: $viewModel.editChildrenStatus) {
                    Text("Select").tag("")
                    ForEach(childrenOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
        .listRowBackground(HarvestTheme.Colors.formSurface)
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
                .foregroundStyle(.primary)
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
}

