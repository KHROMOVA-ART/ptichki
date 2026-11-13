import SwiftUI

/// «Над забором»: тап — взмах крыльями, пролетайте между досками.
final class FlapEngine: ObservableObject {
    enum Mode { case ready, play, over }

    @Published private(set) var mode: Mode = .ready
    @Published private(set) var score = 0

    struct Post { var x: CGFloat; var gapY: CGFloat; var passed = false }

    var size: CGSize = .zero { didSet { if oldValue == .zero { reset() } } }
    private(set) var y: CGFloat = 0
    private(set) var vy: CGFloat = 0
    private(set) var posts: [Post] = []
    private(set) var flapT: Double = 0
    private(set) var t: Double = 0
    private var last: Date?

    let birdX: CGFloat = 44
    let r: CGFloat = 9
    let postW: CGFloat = 24
    let ground: CGFloat = 14
    var gap: CGFloat { max(64, size.height * 0.36) }
    var spacing: CGFloat { 104 }

    func reset() {
        mode = .ready; score = 0; vy = 0; t = 0; last = nil
        y = size.height / 2 - 10
        posts = []
        addPost(x: size.width + 30)
        addPost(x: size.width + 30 + spacing)
    }

    private func addPost(x: CGFloat) {
        let maxY = max(34, size.height - ground - gap - 26)
        posts.append(Post(x: x, gapY: .random(in: 30...maxY)))
    }

    func flap() {
        switch mode {
        case .over: return
        case .ready: mode = .play; fallthrough
        case .play: vy = -4.3; flapT = 0.14
        }
    }

    /// Шаг физики. Скорости заданы на кадр 60 fps и пересчитываются по реальному времени.
    func step(now: Date) -> Bool {
        let dt = min(0.05, now.timeIntervalSince(last ?? now))
        last = now
        let f = CGFloat(dt * 60)
        t += dt
        flapT = max(0, flapT - dt)
        switch mode {
        case .ready:
            y = size.height / 2 - 10 + sin(t * 6) * 5
        case .play:
            vy += 0.27 * f
            y += vy * f
            for i in posts.indices {
                posts[i].x -= 1.7 * f
                if !posts[i].passed && posts[i].x + postW < birdX {
                    posts[i].passed = true
                    score += 1
                    WKInterfaceDeviceHaptic.click()
                }
            }
            if let first = posts.first, first.x < -postW - 6 {
                posts.removeFirst()
                addPost(x: (posts.last?.x ?? size.width) + spacing)
            }
            var hit = y > size.height - ground - r || y < r
            for p in posts where birdX + r > p.x - 3 && birdX - r < p.x + postW + 3 {
                if y - r < p.gapY || y + r > p.gapY + gap { hit = true }
            }
            if hit { mode = .over; return true }
        case .over:
            break
        }
        return false
    }
}

struct FlapGameView: View {
    @EnvironmentObject var store: PetStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var game = FlapEngine()
    @State private var gain = 0
    @State private var record = false

    var body: some View {
        let look = store.pet?.look ?? Look.by("pushok")
        GeometryReader { g in
            TimelineView(.animation(paused: game.mode == .over)) { tl in
                Canvas { ctx, size in
                    draw(ctx: &ctx, size: size, look: look)
                }
                .onChange(of: tl.date) { _, now in
                    if game.step(now: now) { finish() }
                }
            }
            .onAppear { game.size = g.size }
        }
        .contentShape(Rectangle())
        .onTapGesture { game.flap() }
        .overlay(alignment: .top) {
            Text("\(game.score)")
                .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .ink.opacity(0.35), radius: 0, y: 2)
                .padding(.top, 2)
        }
        .overlay(alignment: .bottom) {
            if game.mode == .ready {
                Text("Тапните, чтобы взлететь")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.ink.opacity(0.55), in: Capsule())
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if game.mode == .over {
                VStack(spacing: 6) {
                    Text("\(game.score)").font(.system(size: 34, weight: .black, design: .rounded))
                    Text((record ? "Новый рекорд! " : "") + "+\(gain) радости")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    HStack {
                        Button("Ещё") { record = false; game.reset() }
                        Button("Готово") { dismiss() }.tint(.yolk)
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.55))
            }
        }
        .navigationTitle("Над забором")
        .navigationBarBackButtonHidden(game.mode == .play)
        .accessibilityLabel("Игра: тапайте, чтобы цыпа взмахнула крыльями")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private func finish() {
        WKInterfaceDevice.current().play(.failure)
        gain = min(60, 6 + game.score * 8)
        record = game.score > store.flapBest && game.score > 0
        if record { store.flapBest = game.score }
        store.finishGame(fun: Double(gain), energy: 10, grainsWon: 0)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, look: Look) {
        let W = size.width, H = size.height
        // небо и облака
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [.sky, Color(hex: 0xBFE3FF)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
        let cx = CGFloat(game.t * 18).truncatingRemainder(dividingBy: W + 60)
        ctx.fill(Path(ellipseIn: CGRect(x: W - cx + 8, y: 32, width: 44, height: 16)), with: .color(.white.opacity(0.7)))
        ctx.fill(Path(ellipseIn: CGRect(x: (W - cx + 100).truncatingRemainder(dividingBy: W + 60) - 48, y: 84, width: 36, height: 12)), with: .color(.white.opacity(0.7)))
        // забор
        for p in game.posts {
            let top = p.gapY, bot = p.gapY + game.gap
            ctx.fill(Path(CGRect(x: p.x, y: 0, width: game.postW, height: top)), with: .color(Color(hex: 0xC88A4E)))
            ctx.fill(Path(CGRect(x: p.x, y: bot, width: game.postW, height: H - game.ground - bot)), with: .color(Color(hex: 0xC88A4E)))
            ctx.fill(Path(CGRect(x: p.x - 3, y: top - 8, width: game.postW + 6, height: 8)), with: .color(Color(hex: 0x9C6435)))
            ctx.fill(Path(CGRect(x: p.x - 3, y: bot, width: game.postW + 6, height: 8)), with: .color(Color(hex: 0x9C6435)))
            ctx.fill(Path(CGRect(x: p.x + 4, y: 0, width: 3, height: max(0, top - 8))), with: .color(.white.opacity(0.18)))
        }
        // трава
        ctx.fill(Path(CGRect(x: 0, y: H - game.ground, width: W, height: game.ground)), with: .color(Color(hex: 0x3FB56A)))
        let off = game.mode == .play ? CGFloat(game.t * 102).truncatingRemainder(dividingBy: 10) : 0
        var x = -off
        while x < W { ctx.fill(Path(CGRect(x: x, y: H - game.ground, width: 5, height: 4)), with: .color(Color(hex: 0x2E9455))); x += 10 }
        // цыпа
        var b = ctx
        b.translateBy(x: game.birdX, y: game.y)
        b.rotate(by: .radians(Double(max(-0.5, min(1.1, game.vy / 7)))))
        b.fill(Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20)), with: .color(look.body))
        if let comb = look.comb {
            b.fill(Path(ellipseIn: CGRect(x: -2.2, y: -13.2, width: 6.4, height: 6.4)), with: .color(comb))
            b.fill(Path(ellipseIn: CGRect(x: 2, y: -12, width: 6, height: 6)), with: .color(comb))
        }
        var beak = Path(); beak.move(to: CGPoint(x: 9, y: -2)); beak.addLine(to: CGPoint(x: 16, y: 1)); beak.addLine(to: CGPoint(x: 9, y: 4)); beak.closeSubpath()
        b.fill(beak, with: .color(look.beak))
        b.fill(Path(ellipseIn: CGRect(x: 2.6, y: -4.9, width: 3.8, height: 3.8)), with: .color(.ink))
        var w = b
        let up = game.flapT > 0
        w.translateBy(x: -3, y: up ? -4 : 3)
        w.rotate(by: .radians(up ? -0.6 : 0.3))
        w.fill(Path(ellipseIn: CGRect(x: -6.5, y: -3.6, width: 13, height: 7.2)), with: .color(look.wing))
    }
}

import WatchKit
