package com.harvestglass.harvest.ui.settings

/**
 * The three legal documents, extracted verbatim from
 * the Swift views under Harvest/Views/Legal.
 *
 * Compliance copy: change it here only when it changes there.
 */
sealed class LegalDocument(val title: String, val sections: List<Pair<String, String>>) {

    data object PrivacyPolicy : LegalDocument(
        title = "Privacy Policy",
        sections = listOf(
            "Information We Collect" to
                "We collect information you provide directly to us, including your name, email address, date of birth, gender, photos, location data, and profile information you choose to share. We also collect usage data, device information, and analytics to improve our service.",
            "How We Use Your Information" to
                "We use the information we collect to provide, maintain, and improve our services, including matching you with other users, personalizing your experience, and communicating with you about your account and our services. We also use your information for safety and security purposes, including monitoring for harmful content and enforcing our community guidelines.",
            "Information Sharing" to
                "We share your profile information with other users as part of the matching experience. We do not sell your personal information to third parties. We may share information with service providers who assist us in operating our platform, with law enforcement when required by law, or to protect the safety of our users.",
            "Data Retention" to
                "We retain your information for as long as your account is active or as needed to provide you services. You can request deletion of your account and associated data at any time through the app settings or by contacting our support team.",
            "Your Rights" to
                "You have the right to access, correct, or delete your personal information. You can update your profile information directly in the app. To request data export or deletion, please contact our support team. We will respond to verified requests within 30 days.",
            "Security" to
                "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is completely secure.",
            "Contact Us" to
                "If you have questions about this Privacy Policy, please contact us through the Help Center in the app or email us at support@dateharvest.com.",
        )
    )

    data object Terms : LegalDocument(
        title = "Terms of Service",
        sections = listOf(
            "Acceptance of Terms" to
                "By creating an account or using Harvest, you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use our services. We may update these terms from time to time, and continued use of the app constitutes acceptance of any changes.",
            "Eligibility" to
                "You must be at least 18 years old to use Harvest. By using our services, you represent and warrant that you are at least 18 years of age and have the legal capacity to enter into these terms. We reserve the right to verify your age and terminate accounts that do not meet this requirement.",
            "Your Account" to
                "You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to provide accurate and complete information when creating your profile and to update it as needed. You may not create multiple accounts or transfer your account to another person.",
            "User Conduct" to
                "You agree to use Harvest in a respectful and lawful manner. You may not harass, threaten, or intimidate other users. You may not post content that is illegal, offensive, or violates the rights of others. You may not use the app for commercial purposes, solicitation, or spam. Violation of these rules may result in account suspension or termination.",
            "Content" to
                "You retain ownership of the content you post on Harvest. By posting content, you grant us a non-exclusive, worldwide license to use, display, and distribute your content in connection with our services. You are solely responsible for the content you post and must ensure it does not violate any laws or third-party rights.",
            "Subscriptions and Payments" to
                "Harvest offers free and paid subscription tiers. Paid subscriptions are billed through the Apple App Store. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Refunds are handled according to Apple's refund policies.",
            "Limitation of Liability" to
                "Harvest is provided \"as is\" without warranties of any kind. We are not liable for any damages arising from your use of the app, including but not limited to interactions with other users. We strongly encourage users to exercise caution when meeting people in person and to report any concerning behavior.",
            "Termination" to
                "We reserve the right to suspend or terminate your account at any time for violation of these terms or for any other reason at our discretion. You may delete your account at any time through the app settings.",
        )
    )

    data object Guidelines : LegalDocument(
        title = "Community Guidelines",
        sections = listOf(
            "Be Respectful" to
                "Treat everyone with kindness and respect. Harvest is a community where people are looking for genuine connections. Harassment, hate speech, discrimination, and bullying are not tolerated. Remember that there is a real person behind every profile.",
            "Be Authentic" to
                "Use recent photos that accurately represent you. Provide truthful information in your profile. Do not impersonate others or create fake profiles. Authenticity builds trust and leads to better connections.",
            "Keep It Safe" to
                "Never share personal financial information with matches. Be cautious about sharing your home address, workplace, or daily routine with people you have just met. Report any suspicious behavior immediately. When meeting in person, choose a public place and let someone know your plans.",
            "No Harmful Content" to
                "Do not post content that is violent, sexually explicit, or promotes illegal activities. Do not share others' private information without consent. Do not send unsolicited explicit messages. Our Mindful Messaging system helps maintain a respectful environment.",
            "No Commercial Activity" to
                "Harvest is for personal connections, not business. Do not use the platform to sell products, promote services, recruit, or solicit. Do not share links to external websites for commercial purposes.",
            "Reporting & Blocking" to
                "If you encounter behavior that violates these guidelines, please report or block the user immediately using the ••• menu on their profile or in a chat. Blocking instantly removes the person from your feed and notifies our safety team. We review all reports within 24 hours and take appropriate action, which may include content removal, warnings, temporary suspensions, or permanent bans.",
            "Consequences" to
                "Violations of these guidelines may result in content removal, account warnings, temporary suspensions, or permanent account termination. Severe or repeated violations will be escalated and may be reported to law enforcement when appropriate.",
        )
    )
}
