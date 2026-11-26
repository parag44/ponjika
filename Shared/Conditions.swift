import SwiftUI

/// Weather, air quality and derived alerts for one place, from Open-Meteo
/// (free, no API key). Only the chosen place's coordinates are sent.
/// Shared by the app and the complications, and cached in the App Group so
/// they don't each hit the network.
struct Conditions: Codable {
    struct Hour: Codable, Identifiable {
        var id: Date { time }
        let time: Date
        let temperature: Double
        let code: Int
        let isDay: Bool
        let rainChance: Int
        let rainMM: Double
    }

    let placeID: String
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let wind: Double              // km/h
    let code: Int
    let isDay: Bool
    let high: Double
    let low: Double
    let feelsLikeHigh: Double     // today's max apparent temperature
    let rainChance: Int           // today's max, %
    let uv: Double                // today's max
    let hours: [Hour]             // the next 24 hours
    let aqi: Int?                 // US AQI
    let pm25: Double?
    let fetched: Date

    var condition: (text: String, symbol: String) { WeatherCode.describe(code, isDay: isDay) }

    // MARK: Fetching and cache

    private static let cacheKey = "conditions.cache"
    private static let maxAge: TimeInterval = 20 * 60

    static func cached(for place: Place) -> Conditions? {
        guard let data = AppSettings.defaults.data(forKey: cacheKey),
              let value = try? JSONDecoder().decode(Conditions.self, from: data),
              value.placeID == place.id else { return nil }
        return value
    }

    /// Returns cached data if it's fresh, otherwise fetches (falling back to stale cache on failure).
    static func load(for place: Place, force: Bool = false) async -> Conditions? {
        let cache = cached(for: place)
        if !force, let cache, Date.now.timeIntervalSince(cache.fetched) < maxAge { return cache }
        if let fresh = try? await fetch(for: place) {
            if let data = try? JSONEncoder().encode(fresh) { AppSettings.defaults.set(data, forKey: cacheKey) }
            return fresh
        }
        return cache
    }

    static func fetch(for place: Place) async throws -> Conditions {
        struct Forecast: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double, apparent_temperature: Double
                let relative_humidity_2m: Int, wind_speed_10m: Double
                let weather_code: Int, is_day: Int
            }
            struct Hourly: Decodable {
                let time: [String], temperature_2m: [Double], weather_code: [Int], is_day: [Int]
                let precipitation_probability: [Int?], precipitation: [Double?]
            }
            struct Daily: Decodable {
                let temperature_2m_max: [Double], temperature_2m_min: [Double]
                let apparent_temperature_max: [Double]
                let precipitation_probability_max: [Int?], uv_index_max: [Double?]
            }
            let current: Current, hourly: Hourly, daily: Daily
        }
        struct Air: Decodable {
            struct Current: Decodable { let us_aqi: Int?; let pm2_5: Double? }
            let current: Current
        }

        let coords = "latitude=\(place.latitude)&longitude=\(place.longitude)"
        let forecastURL = URL(string: "https://api.open-meteo.com/v1/forecast?\(coords)"
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,is_day,precipitation_probability,precipitation"
            + "&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,uv_index_max"
            + "&timezone=auto&forecast_days=2&forecast_hours=25")!
        let airURL = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality?\(coords)"
            + "&current=us_aqi,pm2_5&timezone=auto")!

        async let forecastData = data(from: forecastURL)
        async let airData = try? data(from: airURL)   // air quality is optional
        let f = try JSONDecoder().decode(Forecast.self, from: try await forecastData)
        let air = await airData.flatMap { try? JSONDecoder().decode(Air.self, from: $0) }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = place.timeZone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let fromHour = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        let hours: [Hour] = f.hourly.time.indices.compactMap { i in
            guard let time = parser.date(from: f.hourly.time[i]), time > fromHour else { return nil }
            return Hour(time: time, temperature: f.hourly.temperature_2m[i], code: f.hourly.weather_code[i],
                        isDay: f.hourly.is_day[i] == 1,
                        rainChance: f.hourly.precipitation_probability[i] ?? 0,
                        rainMM: f.hourly.precipitation[i] ?? 0)
        }

        return Conditions(
            placeID: place.id,
            temperature: f.current.temperature_2m, feelsLike: f.current.apparent_temperature,
            humidity: f.current.relative_humidity_2m, wind: f.current.wind_speed_10m,
            code: f.current.weather_code, isDay: f.current.is_day == 1,
            high: f.daily.temperature_2m_max.first ?? f.current.temperature_2m,
            low: f.daily.temperature_2m_min.first ?? f.current.temperature_2m,
            feelsLikeHigh: f.daily.apparent_temperature_max.first ?? f.current.apparent_temperature,
            rainChance: (f.daily.precipitation_probability_max.first ?? 0) ?? 0,
            uv: (f.daily.uv_index_max.first ?? 0) ?? 0,
            hours: hours,
            aqi: air?.current.us_aqi, pm25: air?.current.pm2_5,
            fetched: .now)
    }

    private static func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    static let sample = Conditions(
        placeID: Place.dhaka.id, temperature: 25.8, feelsLike: 27.7, humidity: 71, wind: 3, code: 0, isDay: true,
        high: 26.4, low: 17.6, feelsLikeHigh: 28.5, rainChance: 0, uv: 6, hours: [], aqi: 171, pm25: 75.7, fetched: .now)
}

// MARK: - Air quality

struct AirQuality {
    let aqi: Int

    /// US EPA AQI bands, in Bangla.
    var level: (name: String, short: String, advice: String, color: Color) {
        switch aqi {
        case ..<51: ("ভালো", "ভালো", "বাইরে যাওয়া নিরাপদ", Color(red: 0.3, green: 0.85, blue: 0.4))
        case ..<101: ("মাঝারি", "মাঝারি", "সংবেদনশীলরা সাবধান", Color(red: 1.0, green: 0.85, blue: 0.2))
        case ..<151: ("সংবেদনশীলদের জন্য অস্বাস্থ্যকর", "সংবেদনশীল", "শিশু ও বয়স্করা মাস্ক পরুন", Color(red: 1.0, green: 0.55, blue: 0.15))
        case ..<201: ("অস্বাস্থ্যকর", "অস্বাস্থ্যকর", "বাইরে মাস্ক পরুন", Color(red: 1.0, green: 0.3, blue: 0.3))
        case ..<301: ("খুব অস্বাস্থ্যকর", "খুব খারাপ", "বাইরে কম যান", Color(red: 0.7, green: 0.35, blue: 1.0))
        default: ("বিপজ্জনক", "বিপজ্জনক", "ঘরে থাকুন", Color(red: 0.75, green: 0.15, blue: 0.3))
        }
    }

    /// 0...1 position on a 0–300 scale, for gauges.
    var gaugeValue: Double { min(Double(aqi) / 300, 1) }

    static let gradient = Gradient(colors: [
        Color(red: 0.3, green: 0.85, blue: 0.4), Color(red: 1.0, green: 0.85, blue: 0.2),
        Color(red: 1.0, green: 0.55, blue: 0.15), Color(red: 1.0, green: 0.3, blue: 0.3),
        Color(red: 0.7, green: 0.35, blue: 1.0),
    ])
}

// MARK: - Rain alert

struct RainAlert {
    /// The first hour in the next 12 with a real chance of rain.
    let next: Conditions.Hour?
    /// Highest chance in the next 12 hours.
    let maxChance: Int

    init(_ c: Conditions, now: Date = .now) {
        let window = c.hours.filter { $0.time > now.addingTimeInterval(-3600) && $0.time < now.addingTimeInterval(12 * 3600) }
        next = window.first { $0.rainChance >= 40 || $0.rainMM >= 0.3 }
        maxChance = window.map(\.rainChance).max() ?? 0
    }

    var isRaining: Bool { next.map { $0.time <= Date.now.addingTimeInterval(3600) } ?? false }

    static let color = Color(red: 0.35, green: 0.65, blue: 1.0)
}

// MARK: - Heat alert

struct HeatAlert {
    let feelsLike: Double      // the higher of now and today's peak
    let uv: Double

    init(_ c: Conditions) {
        feelsLike = max(c.feelsLike, c.feelsLikeHigh)
        uv = c.uv
    }

    var level: (name: String, advice: String, symbol: String, color: Color) {
        switch feelsLike {
        case 41...: ("চরম গরম", "রোদে বের হবেন না, প্রচুর পানি পান করুন", "thermometer.sun.fill", Color(red: 1.0, green: 0.25, blue: 0.25))
        case 38..<41: ("তীব্র গরম", "দুপুরে রোদ এড়িয়ে চলুন, পানি পান করুন", "thermometer.sun.fill", Color(red: 1.0, green: 0.45, blue: 0.2))
        case 35..<38: ("গরম", "পর্যাপ্ত পানি পান করুন", "thermometer.sun", Color(red: 1.0, green: 0.7, blue: 0.2))
        case 10..<35: ("স্বাভাবিক", "আবহাওয়া আরামদায়ক", "thermometer.medium", Color(red: 0.4, green: 0.9, blue: 0.5))
        case 0..<10: ("ঠান্ডা", "গরম কাপড় পরুন", "thermometer.snowflake", Color(red: 0.45, green: 0.75, blue: 1.0))
        default: ("তীব্র শীত", "ভারী গরম কাপড় পরুন", "snowflake", Color(red: 0.6, green: 0.8, blue: 1.0))
        }
    }

    var uvWarning: String? {
        switch uv {
        case 11...: "অতিবেগুনি রশ্মি চরম"
        case 8..<11: "অতিবেগুনি রশ্মি খুব বেশি"
        case 6..<8: "অতিবেগুনি রশ্মি বেশি"
        default: nil
        }
    }
}

// MARK: - Bangla time of day

extension Bangla {
    /// "বিকেল ৪টা" in the given calendar's time zone.
    static func timeOfDay(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let part: String = switch hour {
        case 4..<6: "ভোর"
        case 6..<12: "সকাল"
        case 12..<15: "দুপুর"
        case 15..<18: "বিকেল"
        case 18..<20: "সন্ধ্যা"
        default: "রাত"
        }
        return "\(part) \(digits((hour + 11) % 12 + 1))টা"
    }
}
