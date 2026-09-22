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
    private static let snapshotFileName = "istiqamah-widget-snapshot.json"
    private static let originalBundleIdentifiers = [
        "com.projectistiqamah.app.widgets",
        "com.projectistiqamah.app"
    ]

    private static let sharedContainer: (identifier: String, url: URL)? = {
        for identifier in candidateAppGroupIdentifiers(for: Bundle.main.bundleIdentifier) {
            if let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
            ) {
                return (identifier, url)
            }
        }
        return nil
    }()

    /// SideStore makes App Group identifiers unique to the signing team by
    /// appending the same suffix it adds to the app and extension bundle IDs.
    /// Try the configured identifier first for normal Xcode/App Store builds,
    /// then the derived identifier for a SideStore-resigned build.
    static func candidateAppGroupIdentifiers(for bundleIdentifier: String?) -> [String] {
        var identifiers = [appGroupIdentifier]
        guard let bundleIdentifier else { return identifiers }

        for originalIdentifier in originalBundleIdentifiers
        where bundleIdentifier.hasPrefix(originalIdentifier + ".") {
            let suffixStart = bundleIdentifier.index(
                bundleIdentifier.startIndex,
                offsetBy: originalIdentifier.count + 1
            )
            let suffix = String(bundleIdentifier[suffixStart...])
            guard !suffix.isEmpty else { break }
            identifiers.append("\(appGroupIdentifier).\(suffix)")
            break
        }
        return identifiers
    }

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

    private static func decode(_ data: Data) -> IstiqamahWidgetSnapshot? {
        try? JSONDecoder().decode(IstiqamahWidgetSnapshot.self, from: data)
    }
}
