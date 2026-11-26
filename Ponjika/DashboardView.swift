import SwiftUI

/// The app: Digital Crown pages of useful info.
/// Complications open the matching page through `ponjika://<page>` links.
struct DashboardView: View {
    @State private var page: AppPage = .today
    @State private var weather = WeatherStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $page) {
            TodayPage().tag(AppPage.today)
            WeatherPage(store: weather).tag(AppPage.weather)
            SkyPage().tag(AppPage.sky)
            DaysPage().tag(AppPage.days)
        }
        .tabViewStyle(.verticalPage)
        .background(Color.black.ignoresSafeArea())
        .onOpenURL { url in
            if let target = AppPage(rawValue: url.host() ?? "") { page = target }
        }
        .task { await weather.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await weather.refresh() } }
        }
    }
}

// MARK: - Shared bits

private enum Palette {
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.2)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.38)
    static let green = Color(red: 0.2, green: 0.82, blue: 0.55)
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.25)
    static let coral = Color(red: 1.0, green: 0.48, blue: 0.3)
    static let violet = Color(red: 0.62, green: 0.42, blue: 1.0)
    static let silver = Color(red: 0.78, green: 0.82, blue: 1.0)
}

private struct PageTitle: View {
    let text: String
    let symbol: String
    let color: Color
    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
    }
}

private struct ProgressBar: View {
    let value: Double
    let colors: [Color]
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.height, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

private struct Stat: View {
    let symbol: String
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 16)
            VStack(alignment: .leading, spacing: -1) {
                Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 14, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "৫টা"
private func hourLabel(_ date: Date) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    return Bangla.digits((hour + 11) % 12 + 1) + "টা"
}

/// "২৪ ডিসেম্বর"
private func shortDate(_ date: Date) -> String { Bangla.gregorianDate(date) }

// MARK: - আজ

struct TodayPage: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let b = BanglaDate(date)
            let seasonColor = Color(rgb: b.season.rgb)
            let fraction = DayClock.fraction(at: date)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    PageTitle(text: "আজ", symbol: "calendar", color: Palette.orange)
                    Text(Bangla.weekday(date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.orange)
                    (Text(Bangla.digits(b.day)).foregroundStyle(Palette.red)
                     + Text(" \(b.monthName)").foregroundStyle(seasonColor))
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(Bangla.digits(b.year)) বঙ্গাব্দ")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("\(Bangla.gregorianDate(date)) \(Bangla.digits(Calendar.current.component(.year, from: date)))")
                        .font(.system(size: 15, weight: .medium))
                    Label("\(b.season.name)কাল", systemImage: b.season.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(seasonColor)
                        .padding(.top, 2)
                    ProgressBar(value: fraction, colors: [Palette.gold, Palette.coral, Palette.violet])
                        .padding(.top, 6)
                    Text("দিনের \(Bangla.digits(Int(fraction * 100)))% পার হয়েছে")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - আবহাওয়া

struct WeatherPage: View {
    let store: WeatherStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                PageTitle(text: "আবহাওয়া · ঢাকা", symbol: "cloud.sun.fill", color: Palette.green)
                if let r = store.report {
                    report(r)
                } else if store.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                } else {
                    Text("আবহাওয়া পাওয়া যায়নি").font(.system(size: 15, weight: .semibold))
                    Text("ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("আবার চেষ্টা") { Task { await store.refresh(force: true) } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func report(_ r: WeatherReport) -> some View {
        let (text, symbol) = WeatherCode.describe(r.code, isDay: r.isDay)
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: -2) {
                Text(WeatherCode.degrees(r.temperature))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(WeatherCode.color(for: r.temperature))
                Text(text).font(.system(size: 14, weight: .semibold))
            }
        }
        VStack(alignment: .leading, spacing: 0) {
            Text("অনুভূত \(WeatherCode.degrees(r.feelsLike))")
            Text("সর্বোচ্চ \(WeatherCode.degrees(r.high)) · সর্বনিম্ন \(WeatherCode.degrees(r.low))")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

        VStack(spacing: 6) {
            HStack {
                Stat(symbol: "humidity.fill", label: "আর্দ্রতা", value: Bangla.digits(r.humidity) + "%", color: .cyan)
                Stat(symbol: "wind", label: "বাতাস", value: Bangla.digits(Int(r.wind.rounded())) + " কিমি/ঘ", color: .mint)
            }
            HStack {
                Stat(symbol: "umbrella.fill", label: "বৃষ্টি", value: Bangla.digits(r.rainChance) + "%", color: .blue)
                Stat(symbol: "sun.max.trianglebadge.exclamationmark.fill", label: "ইউভি",
                     value: Bangla.digits(Int(r.uv.rounded())), color: Palette.gold)
            }
        }
        .padding(.vertical, 4)

        if !r.hours.isEmpty {
            HStack(spacing: 0) {
                ForEach(r.hours.prefix(5)) { hour in
                    let (_, hourSymbol) = WeatherCode.describe(hour.code, isDay: hour.isDay)
                    VStack(spacing: 3) {
                        Text(hourLabel(hour.time)).font(.system(size: 10)).foregroundStyle(.secondary)
                        Image(systemName: hourSymbol).symbolRenderingMode(.multicolor).font(.system(size: 14))
                        Text(WeatherCode.degrees(hour.temperature))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WeatherCode.color(for: hour.temperature))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
        }

        Text("হালনাগাদ \(Bangla.clock(r.fetched))\(store.failed ? " · সংযোগ নেই" : "")")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
}

// MARK: - সূর্য ও চাঁদ

struct SkyPage: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let sun = Sun.day(for: date)
            let moon = MoonPhase(date)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    PageTitle(text: "সূর্য ও চাঁদ", symbol: "sun.and.horizon.fill", color: Palette.gold)
                    if let sun {
                        HStack {
                            Label("সূর্যোদয়", systemImage: "sunrise.fill").symbolRenderingMode(.multicolor)
                            Spacer()
                            Text(Bangla.clock(sun.sunrise)).fontWeight(.bold).foregroundStyle(Palette.gold)
                        }
                        HStack {
                            Label("সূর্যাস্ত", systemImage: "sunset.fill").symbolRenderingMode(.multicolor)
                            Spacer()
                            Text(Bangla.clock(sun.sunset)).fontWeight(.bold).foregroundStyle(Palette.coral)
                        }
                        ProgressBar(value: date.timeIntervalSince(sun.sunrise) / sun.daylight,
                                    colors: [Palette.gold, Palette.coral, Palette.violet])
                        Text("দিনের দৈর্ঘ্য \(Bangla.duration(sun.daylight))")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }

                    Divider().padding(.vertical, 4)

                    HStack(spacing: 10) {
                        MoonDisc(phase: moon).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(moon.paksha)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(moon.isWaxing ? Palette.gold : Palette.silver)
                            Text(moon.tithiName).font(.system(size: 20, weight: .bold))
                            Text("আলোকিত \(Bangla.digits(Int((moon.illumination * 100).rounded())))%")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    if let full = MoonPhase.next(.full, after: date) {
                        Label("পূর্ণিমা: \(shortDate(full))", systemImage: "circle.fill")
                            .font(.system(size: 13)).foregroundStyle(Palette.gold)
                    }
                    if let new = MoonPhase.next(.new, after: date) {
                        Label("অমাবস্যা: \(shortDate(new))", systemImage: "circle")
                            .font(.system(size: 13)).foregroundStyle(Palette.silver)
                    }
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - দিবস

struct DaysPage: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let upcoming = BanglaOccasion.upcoming(after: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    PageTitle(text: "আসন্ন দিবস", symbol: "flag.fill", color: Palette.red)
                    ForEach(upcoming, id: \.0.name) { occasion, days in
                        HStack(spacing: 8) {
                            Image(systemName: occasion.symbol)
                                .foregroundStyle(Color(rgb: occasion.rgb))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: -1) {
                                Text(occasion.name).font(.system(size: 14, weight: .semibold))
                                Text("\(Bangla.digits(occasion.day)) \(Bangla.gregorianMonths[occasion.month - 1])")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Text(days == 0 ? "আজ" : "\(Bangla.digits(days)) দিন")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(rgb: occasion.rgb))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview { DashboardView() }
