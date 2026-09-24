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
            personalMessage: "Keep showing up.",
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

    func messageText(override: String) -> String {
        let customText = override.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !customText.isEmpty { return String(customText.prefix(100)) }
        let savedText = personalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return savedText.isEmpty ? "Keep showing up." : String(savedText.prefix(100))
    }
}

enum IstiqamahWidgetStore {
    static let appGroupIdentifier = "group.com.projectistiqamah.shared"
    static let snapshotKey = "istiqamah.widget.snapshot.v1"
    static let focusWidgetKind = "ProjectIstiqamah.FocusWidget"
    static let consistencyWidgetKind = "ProjectIstiqamah.ConsistencyWidget"
    static let messageWidgetKind = "ProjectIstiqamah.MessageWidget"
    private static let snapshotFileName = "istiqamah-widget-snapshot.json"
    private static let originalAppBundleIdentifier = "com.projectistiqamah.app"
    private static let originalWidgetBundleIdentifier = "com.projectistiqamah.app.widgets"

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
    /// adding the same team suffix it uses for the app and extension bundle IDs.
    /// Try the configured identifier first for normal Xcode/App Store builds,
    /// then the derived identifier for a SideStore-resigned build.
    static func candidateAppGroupIdentifiers(for bundleIdentifier: String?) -> [String] {
        var identifiers = [appGroupIdentifier]
        guard let bundleIdentifier,
              let teamSuffix = sideStoreTeamSuffix(from: bundleIdentifier) else {
            return identifiers
        }
        identifiers.append("\(appGroupIdentifier).\(teamSuffix)")
        return identifiers
    }

    private static func sideStoreTeamSuffix(from bundleIdentifier: String) -> String? {
        guard bundleIdentifier != originalAppBundleIdentifier,
              bundleIdentifier != originalWidgetBundleIdentifier else { return nil }

        // Older resigning layouts append the team after the complete target ID:
        // com.projectistiqamah.app.widgets.TEAM
        let directWidgetPrefix = originalWidgetBundleIdentifier + "."
        if bundleIdentifier.hasPrefix(directWidgetPrefix) {
            let suffix = String(bundleIdentifier.dropFirst(directWidgetPrefix.count))
            return suffix.isEmpty ? nil : suffix
        }

        // SideStore keeps the extension suffix after the resigned parent ID:
        // com.projectistiqamah.app.TEAM.widgets
        let appPrefix = originalAppBundleIdentifier + "."
        let widgetSuffix = String(
            originalWidgetBundleIdentifier.dropFirst(originalAppBundleIdentifier.count)
        )
        if bundleIdentifier.hasPrefix(appPrefix),
           bundleIdentifier.hasSuffix(widgetSuffix) {
            let suffixLength = bundleIdentifier.count - appPrefix.count - widgetSuffix.count
            if suffixLength > 0 {
                let teamStart = bundleIdentifier.index(
                    bundleIdentifier.startIndex,
                    offsetBy: appPrefix.count
                )
                let teamEnd = bundleIdentifier.index(teamStart, offsetBy: suffixLength)
                return String(bundleIdentifier[teamStart..<teamEnd])
            }
        }

        // The main SideStore app ID is com.projectistiqamah.app.TEAM.
        guard bundleIdentifier.hasPrefix(appPrefix) else { return nil }
        let suffix = String(bundleIdentifier.dropFirst(appPrefix.count))
        return suffix.isEmpty ? nil : suffix
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
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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
