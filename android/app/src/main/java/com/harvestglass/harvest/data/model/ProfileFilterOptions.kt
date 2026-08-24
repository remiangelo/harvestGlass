package com.harvestglass.harvest.data.model

/**
 * The option vocabulary shared by anything that filters people by profile
 * attributes — Discover's filters and the room member roster. Kept in one
 * place so the two can't drift apart and stop matching stored values.
 *
 * Mirrors Harvest/Models/ProfileFilterOptions.swift.
 */
object ProfileFilterOptions {

    /** label to stored value. */
    val gender = listOf(
        "Male" to "male",
        "Female" to "female",
        "Non-binary" to "non-binary",
        "Everyone" to "everyone"
    )

    /**
     * Identities only. [gender] above carries "Everyone", which is a
     * *preference* term for "show me" and matches no actual profile.
     */
    val genderIdentity = listOf("Male", "Female", "Non-binary")

    val lookingFor = listOf("Dating", "Relationship", "Long-term Commitment", "Marriage")
    val smoking = listOf("Never", "Sometimes", "Often", "Prefer not to say")
    val drinking = listOf("Never", "Socially", "Often", "Prefer not to say")
    val cannabis = listOf("Never", "Sometimes", "Often", "Prefer not to say")
    val faith = listOf(
        "Christianity", "Islam", "Judaism", "Buddhism", "Hinduism",
        "Spiritual", "Agnostic", "Atheist", "Other"
    )
    val children = listOf(
        "Want someday", "Don't want", "Have & want more",
        "Have & don't want more", "Not sure", "Prefer not to say"
    )

    /** Shown as the "no preference" entry at the top of every picker. */
    /**
     * Label to stored value. The column holds the snake_case value, so the
     * pairs cannot be flattened to a plain list.
     */
    val relationshipStatus = listOf(
        "Single" to "single",
        "Dating / exploring" to "dating",
        "In a relationship" to "in_relationship",
        "Engaged" to "engaged",
        "Married" to "married"
    )

    const val ANY = "Any"
}
