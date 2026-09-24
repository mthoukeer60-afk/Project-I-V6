import Foundation

struct BlockAction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var completedDates: Set<String> = []
}

struct FocusBlock: Identifiable, Codable, Hashable {
    static let everyDay = Set(1...7)

    var id: UUID
    var name: String
    var startTime: String
    var endTime: String
    var note: String
    var actions: [BlockAction]
    var completedDates: Set<String>
    var weekdays: Set<Int>
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        startTime: String,
        endTime: String,
        note: String,
        actions: [BlockAction] = [],
        completedDates: Set<String> = [],
        weekdays: Set<Int> = FocusBlock.everyDay,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.actions = actions
        self.completedDates = completedDates
        self.weekdays = weekdays
        self.archivedAt = archivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case startTime
        case endTime
        case note
        case actions
        case completedDates
        case weekdays
        case archivedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        startTime = try values.decode(String.self, forKey: .startTime)
        endTime = try values.decode(String.self, forKey: .endTime)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        actions = try values.decodeIfPresent([BlockAction].self, forKey: .actions) ?? []
        completedDates = try values.decodeIfPresent(Set<String>.self, forKey: .completedDates) ?? []
        weekdays = try values.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? Self.everyDay
        archivedAt = try values.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

enum ReminderSound: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case systemRingtone
    case gentleChime
    case brightBell
    case focusPulse
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System Notification"
        case .systemRingtone: "System Ringtone"
        case .gentleChime: "Gentle Chime"
        case .brightBell: "Bright Bell"
        case .focusPulse: "Focus Pulse"
        case .custom: "Imported Sound"
        }
    }

    var fileName: String? {
        switch self {
        case .system, .systemRingtone, .custom: nil
        case .gentleChime: "gentle-chime.wav"
        case .brightBell: "bright-bell.wav"
        case .focusPulse: "focus-pulse.wav"
        }
    }
}

struct AppPreferences: Codable, Equatable {
    static let snoozeOptions = [5, 10, 15]

    var haptics = true
    var reminders = true
    var reminderMinutes = 5
    var snoozeMinutes = 5
    var reminderSound: ReminderSound = .system
    var customReminderSoundFileName: String?
    var customReminderSoundDisplayName: String?
    var widgetMessage = "Keep showing up."
    var plainWidgetText = ""

    private enum CodingKeys: String, CodingKey {
        case haptics
        case reminders
        case reminderMinutes
        case snoozeMinutes
        case reminderSound
        case customReminderSoundFileName
        case customReminderSoundDisplayName
        case widgetMessage
        case plainWidgetText
    }

    init(
        haptics: Bool = true,
        reminders: Bool = true,
        reminderMinutes: Int = 5,
        snoozeMinutes: Int = 5,
        reminderSound: ReminderSound = .system,
        customReminderSoundFileName: String? = nil,
        customReminderSoundDisplayName: String? = nil,
        widgetMessage: String = "Keep showing up.",
        plainWidgetText: String = ""
    ) {
        self.haptics = haptics
        self.reminders = reminders
        self.reminderMinutes = min(15, max(5, reminderMinutes))
        self.snoozeMinutes = Self.normalizedSnoozeMinutes(snoozeMinutes)
        self.reminderSound = reminderSound
        self.customReminderSoundFileName = Self.safeSoundFileName(customReminderSoundFileName)
        self.customReminderSoundDisplayName = Self.normalizedSoundDisplayName(
            customReminderSoundDisplayName
        )
        self.widgetMessage = Self.normalizedWidgetMessage(widgetMessage)
        self.plainWidgetText = Self.normalizedWidgetMessage(plainWidgetText)
        if reminderSound == .custom, self.customReminderSoundFileName == nil {
            self.reminderSound = .system
        }
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        haptics = try values.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        reminders = try values.decodeIfPresent(Bool.self, forKey: .reminders) ?? true
        reminderMinutes = min(
            15,
            max(5, try values.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? 5)
        )
        snoozeMinutes = Self.normalizedSnoozeMinutes(
            try values.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5
        )
        reminderSound = try values.decodeIfPresent(ReminderSound.self, forKey: .reminderSound) ?? .system
        customReminderSoundFileName = Self.safeSoundFileName(
            try values.decodeIfPresent(String.self, forKey: .customReminderSoundFileName)
        )
        customReminderSoundDisplayName = Self.normalizedSoundDisplayName(
            try values.decodeIfPresent(String.self, forKey: .customReminderSoundDisplayName)
        )
        widgetMessage = Self.normalizedWidgetMessage(
            try values.decodeIfPresent(String.self, forKey: .widgetMessage) ?? "Keep showing up."
        )
        plainWidgetText = Self.normalizedWidgetMessage(
            try values.decodeIfPresent(String.self, forKey: .plainWidgetText) ?? ""
        )
        if reminderSound == .custom, customReminderSoundFileName == nil {
            reminderSound = .system
        }
    }

    static func normalizedSnoozeMinutes(_ minutes: Int) -> Int {
        let bounded = min(15, max(5, minutes))
        return snoozeOptions.min { first, second in
            abs(first - bounded) < abs(second - bounded)
        } ?? 5
    }

    static func normalizedWidgetMessage(_ message: String) -> String {
        let cleaned = message.replacingOccurrences(of: "\n", with: " ")
        return String(cleaned.prefix(100))
    }

    static func safeSoundFileName(_ fileName: String?) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard let fileName,
              !fileName.isEmpty,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              fileName.rangeOfCharacter(from: allowed.inverted) == nil,
              fileName.lowercased().hasSuffix(".caf") else { return nil }
        return fileName
    }

    private static func normalizedSoundDisplayName(_ name: String?) -> String? {
        guard let name else { return nil }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(50))
    }

    var notificationSoundFileName: String? {
        reminderSound == .custom ? customReminderSoundFileName : reminderSound.fileName
    }
}

struct AppSnapshot: Codable {
    let version: Int
    let exportedAt: Date
    let blocks: [FocusBlock]
    let preferences: AppPreferences
    let pausedBlocks: [String: Date]?

    init(
        version: Int,
        exportedAt: Date,
        blocks: [FocusBlock],
        preferences: AppPreferences,
        pausedBlocks: [String: Date]? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.blocks = blocks
        self.preferences = preferences
        self.pausedBlocks = pausedBlocks
    }
}

struct ScheduledBlock: Identifiable {
    let block: FocusBlock
    let dateKey: String
    let start: Date
    let end: Date

    var id: String { "\(block.id.uuidString):\(dateKey)" }
}
