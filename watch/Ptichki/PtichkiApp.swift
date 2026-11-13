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
    @State private var path: [Route] = DebugLaunch.route.map { [$0] } ?? []

    var body: some View {
        Group {
            if store.pet == nil {
                EggView()
            } else if store.justHatched {
                HatchView()
            } else {
                NavigationStack(path: $path) {
                    PetView()
                }
            }
        }
        .overlay(alignment: .bottom) { ToastView() }
    }
}

/// Параметры запуска для отладки в симуляторе, например:
/// `-demoPet petya -skipHours 9 -route wash` (только в Debug-сборке).
enum DebugLaunch {
    static func value(_ key: String) -> String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: key), i + 1 < args.count { return args[i + 1] }
        #endif
        return nil
    }
    static var route: Route? {
        switch value("-route") {
        case "wash": .wash
        case "games": .games
        case "catch": .catchGame
        case "flap": .flap
        default: nil
        }
    }
}
