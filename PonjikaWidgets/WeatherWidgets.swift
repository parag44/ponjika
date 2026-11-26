import WidgetKit
import SwiftUI

// MARK: - Data

/// Current Dhaka weather from Open-Meteo (free, no API key). Only Dhaka's fixed
/// coordinates are sent. The last good reading is cached for offline display.
struct WeatherNow: Codable, Equatable {
    let temperature: Double
    let code: Int
    let isDay: Bool
    let high: Double
    let low: Double
    let fetched: Date

    private static let cacheKey = "weather.dhaka"
    private static let url = URL(string:
        "https://api.open-meteo.com/v1/forecast?latitude=23.7104&longitude=90.4074"
        + "&current=temperature_2m,weather_code,is_day"
        + "&daily=temperature_2m_max,temperature_2m_min&timezone=Asia%2FDhaka&forecast_days=1")!

    static var cached: WeatherNow? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(WeatherNow.self, from: data)
    }

    static func fetch() async -> WeatherNow? {
        struct Response: Decodable {
            struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let is_day: Int }
            struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
            let current: Current
            let daily: Daily
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        let now = WeatherNow(temperature: decoded.current.temperature_2m,
                             code: decoded.current.weather_code,
                             isDay: decoded.current.is_day == 1,
                             high: decoded.daily.temperature_2m_max.first ?? decoded.current.temperature_2m,
                             low: decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m,
                             fetched: .now)
        if let encoded = try? JSONEncoder().encode(now) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
        return now
    }

    static let sample = WeatherNow(temperature: 25.8, code: 0, isDay: true, high: 26.4, low: 17.6, fetched: .now)

    var condition: (text: String, symbol: String) { WeatherCode.describe(code, isDay: isDay) }
    static func color(for celsius: Double) -> Color { WeatherCode.color(for: celsius) }
    static func degrees(_ celsius: Double) -> String { WeatherCode.degrees(celsius) }
}

// MARK: - Timeline

struct WeatherEntry: TimelineEntry {
    let date: Date
    let weather: WeatherNow?
}

/// Lets the non-Sendable WidgetKit completion handler cross into a Task.
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: .now, weather: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherEntry(date: .now, weather: WeatherNow.cached ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let done = UncheckedBox(value: completion)
        Task {
            let weather = await WeatherNow.fetch() ?? WeatherNow.cached
            // Refresh every 30 minutes; retry sooner if there was no data at all.
            let next = Date.now.addingTimeInterval(weather == nil ? 10 * 60 : 30 * 60)
            done.value(Timeline(entries: [WeatherEntry(date: .now, weather: weather)], policy: .after(next)))
        }
    }
}

// MARK: - Views

struct WeatherView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        if let w = entry.weather {
            content(w)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor)
                    Text("--°").font(.system(size: 14, weight: .bold))
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ w: WeatherNow) -> some View {
        let (text, symbol) = w.condition
        let tempColor = WeatherNow.color(for: w.temperature)
        let temp = WeatherNow.degrees(w.temperature)
        switch family {
        case .accessoryInline:
            Label("\(temp) \(text)", systemImage: symbol)
        case .accessoryCorner:
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: w.temperature, in: min(w.low, w.temperature)...max(w.high, w.temperature)) {
                        Text("তাপ")
                    } currentValueLabel: {
                        Text(temp)
                    } minimumValueLabel: {
                        Text(WeatherNow.degrees(w.low))
                    } maximumValueLabel: {
                        Text(WeatherNow.degrees(w.high))
                    }
                    .tint(Gradient(colors: [WeatherNow.color(for: w.low), WeatherNow.color(for: w.high)]))
                }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ঢাকা")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tempColor)
                        .widgetAccentable()
                    Text(text)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("সর্বোচ্চ \(WeatherNow.degrees(w.high)) · সর্বনিম্ন \(WeatherNow.degrees(w.low))")
                        .font(.system(size: 12))
                        .opacity(0.75)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Image(systemName: symbol)
                        .font(.system(size: 20))
                        .symbolRenderingMode(.multicolor)
                    Text(temp)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tempColor)
                }
            }
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.multicolor)
                        .widgetAccentable()
                    Text(temp)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tempColor)
                    Text("\(Bangla.digits(Int(w.high.rounded())))/\(Bangla.digits(Int(w.low.rounded())))")
                        .font(.system(size: 8, weight: .medium))
                        .opacity(0.75)
                }
            }
        }
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaWeather", provider: WeatherProvider()) { entry in
            WeatherView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.weather.url)
        }
        .configurationDisplayName("আবহাওয়া")
        .description("Dhaka temperature and conditions, in Bangla. Data: Open-Meteo.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
