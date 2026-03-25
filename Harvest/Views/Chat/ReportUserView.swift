import SwiftUI

struct ReportUserView: View {
    let reporterId: String
    let reportedUserId: String
    let onSubmit: (String, String) -> Void

    @State private var selectedCategory = "General"
    @State private var description = ""
    @Environment(\.dismiss) private var dismiss

    private let categories = ["General", "Harassment", "Spam", "Safety", "Catfishing"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Report Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                }

                Section {
                    GlassButton(title: "Submit Report", icon: "exclamationmark.triangle", style: .destructive) {
                        onSubmit(selectedCategory, description)
                        dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
