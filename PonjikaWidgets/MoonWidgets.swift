import WidgetKit
import SwiftUI

struct MoonView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    private static let silver = Color(red: 0.78, green: 0.82, blue: 1.0)
    private static let gold = Color(red: 1.0, green: 0.85, blue: 0.4)

    var body: some View {
        let moon = MoonPhase(entry.date)
        let percent = Bangla.digits(Int((moon.illumination * 100).rounded())) + "%"
        let accent = moon.isWaxing ? Self.gold : Self.silver
        switch family {
        case .accessoryInline:
            Label("\(moon.paksha) \(moon.tithiName) · \(percent)", systemImage: "moon.stars.fill")
        case .accessoryCorner:
            MoonDisc(phase: moon)
                .frame(width: 22, height: 22)
                .widgetAccentable()
                .widgetLabel("\(moon.tithiName) · \(percent)")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(moon.paksha)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .widgetAccentable()
                    Text(moon.tithiName)
                        .font(.system(size: 19, weight: .bold))
                    Text(nextLine(moon))
                        .font(.system(size: 12))
                        .opacity(0.75)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    MoonDisc(phase: moon).frame(width: 34, height: 34)
                    Text(percent).font(.system(size: 11, weight: .semibold)).opacity(0.8)
                }
            }
        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    MoonDisc(phase: moon)
                        .frame(width: 20, height: 20)
                        .widgetAccentable()
                    Text(moon.tithiName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(moon.isWaxing ? "শুক্ল" : "কৃষ্ণ")
                        .font(.system(size: 8, weight: .medium))
                        .opacity(0.75)
                }
                .padding(.horizontal, 5)
            }
        }
    }

    private func nextLine(_ moon: MoonPhase) -> String {
        if moon.tithi == 15 { return "আজ পূর্ণিমা" }
        if moon.tithi == 30 { return "আজ অমাবস্যা" }
        return moon.isWaxing
            ? "পূর্ণিমা আর \(Bangla.digits(max(moon.daysToFull, 1))) দিন"
            : "অমাবস্যা আর \(Bangla.digits(max(moon.daysToNew, 1))) দিন"
    }
}

struct MoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BanglaMoon", provider: DayProvider()) { entry in
            MoonView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(AppPage.sky.url)
        }
        .configurationDisplayName("চাঁদ")
        .description("Moon phase and Bengali tithi.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
