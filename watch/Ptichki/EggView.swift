import SwiftUI

struct EggShape: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0xFFF6E0))
            Ellipse().fill(.white).frame(width: 14, height: 24).offset(x: -12, y: -14)
            Circle().fill(Color(hex: 0xF1DDB0)).frame(width: 8).offset(x: 12, y: 14)
            Circle().fill(Color(hex: 0xF1DDB0)).frame(width: 6).offset(x: -8, y: 22)
        }
        .frame(width: 64, height: 80)
    }
}

/// Пока на iPhone ничего не куплено: яйцо ждёт.
struct EggView: View {
    @EnvironmentObject var store: PetStore
    @State private var wobble = false
    @State private var choosing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                EggShape()
                    .rotationEffect(.degrees(wobble ? 7 : -7), anchor: .bottom)
                    .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: wobble)
                    .padding(.top, 6)
                    .onAppear { wobble = true }
                Text("тут будет цыпа")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text("Купите мерч в приложении «Птички» на iPhone, и из него вылупится цыпа")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                Button("Вылупить цыпу") { choosing = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.sky)
                    .padding(.top, 4)
                Text("Синхронизации с iPhone пока нет: выберите цыпу вручную")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 6)
        }
        .background(RadialGradient(colors: [Color(hex: 0x12397A), .black], center: .center, startRadius: 0, endRadius: 140).ignoresSafeArea())
        .sheet(isPresented: $choosing) {
            List(Look.all) { look in
                Button {
                    choosing = false
                    store.adopt(look)
                } label: {
                    HStack(spacing: 10) {
                        ChickView(look: look, mood: .happy).frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(look.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(look.item).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Что купили?")
        }
    }
}

/// Яйцо трескается, появляется цыпа.
struct HatchView: View {
    @EnvironmentObject var store: PetStore
    @State private var crack = false
    @State private var born = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x12397A), .black], center: .center, startRadius: 0, endRadius: 140).ignoresSafeArea()
            EggShape()
                .rotationEffect(.degrees(crack ? 12 : -12), anchor: .bottom)
                .animation(.easeInOut(duration: 0.12).repeatCount(6, autoreverses: true), value: crack)
                .scaleEffect(born ? 1.6 : 1)
                .opacity(born ? 0 : 1)
            if born, let pet = store.pet {
                VStack(spacing: 6) {
                    ChickView(look: pet.look, mood: .happy).frame(width: 100, height: 100)
                    Text("привет, я \(pet.name.lowercased())!")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    Button("Привет!") { store.justHatched = false }
                        .buttonStyle(.borderedProminent)
                        .tint(.sky)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            crack = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { born = true }
            }
        }
    }
}
