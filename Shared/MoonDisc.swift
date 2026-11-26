import SwiftUI

/// A moon disc lit to the current phase (northern-hemisphere view:
/// waxing is lit on the right, waning on the left).
struct MoonDisc: View {
    let phase: MoonPhase
    var lit = Color(red: 1.0, green: 0.96, blue: 0.82)
    var dark = Color(white: 0.24) // must be opaque: it covers the lit half for crescents

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let k = phase.illumination
            let terminatorWidth = size * abs(1 - 2 * k)
            ZStack {
                Circle().fill(dark)
                // Lit half.
                Circle().fill(lit)
                    .mask(HStack(spacing: 0) {
                        Color.clear
                        Color.black
                    })
                // Terminator: a crescent eats into the lit half, a gibbous moon spills past it.
                Ellipse()
                    .fill(k < 0.5 ? dark : lit)
                    .frame(width: terminatorWidth, height: size)
                if k < 0.5 {
                    // Re-draw the dark half's edge so the crescent keeps a clean outline.
                    Circle().fill(dark)
                        .mask(HStack(spacing: 0) {
                            Color.black
                            Color.clear
                        })
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .scaleEffect(x: phase.isWaxing ? 1 : -1, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
