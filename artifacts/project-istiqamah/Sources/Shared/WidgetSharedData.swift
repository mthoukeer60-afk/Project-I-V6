import Foundation
import Security

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
    static let preferredAppGroupIdentifier = "group.com.projectistiqamah.shared"
    static let snapshotKey = "istiqamah.widget.snapshot.v1"
    static let focusWidgetKind = "ProjectIstiqamah.FocusWidget"
    static let consistencyWidgetKind = "ProjectIstiqamah.ConsistencyWidget"
    private static let snapshotFileName = "istiqamah-widget-snapshot.json"

    private static let sharedContainer: (identifier: String, url: URL)? = {
        let entitledGroups = currentProcessAppGroups()
        var candidates = entitledGroups.sorted(by: groupComesBefore)
        if !candidates.contains(preferredAppGroupIdentifier) {
            candidates.append(preferredAppGroupIdentifier)
        }
        for identifier in candidates {
            if let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
            ) {
                return (identifier, url)
            }
        }
        return nil
    }()

    static var activeAppGroupIdentifier: String? {
        sharedContainer?.identifier
    }

    @discardableResult
    static func save(_ snapshot: IstiqamahWidgetSnapshot) -> Bool {
        guard let sharedContainer,
              let data = try? JSONEncoder().encode(snapshot) else { return false }
        let fileURL = sharedContainer.url.appendingPathComponent(snapshotFileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            guard let writtenData = try? Data(contentsOf: fileURL),
                  decode(writtenData) == snapshot else { return false }
            // Retain the shared-defaults copy for migration from builds that
            // predate the file-backed store. The file is the authoritative
            // value because an atomic write is immediately visible to the
            // separately running widget extension.
            UserDefaults(suiteName: sharedContainer.identifier)?.set(data, forKey: snapshotKey)
            return true
        } catch {
            return false
        }
    }

    static func load() -> IstiqamahWidgetSnapshot? {
        guard let sharedContainer else { return nil }
        let fileURL = sharedContainer.url.appendingPathComponent(snapshotFileName)
        if let data = try? Data(contentsOf: fileURL), let snapshot = decode(data) {
            return snapshot
        }
        guard let data = UserDefaults(suiteName: sharedContainer.identifier)?
            .data(forKey: snapshotKey) else { return nil }
        return decode(data)
    }

    static func preferredGroupIdentifier(from identifiers: [String]) -> String? {
        identifiers.sorted(by: groupComesBefore).first
    }

    private static func decode(_ data: Data) -> IstiqamahWidgetSnapshot? {
        try? JSONDecoder().decode(IstiqamahWidgetSnapshot.self, from: data)
    }

    private static func groupPriority(_ identifier: String) -> Int {
        if identifier == preferredAppGroupIdentifier { return 0 }
        if identifier.localizedCaseInsensitiveContains("projectistiqamah") { return 1 }
        if identifier.localizedCaseInsensitiveContains("istiqamah") { return 2 }
        return 3
    }

    private static func groupComesBefore(_ first: String, _ second: String) -> Bool {
        let firstPriority = groupPriority(first)
        let secondPriority = groupPriority(second)
        if firstPriority != secondPriority {
            return firstPriority < secondPriority
        }
        return first.localizedCaseInsensitiveCompare(second) == .orderedAscending
    }

    private static func currentProcessAppGroups() -> [String] {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.security.application-groups" as CFString,
                nil
              ) else { return [] }
        return value as? [String] ?? []
    }
}
