import SwiftUI

struct ProfileEditView: View {
    let authViewModel: AuthViewModel
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Photos
            Section("Photos") {
                ProfilePhotoGrid(
                    photoUrls: viewModel.profile?.photos ?? [],
                    maxPhotos: 6,
                    onAdd: { data in
                        if let userId = authViewModel.currentUserId {
                            Task { await viewModel.uploadPhoto(userId: userId, imageData: data) }
                        }
                    },
                    onRemove: { index in
                        if let userId = authViewModel.currentUserId {
                            Task { await viewModel.deletePhoto(userId: userId, at: index) }
                        }
                    }
                )
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
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .foregroundStyle(HarvestTheme.Colors.textPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let userId = authViewModel.currentUserId {
                        Task {
                            await viewModel.saveChanges(userId: userId)
                            dismiss()
                        }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            }
        }
        .onAppear {
            viewModel.startEditing()
        }
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

