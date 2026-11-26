import SwiftUI

/// The app: Digital Crown pages — এক নজরে (home glance), আজ, আবহাওয়া,
/// সূর্য ও চাঁদ, ছুটি ও দিবস, সেটিংস. Complications open the matching
/// page through `ponjika://<page>` links; home cards jump to their page.
struct DashboardView: View {
    @State private var page: AppPage = .home
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                HomePage(model: model) { page = $0 }.tag(AppPage.home)
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

// MARK: - Design tokens (from the Watch UI designs)

enum Palette {
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.2)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.38)
    static let green = Color(red: 0.24, green: 0.84, blue: 0.55)
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.25)
    static let coral = Color(red: 1.0, green: 0.48, blue: 0.3)
    static let violet = Color(red: 0.62, green: 0.42, blue: 1.0)
    static let silver = Color(red: 0.78, green: 0.82, blue: 1.0)
    static let blue = Color(red: 0.24, green: 0.55, blue: 1.0)
    static let card = Color(white: 0.11)            // #1C1C1E
    static let separator = Color(white: 0.17)
    static let secondary = Color(red: 0.6, green: 0.6, blue: 0.62)
    static let weekend = Color(red: 1.0, green: 0.42, blue: 0.42)
}

/// Page title in the top-left, like a watchOS navigation title.
struct PageTitle: View {
    let text: String
    let color: Color
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(text).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            if let detail {
                Text(detail).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.leading, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A rounded watchOS-style platter.
struct Card<Content: View>: View {
    var fill: Color = Palette.card
    var radius: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
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
        .frame(height: 5)
    }
}

/// "৫টা" in the place's time zone.
private func hourLabel(_ date: Date, calendar: Calendar) -> String {
    let hour = calendar.component(.hour, from: date)
    return Bangla.digits((hour + 11) % 12 + 1) + "টা"
}

// MARK: - ০ · এক নজরে (home glance)

struct HomePage: View {
    let model: AppModel
    let open: (AppPage) -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let b = BanglaDate(date)
            ScrollView {
                VStack(spacing: 6) {
                    PageTitle(text: "এক নজরে", color: Palette.orange)

                    Button { open(.today) } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Bangla.weekday(date)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.orange)
                                (Text(Bangla.digits(b.day)).foregroundStyle(Palette.red)
                                 + Text(" \(b.monthName) ").foregroundStyle(Palette.gold)
                                 + Text(Bangla.digits(b.year)))
                                    .font(.system(size: 20, weight: .bold))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text("\(Bangla.gregorianDate(date)) · \(b.season.name)কাল")
                                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Button { open(.weather) } label: { weatherTile }.buttonStyle(.plain)
                        Button { open(.weather) } label: { airTile }.buttonStyle(.plain)
                    }

                    if let holiday = Holidays.next(from: date) {
                        let days = holiday.daysAway(from: date)
                        Button { open(.days) } label: {
                            Card {
                                HStack(spacing: 7) {
                                    Image(systemName: holiday.symbol).font(.system(size: 15)).foregroundStyle(Color(rgb: holiday.rgb))
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(holiday.short).font(.system(size: 14, weight: .bold)).lineLimit(1)
                                        Text(holiday.dateText()).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                    }
                                    Spacer(minLength: 2)
                                    Text(days == 0 ? "আজ" : "\(Bangla.digits(days)) দিন")
                                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Color(rgb: holiday.rgb))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var weatherTile: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                if let c = model.conditions {
                    Image(systemName: c.condition.symbol).symbolRenderingMode(.multicolor).font(.system(size: 16))
                    Text(WeatherCode.degrees(c.temperature))
                        .font(.system(size: 23, weight: .semibold)).foregroundStyle(WeatherCode.color(for: c.temperature))
                    Text(c.condition.text).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                } else {
                    Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor).font(.system(size: 16))
                    Text("--°").font(.system(size: 23, weight: .semibold))
                    Text(model.place.name).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var airTile: some View {
        if let aqi = model.conditions?.aqi {
            let air = AirQuality(aqi: aqi)
            Card(fill: air.level.color.opacity(0.16)) {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "aqi.medium").font(.system(size: 16)).foregroundStyle(air.level.color)
                    Text(Bangla.digits(aqi)).font(.system(size: 23, weight: .semibold)).foregroundStyle(air.level.color)
                    Text(air.level.short).font(.system(size: 11)).foregroundStyle(air.level.color.opacity(0.85)).lineLimit(1)
                }
            }
        } else {
            Card {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "aqi.medium").font(.system(size: 16)).foregroundStyle(Palette.secondary)
                    Text("--").font(.system(size: 23, weight: .semibold))
                    Text("বায়ুর মান").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
            }
        }
    }
}

// MARK: - ১ · আজ

struct TodayPage: View {
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let b = BanglaDate(date)
            let seasonColor = Color(rgb: b.season.rgb)
            let moon = MoonPhase(date)
            ScrollView {
                VStack(spacing: 5) {
                    PageTitle(text: "আজ", color: dimmed ? Palette.orange.opacity(0.5) : Palette.orange)

                    HStack(alignment: .center, spacing: 8) {
                        Text(Bangla.digits(b.day))
                            .font(.system(size: 62, weight: dimmed ? .medium : .bold))
                            .foregroundStyle(seasonColor.opacity(dimmed ? 0.55 : 1))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(b.monthName).font(.system(size: 19, weight: .bold))
                                .foregroundStyle(dimmed ? Color(white: 0.65) : .white)
                            Text("\(Bangla.digits(b.year)) · \(Bangla.weekday(date))")
                            Text("\(Bangla.gregorianDate(date)) \(Bangla.digits(Calendar.current.component(.year, from: date)))")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(dimmed ? Color(white: 0.43) : Palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)

                    // This week — looks like a calendar, so it invites a tap.
                    NavigationLink {
                        BanglaCalendarView(date: date)
                    } label: {
                        WeekStrip(date: date, accent: seasonColor, dimmed: dimmed)
                    }
                    .buttonStyle(.plain)

                    if !dimmed {
                        Card(radius: 14) {
                            VStack(spacing: 0) {
                                infoRow(symbol: "moon.stars.fill", color: Palette.silver, text: "\(moon.paksha) \(moon.tithiName)")
                                Divider().overlay(Palette.separator)
                                infoRow(symbol: b.season.symbol, color: seasonColor, text: "\(b.season.name)কাল")
                                if let holiday = Holidays.on(date).first {
                                    Divider().overlay(Palette.separator)
                                    infoRow(symbol: holiday.symbol, color: Color(rgb: holiday.rgb), text: "আজ \(holiday.name)")
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 7) {
                            Image(systemName: "moon.stars").foregroundStyle(Color(white: 0.43))
                            Text("\(moon.paksha) \(moon.tithiName)").foregroundStyle(Color(white: 0.43))
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 11)
                    }
                }
            }
        }
    }

    private func infoRow(symbol: String, color: Color, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(color).frame(width: 18)
            Text(text).font(.system(size: 13)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }
}

/// Sunday-first strip of the current week in Bangla dates, today highlighted.
struct WeekStrip: View {
    let date: Date
    let accent: Color
    var dimmed = false
    private static let initials = ["র", "সো", "ম", "বু", "বৃ", "শু", "শ"]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - (weekday - 1), to: today) }
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    let isToday = calendar.isDate(day, inSameDayAs: today)
                    let weekend = index >= 5
                    VStack(spacing: 1) {
                        Text(Self.initials[index])
                            .font(.system(size: 9))
                            .foregroundStyle(weekend ? Palette.weekend.opacity(dimmed ? 0.5 : 1) : Palette.secondary.opacity(dimmed ? 0.6 : 1))
                        Text(Bangla.digits(BanglaDate(day).day))
                            .font(.system(size: 12, weight: isToday && !dimmed ? .bold : .medium))
                            .foregroundStyle(isToday ? (dimmed ? accent.opacity(0.7) : .black)
                                             : (weekend ? Palette.weekend.opacity(dimmed ? 0.5 : 1) : (dimmed ? Color(white: 0.43) : .white)))
                            .frame(width: 21, height: 21)
                            .background {
                                if isToday {
                                    if dimmed { Circle().stroke(accent.opacity(0.55), lineWidth: 1) }
                                    else { Circle().fill(accent) }
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if !dimmed {
                Text("পুরো মাস দেখুন ›").font(.system(size: 10, weight: .semibold)).foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(dimmed ? Color.clear : Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(dimmed ? Color(white: 0.17) : .clear, lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("পুরো মাসের বাংলা ক্যালেন্ডার খোলে")
    }
}

// MARK: - ২ · আবহাওয়া

struct WeatherPage: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                PageTitle(text: "আবহাওয়া", color: Palette.green, detail: model.place.name)
                if let c = model.conditions {
                    report(c)
                } else if model.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("আবহাওয়া পাওয়া যায়নি").font(.system(size: 14, weight: .semibold))
                            Text("ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                    }
                    Button("আবার চেষ্টা") { Task { await model.refresh(force: true) } }
                }
            }
        }
    }

    @ViewBuilder
    private func report(_ c: Conditions) -> some View {
        let (text, symbol) = c.condition
        let calendar = model.place.calendar

        // Hero: icon, temperature, condition with high/low and feels-like.
        HStack(spacing: 7) {
            Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.system(size: 28))
            Text(WeatherCode.degrees(c.temperature))
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(WeatherCode.color(for: c.temperature))
                .lineLimit(1).minimumScaleFactor(0.6)
            VStack(alignment: .leading, spacing: 0) {
                Text(text).font(.system(size: 13, weight: .semibold))
                Text("↑\(WeatherCode.degrees(c.high)) ↓\(WeatherCode.degrees(c.low))")
                Text("অনুভূত \(WeatherCode.degrees(c.feelsLike))")
            }
            .font(.system(size: 10))
            .foregroundStyle(Palette.secondary)
            .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)

        // Alerts right under the hero: air (full width), rain + heat.
        if let aqi = c.aqi {
            let air = AirQuality(aqi: aqi)
            HStack(spacing: 6) {
                Circle().fill(air.level.color).frame(width: 7, height: 7)
                Text("বায়ু \(Bangla.digits(aqi))").font(.system(size: 12, weight: .bold)).foregroundStyle(air.level.color)
                Text(air.level.name).font(.system(size: 11)).foregroundStyle(air.level.color.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(air.level.color.opacity(0.16)))
        }
        let rain = RainAlert(c)
        let heat = HeatAlert(c)
        HStack(spacing: 5) {
            pill(symbol: rain.next == nil ? "umbrella" : "cloud.rain.fill",
                 text: rain.next.map { rain.isRaining ? "এখন বৃষ্টি" : "\(hourLabel($0.time, calendar: calendar)) বৃষ্টি" } ?? "বৃষ্টি নেই",
                 color: rain.next == nil ? Palette.secondary : RainAlert.color)
            pill(symbol: heat.level.symbol, text: heat.level.name, color: heat.level.color)
        }

        // Next hours.
        if !c.hours.isEmpty {
            HStack(spacing: 0) {
                ForEach(c.hours.prefix(5)) { hour in
                    let (_, hourSymbol) = WeatherCode.describe(hour.code, isDay: hour.isDay)
                    VStack(spacing: 2) {
                        Text(hourLabel(hour.time, calendar: calendar)).font(.system(size: 9)).foregroundStyle(Palette.secondary)
                        Image(systemName: hourSymbol).symbolRenderingMode(.multicolor).font(.system(size: 12))
                        Text(WeatherCode.degrees(hour.temperature))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WeatherCode.color(for: hour.temperature))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
        }

        // Details below the fold.
        Card {
            VStack(spacing: 5) {
                detail("humidity.fill", .cyan, "আর্দ্রতা", Bangla.digits(c.humidity) + "%")
                detail("wind", .mint, "বাতাস", Bangla.digits(Int(c.wind.rounded())) + " কিমি/ঘ")
                detail("umbrella.fill", .blue, "বৃষ্টির সম্ভাবনা", Bangla.digits(c.rainChance) + "%")
                detail("sun.max.fill", Palette.gold, "ইউভি", Bangla.digits(Int(c.uv.rounded())) + (heat.uvWarning.map { " · \($0)" } ?? ""))
                if let aqi = c.aqi {
                    let air = AirQuality(aqi: aqi)
                    detail("aqi.medium", air.level.color, "পরামর্শ", air.level.advice + (c.pm25.map { " · PM২.৫ \(Bangla.digits(Int($0.rounded())))" } ?? ""))
                }
            }
        }

        Text("হালনাগাদ \(Bangla.clock(c.fetched))\(model.failed ? " · সংযোগ নেই" : "")")
            .font(.system(size: 9))
            .foregroundStyle(Palette.secondary)
    }

    private func pill(symbol: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(color)
            Text(text).font(.system(size: 11)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.14)))
    }

    private func detail(_ symbol: String, _ color: Color, _ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(color).frame(width: 14)
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            Spacer(minLength: 4)
            Text(value).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - ৩ · সূর্য ও চাঁদ

/// The sun's path as an arc from sunrise (left) to sunset (right), with the
/// sun at its current position. Before sunrise / after sunset the arc is dim.
struct SunArc: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width / 2 - 14, size.height - 14)
            let center = CGPoint(x: size.width / 2, y: size.height - 4)
            let isDay = progress >= 0 && progress <= 1
            let p = min(max(progress, 0), 1)

            var horizon = Path()
            horizon.move(to: CGPoint(x: 2, y: center.y))
            horizon.addLine(to: CGPoint(x: size.width - 2, y: center.y))
            context.stroke(horizon, with: .color(Color(white: 0.23)), lineWidth: 1)

            var full = Path()
            full.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            context.stroke(full, with: .color(Color(white: 0.23)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 4.5]))

            guard isDay, p > 0 else { return }
            var done = Path()
            done.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * p), clockwise: false)
            context.stroke(done,
                           with: .linearGradient(Gradient(colors: [Palette.gold, Palette.coral, Palette.violet]),
                                                 startPoint: CGPoint(x: center.x - radius, y: 0),
                                                 endPoint: CGPoint(x: center.x + radius, y: 0)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))

            let angle = (180 + 180 * p) * .pi / 180
            let sun = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            context.fill(Path(ellipseIn: CGRect(x: sun.x - 15, y: sun.y - 15, width: 30, height: 30)),
                         with: .radialGradient(Gradient(colors: [Palette.gold.opacity(0.5), Palette.gold.opacity(0)]),
                                               center: sun, startRadius: 0, endRadius: 15))
            context.fill(Path(ellipseIn: CGRect(x: sun.x - 6.5, y: sun.y - 6.5, width: 13, height: 13)), with: .color(Palette.gold))
        }
        .accessibilityElement()
        .accessibilityLabel(progress < 0 ? "সূর্যোদয়ের আগে" : progress > 1 ? "সূর্যাস্তের পরে"
                            : "দিনের \(Bangla.digits(Int(progress * 100)))% পার হয়েছে")
    }
}

struct SkyPage: View {
    let place: Place

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let sun = Sun.day(for: date, at: place)
            let moon = MoonPhase(date)
            let calendar = place.calendar
            ScrollView {
                VStack(spacing: 4) {
                    PageTitle(text: "সূর্য ও চাঁদ", color: Palette.gold, detail: place.name)
                    if let sun {
                        SunArc(progress: date.timeIntervalSince(sun.sunrise) / sun.daylight)
                            .frame(height: 74)
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Bangla.clock(sun.sunrise, calendar: calendar)).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.gold)
                                Text("সূর্যোদয়").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                            }
                            Spacer()
                            Text(Bangla.duration(sun.daylight)).font(.system(size: 10)).foregroundStyle(Color(white: 0.78))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Bangla.clock(sun.sunset, calendar: calendar)).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.coral)
                                Text("সূর্যাস্ত").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                            }
                        }
                        .padding(.horizontal, 5)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                MoonDisc(phase: moon).frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(moon.paksha) \(moon.tithiName)").font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                                    Text("\(Bangla.digits(Int((moon.illumination * 100).rounded())))% আলোকিত").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                }
                            }
                            HStack(spacing: 4) {
                                if let new = MoonPhase.next(.new, after: date) {
                                    moonChip("circle", "অমাবস্যা \(Bangla.gregorianDate(new, calendar: calendar))", Palette.silver)
                                }
                                if let full = MoonPhase.next(.full, after: date) {
                                    moonChip("circle.fill", "পূর্ণিমা \(Bangla.gregorianDate(full, calendar: calendar))", Palette.gold)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func moonChip(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 7))
            Text(text).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5).padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)))
    }
}

// MARK: - ৪ · ছুটি ও দিবস

struct HolidaysPage: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            let upcoming = Holidays.upcoming(from: date)
            let rest = Array(upcoming.dropFirst())
            let groups = Dictionary(grouping: rest) { Calendar.current.dateComponents([.year, .month], from: $0.start) }
                .sorted { ($0.key.year!, $0.key.month!) < ($1.key.year!, $1.key.month!) }
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    PageTitle(text: "ছুটি ও দিবস", color: Palette.red)

                    if let next = upcoming.first {
                        let days = next.daysAway(from: date)
                        let color = Color(rgb: next.rgb)
                        HStack(spacing: 7) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(days == 0 ? "আজ" : "পরের ছুটি").font(.system(size: 9, weight: .semibold)).foregroundStyle(color.opacity(0.85))
                                Text(next.name).font(.system(size: 16, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                                Text(next.dateText() + (next.moonDependent ? " · চাঁদ সাপেক্ষে" : ""))
                                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                            }
                            Spacer(minLength: 2)
                            if days > 0 {
                                VStack(spacing: 0) {
                                    Text(Bangla.digits(days)).font(.system(size: 30, weight: .bold)).foregroundStyle(color)
                                    Text("দিন বাকি").font(.system(size: 9)).foregroundStyle(color.opacity(0.85))
                                }
                            }
                        }
                        .padding(.horizontal, 11).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.16)))
                    }

                    ForEach(groups, id: \.key) { group in
                        Text(Bangla.gregorianMonths[group.key.month! - 1])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Palette.secondary)
                            .padding(.leading, 9).padding(.top, 3)
                        ForEach(group.value) { holiday in
                            row(holiday, days: holiday.daysAway(from: date))
                        }
                    }

                    Text("সূত্র: বাংলাদেশ সরকারের ছুটির তালিকা")
                        .font(.system(size: 9)).foregroundStyle(Palette.secondary).padding(.top, 4)
                }
            }
        }
    }

    private func row(_ holiday: Holiday, days: Int) -> some View {
        let color = Color(rgb: holiday.rgb)
        return HStack(spacing: 7) {
            Image(systemName: holiday.symbol).font(.system(size: 12)).foregroundStyle(color).frame(width: 15)
            VStack(alignment: .leading, spacing: 0) {
                Text(holiday.name).font(.system(size: 12, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text(holiday.dateText()
                     + (holiday.kind == .observance ? " · দিবস" : "")
                     + (holiday.moonDependent ? " · চাঁদ সাপেক্ষে" : ""))
                    .font(.system(size: 9)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 3)
            Text(days == 0 ? "আজ" : "\(Bangla.digits(days)) দিন").font(.system(size: 11, weight: .bold)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
    }
}

#Preview { DashboardView() }
