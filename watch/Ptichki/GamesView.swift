import SwiftUI

struct GamesView: View {
    @EnvironmentObject var store: PetStore

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(value: Route.catchGame) {
                    GameTile(title: "лови зёрна", subtitle: "Тапайте зёрна и червяков. Пойманные зёрна — в копилку",
                             colors: [Color(hex: 0xE9A400), Color(hex: 0xFF7A1A)])
                }
                NavigationLink(value: Route.flap) {
                    GameTile(title: "над забором",
                             subtitle: "Тап — взмах крыльями" + (store.flapBest > 0 ? " · рекорд \(store.flapBest)" : ""),
                             colors: [.sky, Color(hex: 0x3FB56A)])
                }
                #if DEBUG
                Button("Промотать 3 часа") { store.skip(hours: 3) }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                #endif
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Игры")
    }
}

struct GameTile: View {
    let title: String
    let subtitle: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 16, weight: .black, design: .rounded))
            Text(subtitle).font(.system(size: 11, weight: .medium, design: .rounded)).opacity(0.88)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .bottomLeading)
        .padding(12)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Лови зёрна

struct CatchGameView: View {
    @EnvironmentObject var store: PetStore
    @Environment(\.dismiss) private var dismiss
    @State private var targets: [Target] = []
    @State private var score = 0
    @State private var caught = 0
    @State private var left = 10
    @State private var over = false
    @State private var gain = 0
    private let spawnTimer = Timer.publish(every: 0.62, on: .main, in: .common).autoconnect()
    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    struct Target: Identifiable {
        let id = UUID()
        let x: Double, y: Double
        let worm: Bool
        let born = Date()
        var lifetime: Double { worm ? 0.8 : 1.1 }
    }

    var body: some View {
        GeometryReader { g in
            ZStack {
                RadialGradient(colors: [Color(hex: 0x3A1A0A), .black], center: .center, startRadius: 0, endRadius: 140)
                ForEach(targets) { t in
                    Button { hit(t) } label: {
                        Circle()
                            .fill(RadialGradient(colors: t.worm ? [Color(hex: 0xFFC0CB), Color(hex: 0xE2456A)] : [Color(hex: 0xFFE7A1), Color(hex: 0xE9A400)],
                                                 center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: 20))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .position(x: t.x * g.size.width, y: t.y * g.size.height)
                    .transition(.scale)
                    .accessibilityLabel(t.worm ? "Червяк" : "Зерно")
                }
                if over { endCard }
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Text("\(score) \(plural(score, "очко", "очка", "очков"))")
                Spacer()
                Text("\(left) с")
            }
            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            .padding(.horizontal, 12)
            .opacity(over ? 0 : 1)
        }
        .navigationTitle("Лови зёрна")
        .navigationBarBackButtonHidden(!over)
        .onReceive(spawnTimer) { _ in
            guard !over else { return }
            let now = Date()
            withAnimation(.easeOut(duration: 0.2)) {
                targets.removeAll { now.timeIntervalSince($0.born) > $0.lifetime }
                targets.append(Target(x: .random(in: 0.14...0.86), y: .random(in: 0.2...0.86), worm: .random(in: 0...1) < 0.2))
            }
        }
        .onReceive(secondTimer) { _ in
            guard !over else { return }
            left -= 1
            if left <= 0 { finish() }
        }
    }

    private var endCard: some View {
        VStack(spacing: 6) {
            Text("\(score)").font(.system(size: 34, weight: .black, design: .rounded))
            Text("+\(gain) радости · +\(caught) \(plural(caught, "зерно", "зерна", "зёрен"))")
                .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            HStack {
                Button("Ещё") { restart() }
                Button("Готово") { dismiss() }.tint(.yolk)
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 8)
    }

    private func hit(_ t: Target) {
        guard !over else { return }
        score += t.worm ? 3 : 1
        if !t.worm { caught += 1 }
        WKInterfaceDeviceHaptic.click()
        withAnimation(.easeOut(duration: 0.15)) { targets.removeAll { $0.id == t.id } }
    }

    private func finish() {
        over = true
        targets = []
        gain = min(60, score * 5)
        store.finishGame(fun: Double(gain), energy: 8, grainsWon: caught)
        WKInterfaceDeviceHaptic.success()
    }

    private func restart() {
        score = 0; caught = 0; left = 10; gain = 0; over = false
    }
}

func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n10 = n % 10, n100 = n % 100
    if n10 == 1 && n100 != 11 { return one }
    if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
    return many
}

import WatchKit
enum WKInterfaceDeviceHaptic {
    static func click() { WKInterfaceDevice.current().play(.click) }
    static func success() { WKInterfaceDevice.current().play(.success) }
    static func failure() { WKInterfaceDevice.current().play(.failure) }
}
