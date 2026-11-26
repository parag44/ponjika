import WidgetKit
import SwiftUI

private enum SunColor {
    static let rise = Color(red: 1.0, green: 0.8, blue: 0.25)
    static let set = Color(red: 1.0, green: 0.48, blue: 0.3)
    static let dusk = Color(red: 0.62, green: 0.42, blue: 1.0)
}

/// 15-minute entries plus exact entries at sunrise and sunset, so the
/// "next event" flips the moment it happens.
struct SunProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        var dates: Set<Date> = [now]
        let minute = calendar.component(.minute, from: now)
        if let start = calendar.date(bySettingHour: calendar.component(.hour, from: now),
                                     minute: minute - minute % 15, second: 0, of: now) {
            for step in 1...48 {
                if let date = calendar.date(byAdding: .minute, value: step * 15, to: start) { dates.insert(date) }
            }
        }
        let horizon = now.addingTimeInterval(12 * 3600)
        for offset in 0...1 {
            if let probe = calendar.date(byAdding: .day, value: offset, to: now), let day = Sun.day(for: probe, at: AppSettings.place) {
                for event in [day.sunrise, day.sunset] where event > now && event < horizon {
                    dates.insert(event.addingTimeInterval(1))
                }
            }
        }
        completion(Timeline(entries: dates.sorted().map { DayEntry(date: $0) }, policy: .atEnd))
    }
}

struct SunView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        let place = AppSettings.place
        let next = Sun.next(after: entry.date, at: place)
        let isRise = next?.event == .sunrise
        let label = isRise ? "সূর্যোদয়" : "সূর্যাস্ত"
        let symbol = isRise ? "sunrise.fill" : "sunset.fill"
        let color = isRise ? SunColor.rise : SunColor.set
        let time = next.map { Bangla.clock($0.at, calendar: place.calendar) } ?? "--"

        switch family {
        case .accessoryInline:
            Label("\(label) \(time)", systemImage: symbol)
        case .accessoryCorner:
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .widgetAccentable()
                .widgetLabel("\(label) \(time)")
        case .accessoryRectangular:
            rectangular
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .fill(LinearGradient(colors: [color.opacity(0.35), isRise ? .clear : SunColor.dusk.opacity(0.3)],
                                         startPoint: .top, endPoint: .bottom))
                VStack(spacing: -2) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.multicolor)
                        .widgetAccentable()
                    Text(time)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// সূর্যোদয় / সূর্যাস্ত for today, plus a bar showing where the sun is in the day.
    private var rectangular: some View {
        let place = AppSettings.place
        let today = Sun.day(for: entry.date, at: place)
        let progress: Double = today.map {
            min(max(entry.date.timeIntervalSince($0.sunrise) / $0.daylight, 0), 1)
        } ?? 0
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "sunrise.fill").symbolRenderingMode(.multicolor)
                Text("সূর্যোদয়").opacity(0.8)
                Spacer(minLength: 2)
                Text(today.map { Bangla.clock($0.sunrise, calendar: place.calendar) } ?? "--")
                    .fontWeight(.bold).foregroundStyle(SunColor.rise).widgetAccentable()
            }
            HStack(spacing: 4) {
                Image(systemName: "sunset.fill").symbolRenderingMode(.multicolor)
                Text("সূর্যাস্ত").opacity(0.8)
                Spacer(minLength: 2)
                Text(today.map { Bangla.clock($0.sunset, calendar: place.calendar) } ?? "--")
                    .fontWeight(.bold).foregroundStyle(SunColor.set).widgetAccentable()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [SunColor.rise, SunColor.set, SunColor.dusk],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.height, geo.size.width * progress))
                        .widgetAccentable()
                }
            }
            .frame(height: 5)
            .padding(.top, 1)
            Text("দিনের দৈর্ঘ্য \(today.map { Bangla.duration($0.daylight) } ?? "--")")
                .font(.system(size: 11))
                .opacity(0.7)
        }
        .font(.system(size: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaSun", provider: SunProvider()) { entry in
            SunView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.sky.url)
        }
        .configurationDisplayName("সূর্যোদয় / সূর্যাস্ত")
        .description("Next sunrise or sunset for your chosen city, in Bangla.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
