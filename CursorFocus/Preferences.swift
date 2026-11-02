import Foundation

struct Exclusion: Codable, Hashable, Identifiable {
    enum Mode: String, Codable, CaseIterable {
        case both
        case neverFocusInto
        case neverStealFrom

        var title: String {
            switch self {
            case .both: "Ignore completely"
            case .neverFocusInto: "Never focus into"
            case .neverStealFrom: "Never steal from"
            }
        }
    }

    var bundleID: String
    var name: String
    var mode: Mode = .both

    var id: String { bundleID }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults: UserDefaults

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "enabled") }
    }
    /// Seconds after the cursor enters a window that typing still goes there.
    @Published var window: Double {
        didSet { defaults.set(window, forKey: "window") }
    }
    @Published var redirectShortcuts: Bool {
        didSet { defaults.set(redirectShortcuts, forKey: "redirectShortcuts") }
    }
    @Published var raiseWindow: Bool {
        didSet { defaults.set(raiseWindow, forKey: "raiseWindow") }
    }
    @Published var exclusions: [Exclusion] {
        didSet { save(exclusions, forKey: "exclusions") }
    }
    @Published var passthrough: [Shortcut] {
        didSet { save(passthrough, forKey: "passthrough") }
    }
    @Published var pausedUntil: Date? {
        didSet {
            defaults.set(pausedUntil, forKey: "pausedUntil")
            scheduleResume()
        }
    }

    private var resumeTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "enabled": true,
            "window": 3.0,
            "redirectShortcuts": true,
            "raiseWindow": true,
        ])
        enabled = defaults.bool(forKey: "enabled")
        window = defaults.double(forKey: "window")
        redirectShortcuts = defaults.bool(forKey: "redirectShortcuts")
        raiseWindow = defaults.bool(forKey: "raiseWindow")
        exclusions = Self.load([Exclusion].self, from: defaults, key: "exclusions") ?? []
        passthrough = Self.load([Shortcut].self, from: defaults, key: "passthrough") ?? Shortcut.defaults
        pausedUntil = (defaults.object(forKey: "pausedUntil") as? Date).flatMap { $0 > .now ? $0 : nil }
        scheduleResume()
    }

    /// Enabled and not paused.
    var isActive: Bool {
        enabled && pausedUntil == nil
    }

    func pause(for interval: TimeInterval) {
        pausedUntil = Date.now.addingTimeInterval(interval)
    }

    func pauseUntilTomorrow() {
        let calendar = Calendar.current
        pausedUntil = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
    }

    private func scheduleResume() {
        resumeTask?.cancel()
        guard let until = pausedUntil else { return }
        resumeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, until.timeIntervalSinceNow)))
            if !Task.isCancelled { self?.pausedUntil = nil }
        }
    }

    func isExcluded(_ bundleID: String) -> Bool {
        exclusions.contains { $0.bundleID == bundleID }
    }

    func exclude(bundleID: String, name: String) {
        guard !isExcluded(bundleID) else { return }
        exclusions.append(Exclusion(bundleID: bundleID, name: name))
        exclusions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func removeExclusion(_ bundleID: String) {
        exclusions.removeAll { $0.bundleID == bundleID }
    }

    var policy: RedirectPolicy {
        RedirectPolicy(window: window, redirectShortcuts: redirectShortcuts,
                       exclusions: exclusions, passthrough: passthrough)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
