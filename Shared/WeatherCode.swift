import SwiftUI

/// WMO weather codes (as used by Open-Meteo) in Bangla, shared by the app and complications.
enum WeatherCode {
    static func describe(_ code: Int, isDay: Bool) -> (text: String, symbol: String) {
        switch code {
        case 0: ("পরিষ্কার", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2: ("আংশিক মেঘলা", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: ("মেঘলা", "cloud.fill")
        case 45, 48: ("কুয়াশা", "cloud.fog.fill")
        case 51...57: ("গুঁড়ি বৃষ্টি", "cloud.drizzle.fill")
        case 61...67, 80...82: ("বৃষ্টি", "cloud.rain.fill")
        case 71...77, 85, 86: ("তুষার", "snowflake")
        case 95...99: ("বজ্রঝড়", "cloud.bolt.rain.fill")
        default: ("আবহাওয়া", "cloud.sun.fill")
        }
    }

    /// Cool blue through green and gold to hot red.
    static func color(for celsius: Double) -> Color {
        switch celsius {
        case ..<15: Color(red: 0.45, green: 0.7, blue: 1.0)
        case ..<22: Color(red: 0.35, green: 0.85, blue: 0.85)
        case ..<28: Color(red: 0.4, green: 0.9, blue: 0.5)
        case ..<32: Color(red: 1.0, green: 0.82, blue: 0.25)
        case ..<36: Color(red: 1.0, green: 0.55, blue: 0.2)
        default: Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    /// "২৬°"
    static func degrees(_ celsius: Double) -> String { Bangla.digits(Int(celsius.rounded())) + "°" }
}

/// Dashboard pages in the app. Complications deep-link to these with `ponjika://<page>`.
enum AppPage: String, CaseIterable, Hashable {
    case today, weather, sky, days

    var url: URL { URL(string: "ponjika://\(rawValue)")! }
}

extension Color {
    /// Builds a colour from the (r, g, b) tuples used by the Bangla helpers.
    init(rgb: (Double, Double, Double)) { self.init(red: rgb.0, green: rgb.1, blue: rgb.2) }
}
