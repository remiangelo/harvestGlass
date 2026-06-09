import SwiftUI

enum ReportTarget {
    case profile
    case communityMessage(id: String)
    case seedMessage(id: String)

    var typeString: String {
        switch self {
        case .profile: return "profile"
        case .communityMessage: return "community_message"
        case .seedMessage: return "seed_message"
        }
    }
    var targetId: String? {
        switch self {
        case .profile: return nil
        case .communityMessage(let id), .seedMessage(let id): return id
        }
    }
}

struct ReportUserView: View {
    let reporterId: String
    let reportedUserId: String
    var target: ReportTarget = .profile
    let onSubmit: (String, String, ReportTarget) -> Void

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
                        onSubmit(selectedCategory, description, target)
                        dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
