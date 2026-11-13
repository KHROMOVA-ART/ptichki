import SwiftUI
import WatchKit
import UserNotifications

// MARK: - Внешний вид цыпы (зависит от купленного мерча)

struct Look: Identifiable {
    let id: String
    let name: String
    let item: String
    var body = Color(hex: 0xFFD24A)
    var shade = Color(hex: 0xF2A400)
    var belly = Color(hex: 0xFFF0B3)
    var wing = Color(hex: 0xF7B21C)
    var beak = Color(hex: 0xFF8A1F)
    var comb: Color? = Color(hex: 0xFF4436)
    var tail: Color? = nil

    static let all: [Look] = [
        Look(id: "flamingo", name: "Фламинго", item: "Футболка oversize",
             body: Color(hex: 0xFFA3C4), shade: Color(hex: 0xF25C8E), belly: Color(hex: 0xFFE3EE),
             wing: Color(hex: 0xF25C8E), beak: Color(hex: 0x0E1B33), comb: nil),
        Look(id: "pushok", name: "Пушок", item: "Плюшевая цыпа", comb: nil),
        Look(id: "petya", name: "Петя", item: "Кружка «Петух»",
             body: Color(hex: 0xE2563B), shade: Color(hex: 0xA8301E), belly: Color(hex: 0xF7A877),
             wing: Color(hex: 0x8E2E1F), tail: Color(hex: 0x2E8B63)),
        Look(id: "ryaba", name: "Ряба", item: "Шоппер из хлопка",
             body: Color(hex: 0xF1ECE2), shade: Color(hex: 0xC9BDA6), belly: .white, wing: Color(hex: 0xB4A68E)),
        Look(id: "gosha", name: "Гоша", item: "Носки «Лапки»",
             body: Color(hex: 0x8A6650), shade: Color(hex: 0x4F3729), belly: Color(hex: 0xC29F80),
             wing: Color(hex: 0x4A3328), tail: Color(hex: 0xD6993F)),
        Look(id: "nesushka", name: "Несушка", item: "Брелок «Яичко»",
             body: .white, shade: Color(hex: 0xD9DDE6), belly: Color(hex: 0xFFF3D6), wing: Color(hex: 0xE3DCCB)),
        Look(id: "bro", name: "Бройлер Бро", item: "Футболка «птиц»")
    ]

    static func by(_ id: String) -> Look { all.first { $0.id == id } ?? all[1] }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
    static let ink = Color(hex: 0x0E1B33)
    static let sky = Color(hex: 0x1E8BFF)
    static let skyLight = Color(hex: 0x5DB6FF)
    static let yolk = Color(hex: 0xFFC93C)
    static let hot = Color(hex: 0xFF4436)
    static let violet = Color(hex: 0x7A5CFF)
}

// MARK: - Питомец

enum Stat: String, CaseIterable, Identifiable {
    case hunger, clean, fun, energy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hunger: "сытость"
        case .clean: "чистота"
        case .fun: "радость"
        case .energy: "энергия"
        }
    }
    var color: Color {
        switch self {
        case .hunger: .yolk
        case .clean: .skyLight
        case .fun: Color(hex: 0xFF6B5E)
        case .energy: Color(hex: 0xA98BFF)
        }
    }
    var symbol: String {
        switch self {
        case .hunger: "leaf.fill"
        case .clean: "drop.fill"
        case .fun: "heart.fill"
        case .energy: "bolt.fill"
        }
    }
    /// Сколько пунктов в час теряется, пока цыпа не спит.
    var ratePerHour: Double {
        switch self {
        case .hunger: 6
        case .clean: 4
        case .fun: 5
        case .energy: 3
        }
    }
    var alert: String {
        switch self {
        case .hunger: "проголодался, покормите"
        case .clean: "испачкался, пора мыться"
        case .fun: "скучает, поиграйте с ним"
        case .energy: "устал, уложите спать"
        }
    }
}

enum Mood {
    case happy, ok, hungry, dirty, bored, tired, sleep

    var text: String {
        switch self {
        case .happy: "счастлив"
        case .ok: "всё хорошо"
        case .hungry: "проголодался"
        case .dirty: "испачкался"
        case .bored: "скучает"
        case .tired: "устал, хочет спать"
        case .sleep: "спит"
        }
    }
}

struct Pet: Codable {
    var lookID: String
    var hunger: Double = 70
    var clean: Double = 85
    var fun: Double = 60
    var energy: Double = 80
    var sleeping = false
    var born = Date()
    var updated = Date()

    var look: Look { Look.by(lookID) }
    var name: String { look.name }

    subscript(stat: Stat) -> Double {
        get {
            switch stat {
            case .hunger: hunger
            case .clean: clean
            case .fun: fun
            case .energy: energy
            }
        }
        set {
            let v = min(100, max(0, newValue))
            switch stat {
            case .hunger: hunger = v
            case .clean: clean = v
            case .fun: fun = v
            case .energy: energy = v
            }
        }
    }

    var mood: Mood {
        if sleeping { return .sleep }
        let low = Stat.allCases.min { self[$0] < self[$1] }!
        if self[low] >= 65 { return .happy }
        if self[low] >= 40 { return .ok }
        switch low {
        case .hunger: return .hungry
        case .clean: return .dirty
        case .fun: return .bored
        case .energy: return .tired
        }
    }
}

// MARK: - Хранилище

@MainActor
final class PetStore: ObservableObject {
    @Published var pet: Pet?
    @Published var grains: Int = 40
    @Published var flapBest: Int = 0
    @Published var justHatched = false
    @Published var toast: String?

    private let key = "ptichki.watch.v1"
    static let feedCost = 10
    static let lowLevel = 35.0

    init() {
        load()
        tick()
        #if DEBUG
        if let id = DebugLaunch.value("-demoPet") {
            pet = id == "none" ? nil : Pet(lookID: id)
        }
        if let h = DebugLaunch.value("-skipHours"), let hours = Double(h) { skip(hours: hours) }
        if DebugLaunch.value("-sleep") == "1" { pet?.sleeping = true }
        if let a = DebugLaunch.value("-hatch"), a == "1" { justHatched = true }
        #endif
    }

    // время идёт: цыпа голодает, пачкается, скучает и устаёт (во сне — медленнее, а энергия растёт)
    func tick(now: Date = Date()) {
        guard var p = pet else { return }
        let hours = now.timeIntervalSince(p.updated) / 3600
        guard hours > 0 else { return }
        advance(&p, hours: hours)
        p.updated = now
        pet = p
        save()
    }

    func skip(hours: Double) {
        guard var p = pet else { return }
        advance(&p, hours: hours)
        pet = p
        save()
    }

    private func advance(_ p: inout Pet, hours: Double) {
        let before = p
        for s in Stat.allCases where s != .energy {
            p[s] -= s.ratePerHour * hours * (p.sleeping ? 0.35 : 1)
        }
        if p.sleeping {
            p.energy += 25 * hours
            if p.energy >= 100 {
                p.sleeping = false
                say("\(p.name) выспался и бодр", haptic: .success)
            }
        } else {
            p.energy -= Stat.energy.ratePerHour * hours
        }
        if !p.sleeping {
            for s in Stat.allCases where before[s] >= Self.lowLevel && p[s] < Self.lowLevel {
                say("\(p.name) \(s.alert)", haptic: .notification)
                break
            }
        }
    }

    // MARK: действия

    func adopt(_ look: Look) {
        pet = Pet(lookID: look.id)
        justHatched = true
        WKInterfaceDevice.current().play(.success)
        save()
        requestNotifications()
    }

    func feed() -> Bool {
        guard var p = pet else { return false }
        if p.sleeping { say("Тсс, \(p.name) спит", haptic: .failure); return false }
        if p.hunger >= 92 { say("\(p.name) сыт и отворачивается", haptic: .failure); return false }
        if grains < Self.feedCost { say("Нужно \(Self.feedCost) зёрен. Поймайте их в игре", haptic: .failure); return false }
        grains -= Self.feedCost
        p.hunger += 32
        pet = p
        WKInterfaceDevice.current().play(.click)
        save()
        return true
    }

    func toggleSleep() {
        guard var p = pet else { return }
        if !p.sleeping && p.energy >= 90 { say("\(p.name) полон сил и не хочет спать", haptic: .failure); return }
        p.sleeping.toggle()
        if !p.sleeping { p.fun -= 8 }
        pet = p
        WKInterfaceDevice.current().play(p.sleeping ? .directionDown : .directionUp)
        say(p.sleeping ? "Спокойной ночи, \(p.name)" : "\(p.name) проснулся и немного ворчит")
        save()
    }

    func rub(_ amount: Double) {
        guard var p = pet else { return }
        p.clean += amount
        pet = p
    }

    func finishGame(fun: Double, energy: Double, grainsWon: Int) {
        guard var p = pet else { return }
        p.fun += fun
        p.energy -= energy
        pet = p
        grains += grainsWon
        save()
    }

    func say(_ text: String, haptic: WKHapticType? = nil) {
        toast = text
        if let haptic { WKInterfaceDevice.current().play(haptic) }
        let shown = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if self.toast == shown { self.toast = nil }
        }
    }

    // MARK: хранение

    private struct Saved: Codable { var pet: Pet?; var grains: Int; var flapBest: Int }

    func save() {
        let data = try? JSONEncoder().encode(Saved(pet: pet, grains: grains, flapBest: flapBest))
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        pet = s.pet
        grains = s.grains
        flapBest = s.flapBest
    }

    // MARK: напоминания: когда шкала упадёт ниже 35, придёт уведомление

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard let p = pet, !p.sleeping else { return }
        for s in Stat.allCases where p[s] > Self.lowLevel {
            let hours = (p[s] - Self.lowLevel) / s.ratePerHour
            let content = UNMutableNotificationContent()
            content.title = p.name
            content.body = "\(p.name) \(s.alert)"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, hours * 3600), repeats: false)
            center.add(UNNotificationRequest(identifier: "low-\(s.rawValue)", content: content, trigger: trigger))
        }
    }
}
