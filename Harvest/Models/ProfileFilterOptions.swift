import Foundation

/// The option vocabulary shared by anything that filters people by profile
/// attributes — Discover's `FiltersView` and the room member roster. Kept in
/// one place so the two can't drift apart and stop matching stored values.
enum ProfileFilterOptions {
    static let gender: [(label: String, value: String)] = [
        ("Male", "male"),
        ("Female", "female"),
        ("Non-binary", "non-binary"),
        ("Everyone", "everyone")
    ]

    /// Identities only. `gender` above carries "Everyone", which is a
    /// *preference* term for "show me" and matches no actual profile.
    static let genderIdentity = ["Male", "Female", "Non-binary"]

    static let lookingFor = ["Dating", "Relationship", "Long-term Commitment", "Marriage"]
    static let smoking = ["Never", "Sometimes", "Often", "Prefer not to say"]
    static let drinking = ["Never", "Socially", "Often", "Prefer not to say"]
    static let cannabis = ["Never", "Sometimes", "Often", "Prefer not to say"]
    static let faith = [
        "Christianity", "Islam", "Judaism", "Buddhism", "Hinduism",
        "Spiritual", "Agnostic", "Atheist", "Other"
    ]
    static let children = [
        "Want someday", "Don't want", "Have & want more",
        "Have & don't want more", "Not sure", "Prefer not to say"
    ]
}

/// An ephemeral filter over a room's member list. Unlike `FilterPreferences`
/// this is never persisted — it exists for the length of one roster session.
struct RoomMemberFilter: Equatable {
    var search: String = ""
    var ageMin: Int = 18
    var ageMax: Int = 99
    var gender: String?

    // Grow+ (advanced)
    var lookingFor: String?
    var heightMin: Int?
    var heightMax: Int?
    var smoking: String?
    var drinking: String?
    var cannabis: String?

    // Gold (full)
    var faith: String?
    var childrenStatus: String?

    var isDefault: Bool { self == RoomMemberFilter() }

    /// Everything except the free-text search, which the roster shows separately.
    var activeAttributeCount: Int {
        var n = 0
        if ageMin != 18 || ageMax != 99 { n += 1 }
        for value in [gender, lookingFor, smoking, drinking, cannabis, faith, childrenStatus] where value != nil {
            n += 1
        }
        if heightMin != nil || heightMax != nil { n += 1 }
        return n
    }

    func matches(_ profile: UserProfile) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let haystack = [profile.displayName, profile.location ?? "", profile.bio ?? ""]
                .joined(separator: " ")
                .lowercased()
            guard haystack.contains(query) else { return false }
        }

        // An unset attribute on a profile never excludes it — rooms are for
        // meeting people, and half-filled profiles are the norm.
        if let age = profile.age, age < ageMin || age > ageMax { return false }
        if let gender, profile.gender?.lowercased() != gender.lowercased() { return false }
        if let lookingFor, profile.lookingFor != lookingFor { return false }
        if let heightMin, let h = profile.heightCm, h < heightMin { return false }
        if let heightMax, let h = profile.heightCm, h > heightMax { return false }
        if let smoking, profile.smoking != smoking { return false }
        if let drinking, profile.drinking != drinking { return false }
        if let cannabis, profile.cannabis != cannabis { return false }
        if let faith, profile.spiritualOrientation != faith { return false }
        if let childrenStatus, profile.childrenStatus != childrenStatus { return false }
        return true
    }
}
