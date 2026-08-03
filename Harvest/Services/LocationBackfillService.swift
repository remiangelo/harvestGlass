import Foundation
import MapKit
import Supabase

/// Fills in `users.latitude`/`longitude` for accounts that have a location
/// string but no coordinates.
///
/// Location-restricted rooms need real coordinates, and every existing account
/// predates the columns. Rather than a server-side geocoding key and a batch
/// job, each device resolves its own user once — the app already geocodes at
/// onboarding to validate the typed location, so this reuses that machinery.
///
/// Until a user is resolved they match no location-restricted room, which is
/// the intended strict behaviour for a missing attribute.
struct LocationBackfillService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Runs at most once per launch per user. Silent: a failure here must
    /// never interrupt sign-in, and it simply retries next launch.
    func backfillIfNeeded(for profile: UserProfile) async {
        guard profile.latitude == nil || profile.longitude == nil else { return }
        guard let location = profile.location?.trimmingCharacters(in: .whitespaces),
              !location.isEmpty else { return }
        guard let coordinate = await Self.geocode(location) else { return }

        do {
            try await client
                .from("users")
                .update([
                    "latitude": AnyJSON.double(coordinate.latitude),
                    "longitude": AnyJSON.double(coordinate.longitude)
                ])
                .eq("id", value: profile.id)
                .execute()
        } catch {
            print("Warning: location backfill failed for \(profile.id): \(error)")
        }
    }

    /// Resolves a free-text place to a coordinate, or nil if it can't be read.
    static func geocode(_ query: String) async -> CLLocationCoordinate2D? {
        guard let request = MKGeocodingRequest(addressString: query) else { return nil }
        guard let items = try? await request.mapItems, let first = items.first else { return nil }
        return first.location?.coordinate
    }
}
