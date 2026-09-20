import Foundation

struct WidgetBlockSummary: Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let dateKey: String
    let startDate: Date
    let endDate: Date
    let isPaused: Bool

    var deepLink: URL? {
        var components = URLComponents()
        components.scheme = "project-istiqamah"
        components.host = "block"
        components.path = "/\(id.uuidString)"
        components.queryItems = [URLQueryItem(name: "date", value: dateKey)]
        return components.url
    }
}

struct IstiqamahWidgetSnapshot: Codable, Hashable, Sendable {
    let updatedAt: Date
    let personalMessage: String
    let currentBlock: WidgetBlockSummary?
    let nextBlock: WidgetBlockSummary?
    let completedToday: Int
    let totalToday: Int
    let currentStreak: Int

    static func empty(at date: Date = Date()) -> IstiqamahWidgetSnapshot {
        IstiqamahWidgetSnapshot(
            updatedAt: date,
            personalMessage: "Open Project Istiqamah to sync.",
            currentBlock: nil,
            nextBlock: nil,
            completedToday: 0,
            totalToday: 0,
            currentStreak: 0
        )
    }

    static let placeholder = IstiqamahWidgetSnapshot(
        updatedAt: Date(),
        personalMessage: "Keep showing up.",
        currentBlock: WidgetBlockSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            name: "Deep Work",
            dateKey: "2026-09-21",
            startDate: Date().addingTimeInterval(-20 * 60),
            endDate: Date().addingTimeInterval(40 * 60),
            isPaused: false
        ),
        nextBlock: WidgetBlockSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            name: "Evening Review",
            dateKey: "2026-09-21",
            startDate: Date().addingTimeInterval(90 * 60),
            endDate: Date().addingTimeInterval(150 * 60),
            isPaused: false
        ),
        completedToday: 2,
        totalToday: 4,
        currentStreak: 7
    )
}

enum IstiqamahWidgetStore {
    static let appGroupIdentifier = "group.com.projectistiqamah.shared"
    static let snapshotKey = "istiqamah.widget.snapshot.v1"
    static let focusWidgetKind = "ProjectIstiqamah.FocusWidget"
    static let consistencyWidgetKind = "ProjectIstiqamah.ConsistencyWidget"

    @discardableResult
    static func save(_ snapshot: IstiqamahWidgetSnapshot) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults.set(data, forKey: snapshotKey)
        return true
    }

    static func load() -> IstiqamahWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(IstiqamahWidgetSnapshot.self, from: data)
    }
}
