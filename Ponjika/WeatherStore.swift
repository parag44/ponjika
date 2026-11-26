import Foundation
import Observation

/// Detailed Dhaka weather for the app's আবহাওয়া page (Open-Meteo, no API key;
/// only Dhaka's fixed coordinates are sent).
struct WeatherReport: Codable {
    struct Hour: Codable, Identifiable {
        var id: Date { time }
        let time: Date
        let temperature: Double
        let code: Int
        let isDay: Bool
        let rainChance: Int
    }

    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let wind: Double          // km/h
    let code: Int
    let isDay: Bool
    let high: Double
    let low: Double
    let rainChance: Int       // today's max, %
    let uv: Double            // today's max
    let hours: [Hour]         // upcoming hours
    let fetched: Date

    private static let url = URL(string:
        "https://api.open-meteo.com/v1/forecast?latitude=23.7104&longitude=90.4074"
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
        + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
        + "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"
        + "&timezone=Asia%2FDhaka&forecast_days=2&forecast_hours=12")!

    static func fetch() async throws -> WeatherReport {
        struct Response: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double, apparent_temperature: Double
                let relative_humidity_2m: Int, wind_speed_10m: Double
                let weather_code: Int, is_day: Int
            }
            struct Hourly: Decodable {
                let time: [String], temperature_2m: [Double]
                let precipitation_probability: [Int?], weather_code: [Int], is_day: [Int]
            }
            struct Daily: Decodable {
                let temperature_2m_max: [Double], temperature_2m_min: [Double]
                let precipitation_probability_max: [Int?], uv_index_max: [Double?]
            }
            let current: Current, hourly: Hourly, daily: Daily
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let r = try JSONDecoder().decode(Response.self, from: data)

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = Sun.dhaka.timeZone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let startOfHour = Calendar.current.dateInterval(of: .hour, for: .now)?.end ?? .now
        let hours: [Hour] = r.hourly.time.indices.compactMap { i in
            guard let time = parser.date(from: r.hourly.time[i]), time >= startOfHour else { return nil }
            return Hour(time: time, temperature: r.hourly.temperature_2m[i], code: r.hourly.weather_code[i],
                        isDay: r.hourly.is_day[i] == 1, rainChance: r.hourly.precipitation_probability[i] ?? 0)
        }

        return WeatherReport(
            temperature: r.current.temperature_2m, feelsLike: r.current.apparent_temperature,
            humidity: r.current.relative_humidity_2m, wind: r.current.wind_speed_10m,
            code: r.current.weather_code, isDay: r.current.is_day == 1,
            high: r.daily.temperature_2m_max.first ?? r.current.temperature_2m,
            low: r.daily.temperature_2m_min.first ?? r.current.temperature_2m,
            rainChance: (r.daily.precipitation_probability_max.first ?? 0) ?? 0,
            uv: (r.daily.uv_index_max.first ?? 0) ?? 0,
            hours: hours, fetched: .now)
    }
}

@MainActor
@Observable
final class WeatherStore {
    private(set) var report: WeatherReport?
    private(set) var loading = false
    private(set) var failed = false

    private static let cacheKey = "weather.report"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            report = try? JSONDecoder().decode(WeatherReport.self, from: data)
        }
    }

    /// Fetches unless the current report is under 15 minutes old.
    func refresh(force: Bool = false) async {
        if !force, let report, Date.now.timeIntervalSince(report.fetched) < 15 * 60 { return }
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let fresh = try await WeatherReport.fetch()
            report = fresh
            failed = false
            if let data = try? JSONEncoder().encode(fresh) {
                UserDefaults.standard.set(data, forKey: Self.cacheKey)
            }
        } catch {
            failed = true
        }
    }
}
