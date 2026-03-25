import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                Text("Terms of Service")
                    .font(HarvestTheme.Typography.h2)
                    .padding(.bottom, HarvestTheme.Spacing.sm)

                section(title: "Acceptance of Terms", body: """
                By creating an account or using Harvest, you agree to be bound by these Terms of Service. \
                If you do not agree to these terms, do not use our services. We may update these terms \
                from time to time, and continued use of the app constitutes acceptance of any changes.
                """)

                section(title: "Eligibility", body: """
                You must be at least 18 years old to use Harvest. By using our services, you represent \
                and warrant that you are at least 18 years of age and have the legal capacity to enter \
                into these terms. We reserve the right to verify your age and terminate accounts that \
                do not meet this requirement.
                """)

                section(title: "Your Account", body: """
                You are responsible for maintaining the confidentiality of your account credentials and \
                for all activities that occur under your account. You agree to provide accurate and \
                complete information when creating your profile and to update it as needed. You may not \
                create multiple accounts or transfer your account to another person.
                """)

                section(title: "User Conduct", body: """
                You agree to use Harvest in a respectful and lawful manner. You may not harass, \
                threaten, or intimidate other users. You may not post content that is illegal, offensive, \
                or violates the rights of others. You may not use the app for commercial purposes, \
                solicitation, or spam. Violation of these rules may result in account suspension or termination.
                """)

                section(title: "Content", body: """
                You retain ownership of the content you post on Harvest. By posting content, you grant \
                us a non-exclusive, worldwide license to use, display, and distribute your content in \
                connection with our services. You are solely responsible for the content you post and \
                must ensure it does not violate any laws or third-party rights.
                """)

                section(title: "Subscriptions and Payments", body: """
                Harvest offers free and paid subscription tiers. Paid subscriptions are billed through \
                the Apple App Store. Subscriptions automatically renew unless cancelled at least 24 hours \
                before the end of the current period. Refunds are handled according to Apple's refund policies.
                """)

                section(title: "Limitation of Liability", body: """
                Harvest is provided "as is" without warranties of any kind. We are not liable for any \
                damages arising from your use of the app, including but not limited to interactions with \
                other users. We strongly encourage users to exercise caution when meeting people in person \
                and to report any concerning behavior.
                """)

                section(title: "Termination", body: """
                We reserve the right to suspend or terminate your account at any time for violation of \
                these terms or for any other reason at our discretion. You may delete your account at \
                any time through the app settings.
                """)

                Text("Last updated: March 2026")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    .padding(.top, HarvestTheme.Spacing.md)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
