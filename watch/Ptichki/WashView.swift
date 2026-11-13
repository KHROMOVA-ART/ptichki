import SwiftUI

/// Мойка: трите цыпу пальцем — летят пузыри, грязь исчезает.
struct WashView: View {
    @EnvironmentObject var store: PetStore
    @Environment(\.dismiss) private var dismiss
    @State private var bubbles: [Bubble] = []
    @State private var lastRub = Date.distantPast
    @State private var done = false

    struct Bubble: Identifiable { let id = UUID(); let at: CGPoint; let size: CGFloat }

    var body: some View {
        if let pet = store.pet {
            VStack(spacing: 6) {
                ZStack {
                    ChickView(look: pet.look, mood: pet.clean > 80 ? .happy : .ok, dirt: pet.dirt)
                        .padding(10)
                    ForEach(bubbles) { b in BubbleView(size: b.size).position(b.at) }
                    if done {
                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in rub(at: v.location, amount: 2.2) })
                .accessibilityAddTraits(.allowsDirectInteraction)

                ProgressView(value: pet.clean, total: 100)
                    .tint(.white)
                    .padding(.horizontal, 20)

                Button("Потереть") {
                    for _ in 0..<5 { rub(at: CGPoint(x: .random(in: 50...130), y: .random(in: 20...100)), amount: 4) }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .buttonStyle(.bordered)
            }
            .background(LinearGradient(colors: [Color(hex: 0x0B3A8C), .sky], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .navigationTitle("Мойка")
            .onAppear {
                if pet.clean >= 95 {
                    store.say("\(pet.name) и так чистый")
                    dismiss()
                }
            }
        }
    }

    private func rub(at point: CGPoint, amount: Double) {
        guard !done, let pet = store.pet else { return }
        let now = Date()
        guard now.timeIntervalSince(lastRub) > 0.035 else { return }
        lastRub = now
        store.rub(amount)
        let b = Bubble(at: point, size: .random(in: 8...22))
        bubbles.append(b)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { bubbles.removeAll { $0.id == b.id } }
        if pet.clean + amount >= 100 {
            done = true
            withAnimation(.spring) {}
            store.save()
            store.say("\(pet.name) сияет! Чистюля", haptic: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
        }
    }
}

struct BubbleView: View {
    let size: CGFloat
    @State private var up = false
    var body: some View {
        Circle()
            .fill(.white.opacity(0.18))
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
            .frame(width: size, height: size)
            .scaleEffect(up ? 1.3 : 1)
            .offset(y: up ? -30 : 0)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.2)) { up = true } }
            .allowsHitTesting(false)
    }
}
