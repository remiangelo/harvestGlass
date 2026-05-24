import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(HarvestTheme.Typography.caption)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(HarvestTheme.Colors.textSecondary)
            .padding(.leading, HarvestTheme.Spacing.xs)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
        SectionHeader(title: "Notifications")
        SectionHeader(title: "Privacy")
        SectionHeader(title: "Account")
    }
    .padding()
    .background(HarvestTheme.Colors.formBackground)
}
