import SwiftUI

/// Цыпа, нарисованная в системе координат 200×200 (как в веб-версии).
struct ChickView: View {
    let look: Look
    var mood: Mood = .ok
    var dirt: Double = 0          // 0…1

    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 200
            ctx.translateBy(x: (size.width - 200 * k) / 2, y: (size.height - 200 * k) / 2)
            ctx.scaleBy(x: k, y: k)
            draw(&ctx)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(look.name), \(mood.text)")
    }

    private func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private func gradient(_ rect: CGRect) -> GraphicsContext.Shading {
        .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.55), location: 0),
                .init(color: look.body, location: 0.35),
                .init(color: look.shade, location: 1)
            ]),
            center: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.3),
            startRadius: 0, endRadius: max(rect.width, rect.height) * 0.75)
    }

    private func draw(_ ctx: inout GraphicsContext) {
        let ink = Color.ink
        // тень
        ctx.fill(ellipse(100, 188, 50, 7), with: .color(ink.opacity(0.12)))
        // лапки
        var legs = Path()
        legs.move(to: .init(x: 86, y: 168)); legs.addLine(to: .init(x: 86, y: 184))
        legs.move(to: .init(x: 80, y: 184)); legs.addLine(to: .init(x: 92, y: 184))
        legs.move(to: .init(x: 114, y: 168)); legs.addLine(to: .init(x: 114, y: 184))
        legs.move(to: .init(x: 108, y: 184)); legs.addLine(to: .init(x: 120, y: 184))
        ctx.stroke(legs, with: .color(look.beak == .ink ? Color.hot : look.beak), style: .init(lineWidth: 5, lineCap: .round))
        // хвост
        if let tail = look.tail {
            var t = Path()
            t.move(to: .init(x: 40, y: 112)); t.addLine(to: .init(x: 14, y: 82)); t.addLine(to: .init(x: 24, y: 116))
            t.addLine(to: .init(x: 8, y: 106)); t.addLine(to: .init(x: 32, y: 138)); t.closeSubpath()
            ctx.fill(t, with: .color(tail))
        }
        // тело, брюшко, голова
        let bodyRect = CGRect(x: 42, y: 80, width: 116, height: 96)
        ctx.fill(Path(ellipseIn: bodyRect), with: gradient(bodyRect))
        ctx.fill(ellipse(106, 142, 32, 26), with: .color(look.belly.opacity(0.9)))
        let headRect = CGRect(x: 83, y: 37, width: 70, height: 70)
        ctx.fill(Path(ellipseIn: headRect), with: gradient(headRect))
        // гребешок
        if let comb = look.comb {
            ctx.fill(ellipse(106, 40, 9, 9), with: .color(comb))
            ctx.fill(ellipse(118, 34, 10, 10), with: .color(comb))
            ctx.fill(ellipse(130, 40, 9, 9), with: .color(comb))
            var w = Path()
            w.move(to: .init(x: 146, y: 90))
            w.addQuadCurve(to: .init(x: 142, y: 104), control: .init(x: 150, y: 102))
            w.addQuadCurve(to: .init(x: 146, y: 90), control: .init(x: 136, y: 98))
            ctx.fill(w, with: .color(comb))
        }
        // клюв
        var beak = Path()
        beak.move(to: .init(x: 149, y: 68))
        beak.addQuadCurve(to: .init(x: 149, y: 88), control: .init(x: 174, y: 76))
        beak.closeSubpath()
        ctx.fill(beak, with: .color(look.beak))
        // глаза по настроению
        drawEyes(&ctx)
        // румянец
        ctx.fill(ellipse(128, 85, 7, 4), with: .color(Color(hex: 0xFF7A8A).opacity(0.45)))
        // крыло
        var wing = Path()
        wing.move(to: .init(x: 58, y: 118))
        wing.addQuadCurve(to: .init(x: 104, y: 122), control: .init(x: 80, y: 102))
        wing.addQuadCurve(to: .init(x: 66, y: 142), control: .init(x: 94, y: 148))
        wing.addQuadCurve(to: .init(x: 58, y: 118), control: .init(x: 56, y: 136))
        ctx.fill(wing, with: .color(look.wing))
        // грязь
        if dirt > 0 {
            let mud = Color(hex: 0x8A6A45).opacity(min(1, dirt))
            for (x, y, rx, ry) in [(78.0, 150.0, 9.0, 6.0), (128, 160, 7, 5), (104, 98, 5, 5), (140, 122, 6, 4), (66, 128, 4, 4)] {
                ctx.fill(ellipse(x, y, rx, ry), with: .color(mud))
            }
        }
    }

    private func drawEyes(_ ctx: inout GraphicsContext) {
        let ink = Color.ink
        let line = StrokeStyle(lineWidth: 4, lineCap: .round)
        switch mood {
        case .happy:
            var p = Path(); p.move(to: .init(x: 124, y: 68)); p.addQuadCurve(to: .init(x: 138, y: 68), control: .init(x: 131, y: 58))
            ctx.stroke(p, with: .color(ink), style: line)
        case .sleep:
            var p = Path(); p.move(to: .init(x: 124, y: 66)); p.addQuadCurve(to: .init(x: 138, y: 66), control: .init(x: 131, y: 72))
            ctx.stroke(p, with: .color(ink), style: line)
        case .hungry:
            ctx.fill(ellipse(131, 68, 5.5, 6.5), with: .color(ink))
            ctx.fill(ellipse(133, 65.5, 2, 2), with: .color(.white))
            var brow = Path(); brow.move(to: .init(x: 122, y: 54)); brow.addLine(to: .init(x: 138, y: 60))
            ctx.stroke(brow, with: .color(ink), style: .init(lineWidth: 3.5, lineCap: .round))
            var tear = Path(); tear.move(to: .init(x: 128, y: 78))
            tear.addQuadCurve(to: .init(x: 128, y: 87), control: .init(x: 125, y: 84))
            tear.addQuadCurve(to: .init(x: 128, y: 78), control: .init(x: 131, y: 84))
            ctx.fill(tear, with: .color(Color(hex: 0x6EC3FF)))
        case .bored, .tired:
            var p = Path(); p.move(to: .init(x: 124, y: 66)); p.addLine(to: .init(x: 138, y: 66))
            ctx.stroke(p, with: .color(ink), style: line)
            ctx.fill(ellipse(131, 69, 5, 3), with: .color(ink))
        case .ok, .dirty:
            ctx.fill(ellipse(131, 66, 6, 7), with: .color(ink))
            ctx.fill(ellipse(133, 63, 2.2, 2.2), with: .color(.white))
        }
    }
}

extension Pet {
    /// Насколько видна грязь: появляется, когда чистота ниже 55.
    var dirt: Double { clean < 55 ? 0.25 + 0.75 * (1 - clean / 55) : 0 }
}

#Preview {
    ChickView(look: Look.by("petya"), mood: .happy)
        .frame(width: 150, height: 150)
        .background(Color.black)
}
