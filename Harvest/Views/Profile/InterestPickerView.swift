import SwiftUI

struct InterestPickerView: View {
    @Binding var selectedInterests: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var draftInterests: [String] = []

    private static let categorizedInterests: [(String, [String])] = [
        ("Sports & Fitness", [
            "Running", "Yoga", "Hiking", "Gym", "Swimming", "Basketball", "Soccer",
            "Tennis", "Cycling", "Rock Climbing", "Martial Arts", "Surfing",
            "Skiing", "Snowboarding", "Golf", "Volleyball", "Pilates", "CrossFit",
            "Skateboarding", "Boxing"
        ]),
        ("Music & Arts", [
            "Live Music", "Playing Guitar", "Singing", "DJing", "Piano",
            "Painting", "Drawing", "Photography", "Pottery", "Graphic Design",
            "Film Making", "Dance", "Theater", "Poetry", "Creative Writing"
        ]),
        ("Food & Drink", [
            "Cooking", "Baking", "Coffee", "Wine Tasting", "Craft Beer",
            "Foodie", "BBQ & Grilling", "Sushi", "Brunch", "Cocktails",
            "Vegan Cooking", "Food Trucks"
        ]),
        ("Travel & Outdoors", [
            "Traveling", "Camping", "Road Trips", "Beach", "Backpacking",
            "Fishing", "Gardening", "Bird Watching", "Kayaking", "Sailing",
            "National Parks", "Stargazing"
        ]),
        ("Entertainment", [
            "Movies", "TV Shows", "Anime", "Gaming", "Board Games",
            "Concerts", "Podcasts", "Stand-Up Comedy", "Trivia", "Karaoke",
            "Reading", "Book Club", "True Crime"
        ]),
        ("Tech & Learning", [
            "Technology", "Coding", "AI & Machine Learning", "Investing",
            "Entrepreneurship", "Science", "History", "Languages", "Philosophy"
        ]),
        ("Lifestyle", [
            "Meditation", "Thrifting", "Fashion", "Interior Design", "Volunteering",
            "Dogs", "Cats", "Astrology", "Tattoos", "Journaling",
            "Skincare", "Wellness", "Festivals", "Brunch", "Night Life"
        ]),
        ("Social", [
            "Dinner Parties", "Game Nights", "Wine Nights", "Sports Watching",
            "Networking", "Community Service", "Mentoring"
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.lg) {
                Text("Pick your interests (\(draftInterests.count) selected)")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(Self.categorizedInterests, id: \.0) { category, interests in
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                        Text(category)
                            .font(HarvestTheme.Typography.h4)
                            .foregroundStyle(.primary)
                            .padding(.horizontal)

                        FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                            ForEach(interests, id: \.self) { interest in
                                ChipView(
                                    title: interest,
                                    isSelected: draftInterests.contains(interest),
                                    lightStyle: true
                                ) {
                                    toggleInterest(interest)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Interests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    selectedInterests = draftInterests
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            }
        }
        .onAppear {
            draftInterests = selectedInterests
        }
    }

    private func toggleInterest(_ interest: String) {
        if let index = draftInterests.firstIndex(of: interest) {
            draftInterests.remove(at: index)
        } else {
            draftInterests.append(interest)
        }
    }
}
