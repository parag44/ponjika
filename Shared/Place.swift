import Foundation

/// A location the app shows sun times, weather and alerts for.
struct Place: Codable, Hashable, Identifiable {
    let name: String          // display name, Bangla where we have one
    let country: String       // display name
    let latitude: Double
    let longitude: Double
    let timeZoneID: String

    var id: String { String(format: "%.3f,%.3f", latitude, longitude) }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// A Gregorian calendar in the place's own time zone, for showing its local times.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static let dhaka = Place(name: "ঢাকা", country: "বাংলাদেশ", latitude: 23.7104, longitude: 90.4074, timeZoneID: "Asia/Dhaka")

    private static func bd(_ name: String, _ lat: Double, _ lon: Double) -> Place {
        Place(name: name, country: "বাংলাদেশ", latitude: lat, longitude: lon, timeZoneID: "Asia/Dhaka")
    }

    /// Division headquarters first, then other large districts.
    static let bangladesh: [Place] = [
        dhaka,
        bd("চট্টগ্রাম", 22.3569, 91.7832),
        bd("সিলেট", 24.8949, 91.8687),
        bd("রাজশাহী", 24.3745, 88.6042),
        bd("খুলনা", 22.8456, 89.5403),
        bd("বরিশাল", 22.7010, 90.3535),
        bd("রংপুর", 25.7439, 89.2752),
        bd("ময়মনসিংহ", 24.7471, 90.4203),
        bd("কুমিল্লা", 23.4607, 91.1809),
        bd("গাজীপুর", 23.9999, 90.4203),
        bd("নারায়ণগঞ্জ", 23.6238, 90.5000),
        bd("কক্সবাজার", 21.4272, 92.0058),
        bd("বগুড়া", 24.8465, 89.3773),
        bd("যশোর", 23.1664, 89.2081),
        bd("দিনাজপুর", 25.6217, 88.6355),
        bd("ফরিদপুর", 23.6071, 89.8429),
        bd("টাঙ্গাইল", 24.2513, 89.9167),
        bd("নোয়াখালী", 22.8696, 91.0995),
        bd("সুনামগঞ্জ", 25.0715, 91.3992),
        bd("রাঙ্গামাটি", 22.6533, 92.1789),
    ]

    /// Cities with large Bangladeshi communities.
    static let abroad: [Place] = [
        Place(name: "লন্ডন", country: "যুক্তরাজ্য", latitude: 51.5072, longitude: -0.1276, timeZoneID: "Europe/London"),
        Place(name: "নিউ ইয়র্ক", country: "যুক্তরাষ্ট্র", latitude: 40.7128, longitude: -74.0060, timeZoneID: "America/New_York"),
        Place(name: "টরন্টো", country: "কানাডা", latitude: 43.6532, longitude: -79.3832, timeZoneID: "America/Toronto"),
        Place(name: "দুবাই", country: "সংযুক্ত আরব আমিরাত", latitude: 25.2048, longitude: 55.2708, timeZoneID: "Asia/Dubai"),
        Place(name: "রিয়াদ", country: "সৌদি আরব", latitude: 24.7136, longitude: 46.6753, timeZoneID: "Asia/Riyadh"),
        Place(name: "দোহা", country: "কাতার", latitude: 25.2854, longitude: 51.5310, timeZoneID: "Asia/Qatar"),
        Place(name: "কুয়েত সিটি", country: "কুয়েত", latitude: 29.3759, longitude: 47.9774, timeZoneID: "Asia/Kuwait"),
        Place(name: "মাস্কাট", country: "ওমান", latitude: 23.5880, longitude: 58.3829, timeZoneID: "Asia/Muscat"),
        Place(name: "কুয়ালালামপুর", country: "মালয়েশিয়া", latitude: 3.1390, longitude: 101.6869, timeZoneID: "Asia/Kuala_Lumpur"),
        Place(name: "সিঙ্গাপুর", country: "সিঙ্গাপুর", latitude: 1.3521, longitude: 103.8198, timeZoneID: "Asia/Singapore"),
        Place(name: "কলকাতা", country: "ভারত", latitude: 22.5726, longitude: 88.3639, timeZoneID: "Asia/Kolkata"),
        Place(name: "রোম", country: "ইতালি", latitude: 41.9028, longitude: 12.4964, timeZoneID: "Europe/Rome"),
        Place(name: "প্যারিস", country: "ফ্রান্স", latitude: 48.8566, longitude: 2.3522, timeZoneID: "Europe/Paris"),
        Place(name: "সিডনি", country: "অস্ট্রেলিয়া", latitude: -33.8688, longitude: 151.2093, timeZoneID: "Australia/Sydney"),
        Place(name: "টোকিও", country: "জাপান", latitude: 35.6762, longitude: 139.6503, timeZoneID: "Asia/Tokyo"),
    ]

    /// Searches any city worldwide with Open-Meteo's free geocoding API.
    static func search(_ query: String) async throws -> [Place] {
        struct Response: Decodable {
            struct Result: Decodable {
                let name: String
                let latitude: Double
                let longitude: Double
                let timezone: String?
                let country: String?
                let admin1: String?
            }
            let results: [Result]?
        }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: "en"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.results ?? []).map { r in
            let region = [r.admin1, r.country].compactMap { $0 }.joined(separator: ", ")
            return Place(name: r.name, country: region, latitude: r.latitude, longitude: r.longitude,
                         timeZoneID: r.timezone ?? TimeZone.current.identifier)
        }
    }
}

/// Settings shared by the app and its complications through the App Group.
enum AppSettings {
    /// "group.<app bundle ID>", derived at runtime so it matches whatever
    /// bundle ID the developer configured (the extension's ID ends in ".widgets").
    static var appGroupID: String {
        var base = Bundle.main.bundleIdentifier ?? "ponjika"
        if base.hasSuffix(".widgets") { base.removeLast(".widgets".count) }
        return "group." + base
    }

    /// Shared defaults; falls back to the app's own defaults if the App Group isn't set up.
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    private static let placeKey = "settings.place"

    static var place: Place {
        get {
            guard let data = defaults.data(forKey: placeKey),
                  let place = try? JSONDecoder().decode(Place.self, from: data) else { return .dhaka }
            return place
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: placeKey) }
        }
    }
}
