import SwiftUI

@main
struct PtichkiApp: App {
    @StateObject private var store = PetStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.tick() }
                    if phase == .background { store.save(); store.scheduleReminders() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: PetStore

    var body: some View {
        Group {
            if store.pet == nil {
                EggView()
            } else if store.justHatched {
                HatchView()
            } else {
                NavigationStack {
                    PetView()
                }
            }
        }
        .overlay(alignment: .bottom) { ToastView() }
    }
}
