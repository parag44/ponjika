import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ConditionsEntry: TimelineEntry {
    let date: Date
    let place: Place
    let conditions: Conditions?
}

/// Lets the non-Sendable WidgetKit completion handler cross into a Task.
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }

/// Shared by the weather, air quality, rain and heat complications. Data is
/// cached in the App Group, so these complications and the app share one fetch.
struct ConditionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConditionsEntry {
        ConditionsEntry(date: .now, place: .dhaka, conditions: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConditionsEntry) -> Void) {
        let place = AppSettings.place
        completion(ConditionsEntry(date: .now, place: place, conditions: Conditions.cached(for: place) ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConditionsEntry>) -> Void) {
        let done = UncheckedBox(value: completion)
        let place = AppSettings.place
        Task {
            let conditions = await Conditions.load(for: place)
            // A few entries over the next hour so "next rain" stays current; refetch after 30 min.
            let now = Date.now
            let entries = (0..<4).map { i in
                ConditionsEntry(date: now.addingTimeInterval(Double(i) * 15 * 60), place: place, conditions: conditions)
            }
            let next = now.addingTimeInterval(conditions == nil ? 10 * 60 : 30 * 60)
            done.value(Timeline(entries: entries, policy: .after(next)))
        }
    }
}

/// Shown when there's no data yet (first run, no connection).
private struct NoData: View {
    let symbol: String
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: symbol).symbolRenderingMode(.multicolor)
                Text("--").font(.system(size: 14, weight: .bold))
            }
        }
    }
}

// MARK: - আবহাওয়া

struct WeatherView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConditionsEntry

    var body: some View {
        if let c = entry.conditions { content(c) } else { NoData(symbol: "cloud.sun.fill") }
    }

    @ViewBuilder
    private func content(_ c: Conditions) -> some View {
        let (text, symbol) = c.condition
        let tempColor = WeatherCode.color(for: c.temperature)
        let temp = WeatherCode.degrees(c.temperature)
        switch family {
        case .accessoryInline:
            Label("\(temp) \(text)", systemImage: symbol)
        case .accessoryCorner:
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: c.temperature, in: min(c.low, c.temperature)...max(c.high, c.temperature)) {
                        Text("তাপ")
                    } currentValueLabel: {
                        Text(temp)
                    } minimumValueLabel: {
                        Text(WeatherCode.degrees(c.low))
                    } maximumValueLabel: {
                        Text(WeatherCode.degrees(c.high))
                    }
                    .tint(Gradient(colors: [WeatherCode.color(for: c.low), WeatherCode.color(for: c.high)]))
                }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.place.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tempColor)
                        .widgetAccentable()
                        .lineLimit(1)
                    Text(text)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("সর্বোচ্চ \(WeatherCode.degrees(c.high)) · সর্বনিম্ন \(WeatherCode.degrees(c.low))")
                        .font(.system(size: 12))
                        .opacity(0.75)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Image(systemName: symbol).font(.system(size: 20)).symbolRenderingMode(.multicolor)
                    Text(temp).font(.system(size: 20, weight: .bold)).foregroundStyle(tempColor)
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
                    Text("\(Bangla.digits(Int(c.high.rounded())))/\(Bangla.digits(Int(c.low.rounded())))")
                        .font(.system(size: 8, weight: .medium))
                        .opacity(0.75)
                }
            }
        }
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaWeather", provider: ConditionsProvider()) { entry in
            WeatherView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.weather.url)
        }
        .configurationDisplayName("আবহাওয়া")
        .description("Temperature and conditions for your chosen city, in Bangla.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - বায়ুর মান (air quality)

struct AirQualityView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConditionsEntry

    var body: some View {
        if let aqi = entry.conditions?.aqi { content(AirQuality(aqi: aqi), pm25: entry.conditions?.pm25) }
        else { NoData(symbol: "aqi.medium") }
    }

    @ViewBuilder
    private func content(_ air: AirQuality, pm25: Double?) -> some View {
        let value = Bangla.digits(air.aqi)
        switch family {
        case .accessoryInline:
            Label("বায়ু \(value) · \(air.level.short)", systemImage: "aqi.medium")
        case .accessoryCorner:
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(air.level.color)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: air.gaugeValue) { Text("বায়ু") }
                        .tint(AirQuality.gradient)
                }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("বায়ুর মান · \(entry.place.name)", systemImage: "aqi.medium")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.8)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(air.level.color)
                        .widgetAccentable()
                    Text(air.level.short)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(air.level.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Gauge(value: air.gaugeValue) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(AirQuality.gradient)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default: // .accessoryCircular
            Gauge(value: air.gaugeValue) {
                Text("বায়ু")
            } currentValueLabel: {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(air.level.color)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(AirQuality.gradient)
            .widgetAccentable()
        }
    }
}

struct AirQualityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaAirQuality", provider: ConditionsProvider()) { entry in
            AirQualityView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.weather.url)
        }
        .configurationDisplayName("বায়ুর মান")
        .description("Air quality (US AQI) for your chosen city, colour-coded.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - বৃষ্টির সতর্কতা (rain alert)

struct RainView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConditionsEntry

    var body: some View {
        if let c = entry.conditions { content(RainAlert(c, now: entry.date)) } else { NoData(symbol: "umbrella.fill") }
    }

    @ViewBuilder
    private func content(_ rain: RainAlert) -> some View {
        let calendar = entry.place.calendar
        let color = rain.next == nil ? Color.gray : RainAlert.color
        let headline: String = {
            guard let next = rain.next else { return "বৃষ্টি নেই" }
            return rain.isRaining ? "এখন বৃষ্টি" : Bangla.timeOfDay(next.time, calendar: calendar)
        }()
        switch family {
        case .accessoryInline:
            Label(rain.next == nil ? "১২ ঘণ্টায় বৃষ্টি নেই" : "বৃষ্টি · \(headline)", systemImage: "umbrella.fill")
        case .accessoryCorner:
            Image(systemName: rain.next == nil ? "umbrella" : "cloud.rain.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .widgetAccentable()
                .widgetLabel(rain.next == nil ? "বৃষ্টি নেই" : "বৃষ্টি \(headline)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("বৃষ্টির সতর্কতা", systemImage: "umbrella.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .widgetAccentable()
                Text(rain.next == nil ? "বৃষ্টির সম্ভাবনা নেই" : "\(headline) বৃষ্টি")
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(rain.next.map { "সম্ভাবনা \(Bangla.digits($0.rainChance))% · ছাতা নিন" }
                     ?? "আগামী ১২ ঘণ্টা · সর্বোচ্চ \(Bangla.digits(rain.maxChance))%")
                    .font(.system(size: 12))
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: rain.next == nil ? "umbrella" : "cloud.rain.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                        .widgetAccentable()
                    if let next = rain.next {
                        Text(rain.isRaining ? "এখন" : clock(next.time, calendar))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(color)
                        Text("\(Bangla.digits(next.rainChance))%")
                            .font(.system(size: 9, weight: .semibold))
                    } else {
                        Text("নেই")
                            .font(.system(size: 13, weight: .bold))
                        Text("বৃষ্টি")
                            .font(.system(size: 9, weight: .semibold))
                            .opacity(0.75)
                    }
                }
            }
        }
    }

    /// "৪টা" for the small circle.
    private func clock(_ date: Date, _ calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        return Bangla.digits((hour + 11) % 12 + 1) + "টা"
    }
}

struct RainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaRain", provider: ConditionsProvider()) { entry in
            RainView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.weather.url)
        }
        .configurationDisplayName("বৃষ্টির সতর্কতা")
        .description("When rain is likely in the next 12 hours.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - গরমের সতর্কতা (heat alert)

struct HeatView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConditionsEntry

    var body: some View {
        if let c = entry.conditions { content(HeatAlert(c)) } else { NoData(symbol: "thermometer.sun.fill") }
    }

    @ViewBuilder
    private func content(_ heat: HeatAlert) -> some View {
        let level = heat.level
        let feels = WeatherCode.degrees(heat.feelsLike)
        switch family {
        case .accessoryInline:
            Label("\(level.name) · অনুভূত \(feels)", systemImage: level.symbol)
        case .accessoryCorner:
            Image(systemName: level.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(level.color)
                .widgetAccentable()
                .widgetLabel("\(level.name) \(feels)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("গরমের সতর্কতা", systemImage: level.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(level.color)
                    .widgetAccentable()
                Text("\(level.name) · অনুভূত \(feels)")
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(heat.uvWarning ?? level.advice)
                    .font(.system(size: 12))
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                Circle().fill(RadialGradient(colors: [level.color.opacity(0.35), .clear],
                                             center: .center, startRadius: 2, endRadius: 30))
                VStack(spacing: -1) {
                    Image(systemName: level.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(level.color)
                        .widgetAccentable()
                    Text(feels)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(level.color)
                    Text(level.name)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                }
            }
        }
    }
}

struct HeatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaHeat", provider: ConditionsProvider()) { entry in
            HeatView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.weather.url)
        }
        .configurationDisplayName("গরমের সতর্কতা")
        .description("Feels-like temperature with heat, cold and UV warnings.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
