import SwiftUI
import UIKit

/// Full-screen flame burst that plays before Daily Fire, matching Flutter Hell Fire.
struct HellFireCanvas: View {
    var intensity: Double = 1.15
    var onFinished: () -> Void

    @State private var startedAt = Date()
    @State private var peaked = false
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            let progress = min(1.0, max(0.0, elapsed / 1.5))
            let phase = elapsed.truncatingRemainder(dividingBy: 0.52) / 0.52

            ZStack {
                Color.black.ignoresSafeArea()
                FlameCanvas(progress: progress, phase: phase, intensity: intensity)
                    .ignoresSafeArea()
                if progress > 0.22 && progress < 0.9 {
                    Text("BURN")
                        .font(.system(size: 64, weight: .heavy))
                        .tracking(10)
                        .foregroundStyle(Palette.gold)
                        .opacity(min(0.9, max(0.0, (progress - 0.22) / 0.35)))
                }
            }
        }
        .task {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try? await Task.sleep(for: .milliseconds(1_320))
            if !peaked {
                peaked = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            try? await Task.sleep(for: .milliseconds(400))
            if !finished {
                finished = true
                onFinished()
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct FlameCanvas: View {
    var progress: Double
    var phase: Double
    var intensity: Double

    var body: some View {
        Canvas { context, size in
            guard progress > 0 else { return }
            let scaled = min(1.2, max(0, progress * intensity))
            let flameCount = 48 + Int(scaled * 28)
            var rng = FlameRNG(seed: 123)

            for i in 0..<flameCount {
                let x = rng.nextDouble() * size.width
                let flameHeight = scaled * size.height * (1.35 + rng.nextDouble() * 0.45)
                let baseWidth = 64 + rng.nextDouble() * 140
                let speed = 0.75 + rng.nextDouble() * 0.7
                let t = progress * speed + Double(i) * 0.05 + phase * 6
                let flicker = sin(t * 18) * 0.16 + cos(t * 11 + Double(i)) * 0.1
                let height = flameHeight * (1 + flicker)
                let alpha = min(1, 0.78 * scaled)

                var outer = context
                outer.blendMode = .plusLighter
                outer.fill(
                    Self.tongue(
                        x: x,
                        floor: size.height,
                        width: baseWidth,
                        height: height,
                        inner: false
                    ),
                    with: .color(Self.lerp(Color(hex: 0xFF2A00), Color(hex: 0xFF8C00), Double(i) / Double(flameCount)).opacity(alpha))
                )

                var inner = context
                inner.blendMode = .plusLighter
                inner.fill(
                    Self.tongue(
                        x: x,
                        floor: size.height,
                        width: baseWidth,
                        height: height,
                        inner: true
                    ),
                    with: .color(Self.lerp(Palette.gold, .white, Double(i) / Double(flameCount)).opacity(min(1, 0.92 * scaled)))
                )

                let emberY = size.height - height * (0.55 + (phase + Double(i) * 0.03).truncatingRemainder(dividingBy: 0.45))
                let emberR = 2.2 + rng.nextDouble() * 2.4
                var ember = context
                ember.blendMode = .plusLighter
                ember.fill(
                    Path(ellipseIn: CGRect(
                        x: x + sin(t * 9) * 10 - emberR,
                        y: emberY - emberR,
                        width: emberR * 2,
                        height: emberR * 2
                    )),
                    with: .color(Palette.gold.opacity(0.55 * scaled))
                )
            }

            if progress > 0.88 {
                let flash = min(1, (progress - 0.88) * 8.5)
                var wash = context
                wash.blendMode = .plusLighter
                wash.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(flash)))
            }
        }
    }

    private static func tongue(x: Double, floor: Double, width: Double, height: Double, inner: Bool) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: x, y: floor))
        if inner {
            path.addQuadCurve(
                to: CGPoint(x: x - width / 8, y: floor - height * 0.9),
                control: CGPoint(x: x - width / 4, y: floor - height * 0.6)
            )
            path.addQuadCurve(
                to: CGPoint(x: x + width / 8, y: floor - height * 0.9),
                control: CGPoint(x: x, y: floor - height * 1.12)
            )
            path.addQuadCurve(
                to: CGPoint(x: x, y: floor),
                control: CGPoint(x: x + width / 4, y: floor - height * 0.6)
            )
        } else {
            path.addQuadCurve(
                to: CGPoint(x: x - width / 5, y: floor - height),
                control: CGPoint(x: x - width / 2, y: floor - height * 0.7)
            )
            path.addQuadCurve(
                to: CGPoint(x: x + width / 5, y: floor - height),
                control: CGPoint(x: x, y: floor - height * 1.28)
            )
            path.addQuadCurve(
                to: CGPoint(x: x, y: floor),
                control: CGPoint(x: x + width / 2, y: floor - height * 0.7)
            )
        }
        path.closeSubpath()
        return path
    }

    private static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let clamped = min(1, max(0, t))
        let ua = UIColor(a)
        let ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: ar + (br - ar) * clamped,
            green: ag + (bg - ag) * clamped,
            blue: ab + (bb - ab) * clamped,
            opacity: aa + (ba - aa) * clamped
        )
    }
}

private struct FlameRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
