import SwiftUI

/// The app: Digital Crown pages of useful info, then settings.
/// Complications open the matching page through `ponjika://<page>` links.
struct DashboardView: View {
    @State private var page: AppPage = .today
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                TodayPage().tag(AppPage.today)
                WeatherPage(model: model).tag(AppPage.weather)
                SkyPage(place: model.place).tag(AppPage.sky)
                HolidaysPage().tag(AppPage.days)
                SettingsPage(model: model).tag(AppPage.settings)
            }
            .tabViewStyle(.verticalPage)
        }
        .background(Color.black.ignoresSafeArea())
        .onOpenURL { url in
            if let target = AppPage(rawValue: url.host() ?? "") { page = target }
        }
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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

/// A coloured alert card: icon, title, detail.
private struct AlertCard: View {
    let symbol: String
    let title: String
    let detail: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
    }
}

/// "৫টা" in the place's time zone.
private func hourLabel(_ date: Date, calendar: Calendar) -> String {
    let hour = calendar.component(.hour, from: date)
    return Bangla.digits((hour + 11) % 12 + 1) + "টা"
}

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
                    if let holiday = Holidays.next(from: date), holiday.daysAway(from: date) == 0 {
                        Label("আজ \(holiday.name)", systemImage: holiday.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(rgb: holiday.rgb))
                    }
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

// MARK: - আবহাওয়া (weather, air quality, alerts)

struct WeatherPage: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                PageTitle(text: "আবহাওয়া · \(model.place.name)", symbol: "cloud.sun.fill", color: Palette.green)
                if let c = model.conditions {
                    report(c)
                } else if model.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                } else {
                    Text("আবহাওয়া পাওয়া যায়নি").font(.system(size: 15, weight: .semibold))
                    Text("ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("আবার চেষ্টা") { Task { await model.refresh(force: true) } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func report(_ c: Conditions) -> some View {
        let (text, symbol) = c.condition
        let calendar = model.place.calendar
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: -2) {
                Text(WeatherCode.degrees(c.temperature))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(WeatherCode.color(for: c.temperature))
                Text(text).font(.system(size: 14, weight: .semibold))
            }
        }
        VStack(alignment: .leading, spacing: 0) {
            Text("অনুভূত \(WeatherCode.degrees(c.feelsLike))")
            Text("সর্বোচ্চ \(WeatherCode.degrees(c.high)) · সর্বনিম্ন \(WeatherCode.degrees(c.low))")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

        // সতর্কতা: air, rain, heat
        alerts(c, calendar: calendar)

        VStack(spacing: 6) {
            HStack {
                Stat(symbol: "humidity.fill", label: "আর্দ্রতা", value: Bangla.digits(c.humidity) + "%", color: .cyan)
                Stat(symbol: "wind", label: "বাতাস", value: Bangla.digits(Int(c.wind.rounded())) + " কিমি/ঘ", color: .mint)
            }
            HStack {
                Stat(symbol: "umbrella.fill", label: "বৃষ্টি", value: Bangla.digits(c.rainChance) + "%", color: .blue)
                Stat(symbol: "sun.max.trianglebadge.exclamationmark.fill", label: "ইউভি",
                     value: Bangla.digits(Int(c.uv.rounded())), color: Palette.gold)
            }
        }
        .padding(.vertical, 4)

        if !c.hours.isEmpty {
            HStack(spacing: 0) {
                ForEach(c.hours.prefix(5)) { hour in
                    let (_, hourSymbol) = WeatherCode.describe(hour.code, isDay: hour.isDay)
                    VStack(spacing: 3) {
                        Text(hourLabel(hour.time, calendar: calendar)).font(.system(size: 10)).foregroundStyle(.secondary)
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

        Text("হালনাগাদ \(Bangla.clock(c.fetched))\(model.failed ? " · সংযোগ নেই" : "")")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func alerts(_ c: Conditions, calendar: Calendar) -> some View {
        VStack(spacing: 5) {
            if let aqi = c.aqi {
                let air = AirQuality(aqi: aqi)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("বায়ুর মান", systemImage: "aqi.medium").font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Text(Bangla.digits(aqi)).font(.system(size: 16, weight: .bold)).foregroundStyle(air.level.color)
                    }
                    ProgressBar(value: air.gaugeValue, colors: AirQuality.gradient.stops.map(\.color))
                    Text(air.level.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(air.level.color)
                    Text("\(air.level.advice)\(c.pm25.map { " · PM২.৫ \(Bangla.digits(Int($0.rounded())))" } ?? "")")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(air.level.color.opacity(0.12)))
            }

            let rain = RainAlert(c)
            if let next = rain.next {
                AlertCard(symbol: "cloud.rain.fill",
                          title: rain.isRaining ? "এখন বৃষ্টি হতে পারে" : "\(Bangla.timeOfDay(next.time, calendar: calendar)) বৃষ্টি",
                          detail: "সম্ভাবনা \(Bangla.digits(next.rainChance))% · ছাতা সঙ্গে রাখুন",
                          color: RainAlert.color)
            } else {
                AlertCard(symbol: "umbrella", title: "বৃষ্টির সম্ভাবনা নেই",
                          detail: "আগামী ১২ ঘণ্টায় সর্বোচ্চ \(Bangla.digits(rain.maxChance))%", color: .gray)
            }

            let heat = HeatAlert(c)
            AlertCard(symbol: heat.level.symbol,
                      title: "\(heat.level.name) · অনুভূত \(WeatherCode.degrees(heat.feelsLike))",
                      detail: [heat.level.advice, heat.uvWarning].compactMap { $0 }.joined(separator: " · "),
                      color: heat.level.color)
        }
    }
}

// MARK: - সূর্য ও চাঁদ

struct SkyPage: View {
    let place: Place

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let sun = Sun.day(for: date, at: place)
            let moon = MoonPhase(date)
            let calendar = place.calendar
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    PageTitle(text: "সূর্য ও চাঁদ · \(place.name)", symbol: "sun.and.horizon.fill", color: Palette.gold)
                    if let sun {
                        HStack {
                            Label("সূর্যোদয়", systemImage: "sunrise.fill").symbolRenderingMode(.multicolor)
                            Spacer()
                            Text(Bangla.clock(sun.sunrise, calendar: calendar)).fontWeight(.bold).foregroundStyle(Palette.gold)
                        }
                        HStack {
                            Label("সূর্যাস্ত", systemImage: "sunset.fill").symbolRenderingMode(.multicolor)
                            Spacer()
                            Text(Bangla.clock(sun.sunset, calendar: calendar)).fontWeight(.bold).foregroundStyle(Palette.coral)
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
                        Label("পূর্ণিমা: \(Bangla.gregorianDate(full, calendar: calendar))", systemImage: "circle.fill")
                            .font(.system(size: 13)).foregroundStyle(Palette.gold)
                    }
                    if let new = MoonPhase.next(.new, after: date) {
                        Label("অমাবস্যা: \(Bangla.gregorianDate(new, calendar: calendar))", systemImage: "circle")
                            .font(.system(size: 13)).foregroundStyle(Palette.silver)
                    }
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - ছুটি ও দিবস

struct HolidaysPage: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let upcoming = Holidays.upcoming(from: date)
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    PageTitle(text: "ছুটি ও দিবস", symbol: "calendar.badge.clock", color: Palette.red)
                    ForEach(upcoming) { holiday in
                        let days = holiday.daysAway(from: date)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: holiday.symbol)
                                .foregroundStyle(Color(rgb: holiday.rgb))
                                .frame(width: 18)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(holiday.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(holiday.dateText()
                                     + (holiday.kind == .observance ? " · দিবস" : "")
                                     + (holiday.moonDependent ? " · চাঁদ দেখা সাপেক্ষে" : ""))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                            Text(days == 0 ? "আজ" : "\(Bangla.digits(days)) দিন")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(rgb: holiday.rgb))
                        }
                    }
                    Text("সূত্র: বাংলাদেশ সরকারের ছুটির তালিকা")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview { DashboardView() }
