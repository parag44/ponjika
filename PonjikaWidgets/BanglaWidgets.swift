import WidgetKit
import SwiftUI

// Colours only show in full on a face set to Multicolour. On a single-colour
// face watchOS tints the `.widgetAccentable()` parts and draws the rest white.
private enum BanglaColor {
    static let red = Color(red: 1.0, green: 0.33, blue: 0.38)
    static let green = Color(red: 0.2, green: 0.82, blue: 0.55)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.2)
    static let dayGradient = Gradient(colors: [
        Color(red: 1.0, green: 0.75, blue: 0.2),   // morning
        Color(red: 1.0, green: 0.4, blue: 0.45),   // afternoon
        Color(red: 0.6, green: 0.4, blue: 1.0),    // night
    ])
}

private extension Color {
    init(_ rgb: (Double, Double, Double)) { self.init(red: rgb.0, green: rgb.1, blue: rgb.2) }
}

// MARK: - বাংলা তারিখ (Bangla date)

struct BanglaDateView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        let b = BanglaDate(entry.date)
        let seasonColor = Color(b.season.rgb)
        switch family {
        case .accessoryInline:
            Text("\(Bangla.digits(b.day)) \(b.monthName) \(Bangla.digits(b.year))")
        case .accessoryCorner:
            Text(Bangla.digits(b.day))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BanglaColor.red)
                .widgetAccentable()
                .widgetLabel("\(b.monthName) \(Bangla.digits(b.year))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(Bangla.weekday(entry.date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BanglaColor.orange)
                    .widgetAccentable()
                (Text(Bangla.digits(b.day)).foregroundStyle(BanglaColor.red)
                 + Text(" \(b.monthName) ").foregroundStyle(seasonColor)
                 + Text(Bangla.digits(b.year)))
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // Season lives in its own ঋতু complication, so it isn't repeated here.
                Text("\(Bangla.gregorianDate(entry.date)) \(Bangla.digits(Calendar.current.component(.year, from: entry.date)))")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -3) {
                    Text(Bangla.weekday(entry.date, short: true))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BanglaColor.orange)
                    Text(Bangla.digits(b.day))
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(BanglaColor.red)
                        .widgetAccentable()
                    Text(b.monthName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(seasonColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 5)
                }
            }
        }
    }
}

struct BanglaDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaDate", provider: DayProvider()) { entry in
            BanglaDateView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.today.url)
        }
        .configurationDisplayName("বাংলা তারিখ")
        .description("Today's date in the Bangla calendar (Bangladesh).")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - ঋতু (season)

struct BanglaSeasonView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        let season = BanglaDate(entry.date).season
        let color = Color(season.rgb)
        switch family {
        case .accessoryInline:
            Label("\(season.name)কাল", systemImage: season.symbol)
        case .accessoryCorner:
            Image(systemName: season.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .widgetAccentable()
                .widgetLabel("\(season.name)কাল")
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.35), .clear],
                                         center: .center, startRadius: 2, endRadius: 30))
                VStack(spacing: 1) {
                    Image(systemName: season.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                        .widgetAccentable()
                    Text(season.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

struct BanglaSeasonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaSeason", provider: DayProvider()) { entry in
            BanglaSeasonView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.today.url)
        }
        .configurationDisplayName("ঋতু")
        .description("The current season of the six Bangla seasons.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - দিন (day progress)

struct BanglaDayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        let fraction = DayClock.fraction(at: entry.date)
        let percent = Bangla.digits(Int((fraction * 100).rounded(.down))) + "%"
        switch family {
        case .accessoryCorner:
            Text(percent)
                .font(.system(size: 14, weight: .bold))
                .widgetLabel {
                    Gauge(value: fraction) { Text("দিন") }
                        .tint(BanglaColor.dayGradient)
                }
        default: // .accessoryCircular
            Gauge(value: fraction) {
                Text("দিন")
            } currentValueLabel: {
                Text(percent)
                    .font(.system(size: 13, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(BanglaColor.dayGradient)
            .widgetAccentable()
        }
    }
}

struct BanglaDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaDay", provider: DayProvider()) { entry in
            BanglaDayView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.today.url)
        }
        .configurationDisplayName("দিনের অগ্রগতি")
        .description("How much of today has passed, in Bangla numerals.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

// MARK: - ছুটি ও দিবস কাউন্টডাউন (holiday countdown)

struct BanglaCountdownView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        if let holiday = Holidays.next(from: entry.date) {
            content(holiday, days: holiday.daysAway(from: entry.date))
        } else {
            Image(systemName: "calendar")
        }
    }

    @ViewBuilder
    private func content(_ holiday: Holiday, days: Int) -> some View {
        let color = Color(holiday.rgb)
        let count = days == 0 ? "আজ" : Bangla.digits(days)
        switch family {
        case .accessoryInline:
            Label(days == 0 ? "আজ \(holiday.short)" : "\(holiday.short) · \(count) দিন বাকি",
                  systemImage: holiday.symbol)
        case .accessoryCorner:
            Text(count)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .widgetAccentable()
                .widgetLabel(days == 0 ? holiday.short : "\(holiday.short) · দিন বাকি")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Label(holiday.name, systemImage: holiday.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(days == 0 ? "আজ" : "আর \(count) দিন")
                    .font(.system(size: 20, weight: .bold))
                Text(holiday.dateText() + (holiday.moonDependent ? " · চাঁদ সাপেক্ষে" : ""))
                    .font(.system(size: 12))
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Image(systemName: holiday.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                    Text(count)
                        .font(.system(size: days == 0 ? 16 : 20, weight: .bold))
                        .foregroundStyle(color)
                        .widgetAccentable()
                        .minimumScaleFactor(0.7)
                    Text(holiday.short)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 5)
                }
            }
        }
    }
}

struct BanglaCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaCountdown", provider: DayProvider()) { entry in
            BanglaCountdownView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.days.url)
        }
        .configurationDisplayName("ছুটি ও দিবস")
        .description("Days until the next Bangladesh holiday or national day, including Eid and Puja.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
