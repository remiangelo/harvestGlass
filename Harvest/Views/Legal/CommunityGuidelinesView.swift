import SwiftUI

struct CommunityGuidelinesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                Text("Community Guidelines")
                    .font(HarvestTheme.Typography.h2)
                    .padding(.bottom, HarvestTheme.Spacing.sm)

                section(title: "Be Respectful", body: """
                Treat everyone with kindness and respect. Harvest is a community where people are \
                looking for genuine connections. Harassment, hate speech, discrimination, and bullying \
                are not tolerated. Remember that there is a real person behind every profile.
                """)

                section(title: "Be Authentic", body: """
                Use recent photos that accurately represent you. Provide truthful information in your \
                profile. Do not impersonate others or create fake profiles. Authenticity builds trust \
                and leads to better connections.
                """)

                section(title: "Keep It Safe", body: """
                Never share personal financial information with matches. Be cautious about sharing your \
                home address, workplace, or daily routine with people you have just met. Report any \
                suspicious behavior immediately. When meeting in person, choose a public place and \
                let someone know your plans.
                """)

                section(title: "No Harmful Content", body: """
                Do not post content that is violent, sexually explicit, or promotes illegal activities. \
                Do not share others' private information without consent. Do not send unsolicited \
                explicit messages. Our Mindful Messaging system helps maintain a respectful environment.
                """)

                section(title: "No Commercial Activity", body: """
                Harvest is for personal connections, not business. Do not use the platform to sell \
                products, promote services, recruit, or solicit. Do not share links to external \
                websites for commercial purposes.
                """)

                section(title: "Reporting", body: """
                If you encounter behavior that violates these guidelines, please report it immediately \
                using the report feature in the chat menu. Our safety team reviews all reports and \
                takes appropriate action, which may include warnings, temporary suspensions, or \
                permanent bans.
                """)

                section(title: "Consequences", body: """
                Violations of these guidelines may result in content removal, account warnings, \
                temporary suspensions, or permanent account termination. Severe or repeated violations \
                will be escalated and may be reported to law enforcement when appropriate.
                """)

                Text("Last updated: March 2026")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    .padding(.top, HarvestTheme.Spacing.md)
            }
            .padding()
        }
        .navigationTitle("Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text(title)
                .font(HarvestTheme.Typography.h3)

            Text(body)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
    }
}
