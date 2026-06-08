// Harvest/Views/Field/FieldView.swift
import SwiftUI

struct FieldView: View {
    let authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(HarvestTheme.Colors.primary)
                Text("The Field")
                    .font(.title2.bold())
                Text("Community spaces are coming here.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("The Field")
        }
    }
}
