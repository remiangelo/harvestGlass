import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                Text("Privacy Policy")
                    .font(HarvestTheme.Typography.h2)
                    .foregroundStyle(.primary)
                    .padding(.bottom, HarvestTheme.Spacing.sm)

                section(title: "Information We Collect", body: """
                We collect information you provide directly to us, including your name, email address, \
                date of birth, gender, photos, location data, and profile information you choose to share. \
                We also collect usage data, device information, and analytics to improve our service.
                """)

                section(title: "How We Use Your Information", body: """
                We use the information we collect to provide, maintain, and improve our services, \
                including matching you with other users, personalizing your experience, and communicating \
                with you about your account and our services. We also use your information for safety \
                and security purposes, including monitoring for harmful content and enforcing our community guidelines.
                """)

                section(title: "Information Sharing", body: """
                We share your profile information with other users as part of the matching experience. \
                We do not sell your personal information to third parties. We may share information with \
                service providers who assist us in operating our platform, with law enforcement when \
                required by law, or to protect the safety of our users.
                """)

                section(title: "Data Retention", body: """
                We retain your information for as long as your account is active or as needed to provide \
                you services. You can request deletion of your account and associated data at any time \
                through the app settings or by contacting our support team.
                """)

                section(title: "Your Rights", body: """
                You have the right to access, correct, or delete your personal information. You can \
                update your profile information directly in the app. To request data export or deletion, \
                please contact our support team. We will respond to verified requests within 30 days.
                """)

                section(title: "Security", body: """
                We implement appropriate technical and organizational measures to protect your personal \
                information against unauthorized access, alteration, disclosure, or destruction. However, \
                no method of transmission over the internet is completely secure.
                """)

                section(title: "Contact Us", body: """
                If you have questions about this Privacy Policy, please contact us through the Help Center \
                in the app or email us at support@dateharvest.com.
                """)

                Text("Last updated: March 2026")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, HarvestTheme.Spacing.md)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            Text(title)
                .font(HarvestTheme.Typography.h3)
                .foregroundStyle(.primary)

            Text(body)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(.secondary)
        }
    }
}
