import SwiftUI

enum Route: Hashable { case wash, games, catchGame, flap }

struct PetView: View {
    @EnvironmentObject var store: PetStore
    @State private var munching = false
    @State private var falling: [UUID] = []
    private let clock = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        if let pet = store.pet {
            content(pet)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .wash: WashView()
                    case .games: GamesView()
                    case .catchGame: CatchGameView()
                    case .flap: FlapGameView()
                    }
                }
                .onReceive(clock) { _ in store.tick() }
        }
    }

    private func content(_ pet: Pet) -> some View {
        let mood = pet.mood
        return VStack(spacing: 4) {
            HStack(spacing: 5) {
                ForEach(Stat.allCases) { s in StatBar(stat: s, value: pet[s]) }
            }
            .padding(.horizontal, 4)

            GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            ZStack {
                // покачивание считается от времени, а не неявной анимацией: так размер цыпы не «анимируется» из нуля
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let speed = mood == .sleep ? 2.2 : (mood == .hungry || mood == .tired || mood == .bored ? 2.6 : 5.5)
                    let wave = sin(t * speed)
                    ChickView(look: pet.look, mood: munching ? .happy : mood, dirt: pet.dirt)
                        .frame(width: side, height: side)
                        .scaleEffect(x: mood == .sleep ? 1 + 0.02 * wave : 1, y: mood == .sleep ? 1 - 0.02 * wave : 1, anchor: .bottom)
                        .offset(y: mood == .sleep ? 0 : -3 - 3 * wave)
                        .rotationEffect(.degrees(munching ? -6 * sin(t * 30) : 0), anchor: .bottom)
                }
                if mood == .sleep { ZzzView() }
                if mood == .bored {
                    Text("…").font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 7).background(.white, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.trailing, 18)
                }
                ForEach(Array(falling.enumerated()), id: \.element) { i, id in
                    FallingGrain(delay: Double(i) * 0.15, x: CGFloat(i - 1) * 18)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
            }
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { h, _ in h * 0.46 }

            Text("\(Text(pet.name).bold()) \(mood.text)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7)

            HStack(spacing: 6) {
                ActionButton(symbol: "leaf.fill", color: Color(hex: 0xE9A400), label: "Покормить", needs: pet.hunger < PetStore.lowLevel, dim: pet.sleeping) {
                    if store.feed() { animateFeeding() }
                }
                NavAction(route: .wash, symbol: "drop.fill", color: .sky, label: "Помыть", needs: pet.clean < PetStore.lowLevel, sleeping: pet.sleeping)
                NavAction(route: .games, symbol: "gamecontroller.fill", color: .hot, label: "Поиграть", needs: pet.fun < PetStore.lowLevel, sleeping: pet.sleeping, tired: pet.energy < 15)
                ActionButton(symbol: pet.sleeping ? "sun.max.fill" : "moon.fill", color: .violet, label: pet.sleeping ? "Разбудить" : "Уложить спать", needs: !pet.sleeping && pet.energy < PetStore.lowLevel, dim: false) {
                    store.toggleSleep()
                }
            }
        }
        .padding(.horizontal, 4)
        .background(
            RadialGradient(colors: [pet.sleeping ? Color(hex: 0x1E1550) : Color(hex: 0x10306A), .black],
                           center: .init(x: 0.5, y: 0.58), startRadius: 0, endRadius: 140)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: pet.sleeping)
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Label("\(store.grains)", systemImage: "leaf.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yolk)
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("\(store.grains) зёрен")
            }
        }
    }

    private func animateFeeding() {
        falling = [UUID(), UUID(), UUID()]
        munching = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            falling = []
            munching = false
        }
    }
}

// MARK: - Элементы экрана

struct StatBar: View {
    let stat: Stat
    let value: Double
    @State private var blink = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: stat.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(stat.color)
            GeometryReader { g in
                Capsule().fill(.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(stat.color)
                            .frame(width: g.size.width * value / 100)
                            .opacity(value < PetStore.lowLevel && blink ? 0.35 : 1)
                    }
            }
            .frame(height: 5)
        }
        .animation(.easeInOut(duration: 0.4), value: value)
        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { blink = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title) \(Int(value)) из 100")
    }
}

struct ActionButton: View {
    let symbol: String
    let color: Color
    let label: String
    var needs = false
    var dim = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionIcon(symbol: symbol, color: color, needs: needs)
        }
        .buttonStyle(.plain)
        .opacity(dim ? 0.4 : 1)
        .accessibilityLabel(label)
    }
}

struct NavAction: View {
    @EnvironmentObject var store: PetStore
    let route: Route
    let symbol: String
    let color: Color
    let label: String
    var needs = false
    var sleeping = false
    var tired = false

    var body: some View {
        Group {
            if sleeping || tired {
                Button {
                    if let p = store.pet {
                        store.say(sleeping ? "Тсс, \(p.name) спит. Сначала разбудите" : "\(p.name) слишком устал для игр. Уложите спать", haptic: .failure)
                    }
                } label: { ActionIcon(symbol: symbol, color: color, needs: needs) }
            } else {
                NavigationLink(value: route) { ActionIcon(symbol: symbol, color: color, needs: needs) }
            }
        }
        .buttonStyle(.plain)
        .opacity(sleeping ? 0.4 : 1)
        .accessibilityLabel(label)
    }
}

struct ActionIcon: View {
    let symbol: String
    let color: Color
    var needs = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(color, in: Circle())
            .overlay(alignment: .topTrailing) {
                if needs {
                    Circle().fill(.white).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(color, lineWidth: 3))
                        .offset(x: 2, y: -2)
                }
            }
    }
}

struct ZzzView: View {
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Text(i == 2 ? "Z" : "z")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0xC9B8FF))
                    .offset(x: go ? 26 : 4, y: go ? -46 : -6)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8), value: go)
            }
        }
        .offset(x: 18, y: -10)
        .onAppear { go = true }
        .accessibilityHidden(true)
    }
}

struct FallingGrain: View {
    let delay: Double
    let x: CGFloat
    @State private var down = false
    var body: some View {
        Ellipse().fill(Color.yolk)
            .frame(width: 7, height: 10)
            .offset(x: x, y: down ? 0 : -60)
            .opacity(down ? 0 : 1)
            .onAppear { withAnimation(.easeIn(duration: 0.7).delay(delay)) { down = true } }
    }
}

struct ToastView: View {
    @EnvironmentObject var store: PetStore
    var body: some View {
        if let t = store.toast {
            Text(t)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color(hex: 0x26324A).opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 8).padding(.bottom, 42)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.25), value: store.toast)
                .allowsHitTesting(false)
        }
    }
}
