import Combine
import Foundation
import UIKit
import WidgetKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var blocks: [FocusBlock]
    @Published var preferences: AppPreferences
    @Published var selectedDate = Date()
    @Published private(set) var requestedBlockID: UUID?
    @Published private(set) var liveActivityStatus = "Checking…"
    @Published private(set) var notificationSyncStatus = "Not synced yet"
    @Published private(set) var backgroundScheduleStatus = "Not scheduled yet"
    @Published private(set) var notificationTestStatus: String?
    @Published private(set) var soundImportStatus: String?
    @Published private(set) var widgetSyncStatus = "Preparing…"
    @Published private(set) var storageStatus = "Ready"
    @Published private(set) var timelineDate = Date()

    private let storageURL: URL
    private var pausedBlocks: [String: Date]
    private var followsToday = true
    private var refreshGeneration = 0
    private var transitionTask: Task<Void, Never>?

    var activeBlocks: [FocusBlock] {
        blocks.filter { $0.archivedAt == nil }
    }

    var archivedBlocks: [FocusBlock] {
        blocks.filter { $0.archivedAt != nil }
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("ProjectIstiqamah", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try (directory as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        } catch {
            storageStatus = "Storage setup warning: \(error.localizedDescription)"
        }
        storageURL = directory.appendingPathComponent("data.json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let needsInitialPersist: Bool
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                let snapshot = try decoder.decode(AppSnapshot.self, from: data)
                blocks = snapshot.blocks
                preferences = snapshot.preferences
                pausedBlocks = snapshot.pausedBlocks ?? [:]
                needsInitialPersist = false
            } catch {
                blocks = Self.seedBlocks
                preferences = AppPreferences()
                pausedBlocks = [:]
                let unreadableURL = directory
                    .appendingPathComponent("data-unreadable-\(UUID().uuidString).json")
                do {
                    try FileManager.default.moveItem(at: storageURL, to: unreadableURL)
                    storageStatus = "Recovered defaults; the unreadable data file was preserved."
                    needsInitialPersist = true
                } catch {
                    storageStatus = "Data recovery failed: \(error.localizedDescription)"
                    needsInitialPersist = false
                }
            }
        } else {
            blocks = Self.seedBlocks
            preferences = AppPreferences()
            pausedBlocks = [:]
            needsInitialPersist = true
        }
        requestedBlockID = nil
        if needsInitialPersist {
            persist()
        }
        BlockLiveActivityActionBridge.shared.register { [weak self] action in
            self?.handleLiveActivityAction(action)
        }
    }

    func add(_ block: FocusBlock) {
        blocks.append(block)
        changed()
    }

    func update(_ block: FocusBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        blocks[index] = block
        changed()
    }

    func remove(_ block: FocusBlock) {
        archive(block)
    }

    func archive(_ block: FocusBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }),
              blocks[index].archivedAt == nil else { return }
        blocks[index].archivedAt = Date()
        pausedBlocks = pausedBlocks.filter { !$0.key.hasPrefix("\(block.id.uuidString):") }
        if requestedBlockID == block.id {
            requestedBlockID = nil
        }
        changed()
    }

    @discardableResult
    func restore(_ block: FocusBlock) -> String? {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }),
              blocks[index].archivedAt != nil else { return nil }
        var restored = blocks[index]
        restored.archivedAt = nil
        if let conflict = activeBlocks.first(where: { DateTools.overlaps(restored, $0) }) {
            return "This schedule overlaps \(conflict.name). Edit a time slot before restoring."
        }
        blocks[index].archivedAt = nil
        changed()
        return nil
    }

    func swapBlockTimeSlots(_ blockID: UUID, with targetID: UUID) {
        guard blockID != targetID,
              let sourceIndex = blocks.firstIndex(where: { $0.id == blockID }),
              let targetIndex = blocks.firstIndex(where: { $0.id == targetID }) else { return }
        let sourceStart = blocks[sourceIndex].startTime
        let sourceEnd = blocks[sourceIndex].endTime
        let sourceWeekdays = blocks[sourceIndex].weekdays
        blocks[sourceIndex].startTime = blocks[targetIndex].startTime
        blocks[sourceIndex].endTime = blocks[targetIndex].endTime
        blocks[sourceIndex].weekdays = blocks[targetIndex].weekdays
        blocks[targetIndex].startTime = sourceStart
        blocks[targetIndex].endTime = sourceEnd
        blocks[targetIndex].weekdays = sourceWeekdays
        blocks.swapAt(sourceIndex, targetIndex)
        changed()
    }

    func toggleBlock(_ blockID: UUID, dateKey: String) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        if blocks[index].completedDates.contains(dateKey) {
            blocks[index].completedDates.remove(dateKey)
        } else {
            guard canRecordCompletion(for: blocks[index], dateKey: dateKey) else { return }
            blocks[index].completedDates.insert(dateKey)
            pausedBlocks.removeValue(forKey: scheduleKey(blockID: blockID, dateKey: dateKey))
            resumeTodayAfterEnding(blockID)
            haptic(.success)
        }
        changed()
    }

    func toggleAction(_ actionID: UUID, in blockID: UUID, dateKey: String) {
        guard let blockIndex = blocks.firstIndex(where: { $0.id == blockID }),
              let actionIndex = blocks[blockIndex].actions.firstIndex(where: { $0.id == actionID }) else { return }
        if blocks[blockIndex].actions[actionIndex].completedDates.contains(dateKey) {
            blocks[blockIndex].actions[actionIndex].completedDates.remove(dateKey)
        } else {
            guard canRecordCompletion(for: blocks[blockIndex], dateKey: dateKey) else { return }
            blocks[blockIndex].actions[actionIndex].completedDates.insert(dateKey)
            haptic(.light)
        }
        changed()
    }

    func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        update(&preferences)
        preferences.reminderMinutes = min(15, max(5, preferences.reminderMinutes))
        preferences.snoozeMinutes = AppPreferences.normalizedSnoozeMinutes(preferences.snoozeMinutes)
        preferences.widgetMessage = AppPreferences.normalizedWidgetMessage(preferences.widgetMessage)
        if preferences.reminderSound == .custom,
           AppPreferences.safeSoundFileName(preferences.customReminderSoundFileName) == nil {
            preferences.reminderSound = .system
        }
        changed()
    }

    func importCustomReminderSound(from url: URL) {
        soundImportStatus = "Importing and converting…"
        Task { [weak self] in
            do {
                let imported = try await CustomNotificationSoundManager.importSound(from: url)
                guard let self else { return }
                self.updatePreferences {
                    $0.customReminderSoundFileName = imported.fileName
                    $0.customReminderSoundDisplayName = imported.displayName
                    $0.reminderSound = .custom
                }
                self.soundImportStatus = "Using \(imported.displayName)"
            } catch {
                self?.soundImportStatus = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    func selectDate(_ date: Date) {
        requestedBlockID = nil
        selectedDate = date
        followsToday = DateTools.key(date) == DateTools.key(Date())
    }

    func handle(_ route: AppRoute) {
        guard let blockID = route.blockID,
              let dateKey = route.dateKey,
              blocks.contains(where: { $0.id == blockID }) else { return }
        if let date = DateTools.date(from: dateKey) {
            selectedDate = date
            followsToday = false
        }
        requestedBlockID = blockID
        switch route.action {
        case "pause":
            setPaused(true, blockID: blockID, dateKey: dateKey)
        case "resume":
            setPaused(false, blockID: blockID, dateKey: dateKey)
        case "end":
            endBlock(blockID, dateKey: dateKey)
        case "complete":
            guard let block = blocks.first(where: { $0.id == blockID }),
                  let date = DateTools.date(from: dateKey),
                  let window = DateTools.window(for: block, on: date),
                  Date() >= window.end,
                  !block.completedDates.contains(dateKey) else { return }
            toggleBlock(blockID, dateKey: dateKey)
        default:
            break
        }
    }

    func pauseDate(for item: ScheduledBlock) -> Date? {
        pausedBlocks[item.id]
    }

    func togglePause(_ item: ScheduledBlock) {
        setPaused(pauseDate(for: item) == nil, blockID: item.block.id, dateKey: item.dateKey)
    }

    func exportBackup() throws -> URL {
        let snapshot = AppSnapshot(
            version: 4,
            exportedAt: Date(),
            blocks: blocks,
            preferences: preferences,
            pausedBlocks: pausedBlocks
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Project-Istiqamah-Backup.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func importBackup(from url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile != false else {
            throw BackupImportError.invalid("Choose a regular JSON backup file.")
        }
        guard values.fileSize.map({ $0 <= Self.maximumBackupBytes }) ?? true else {
            throw BackupImportError.invalid("The backup is larger than 5 MB.")
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= Self.maximumBackupBytes else {
            throw BackupImportError.invalid("The backup is larger than 5 MB.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: AppSnapshot
        do {
            snapshot = try decoder.decode(AppSnapshot.self, from: data)
        } catch {
            throw BackupImportError.unreadable(error.localizedDescription)
        }
        try Self.validateBackup(snapshot)
        blocks = snapshot.blocks
        preferences = snapshot.preferences
        pausedBlocks = snapshot.pausedBlocks ?? [:]
        requestedBlockID = nil
        selectedDate = Date()
        followsToday = true
        storageStatus = "Backup restored successfully."
        persist()
        refreshSystemFeatures()
    }

    func activateTimeline() {
        refreshSystemFeatures()
    }

    func deactivateTimeline() {
        transitionTask?.cancel()
        transitionTask = nil
    }

    func refreshSystemFeatures(now: Date = Date()) {
        if followsToday, DateTools.key(selectedDate) != DateTools.key(now) {
            selectedDate = now
        }
        clearExpiredRoute(at: now)
        timelineDate = now
        prunePausedBlocks(at: now)
        publishWidgetSnapshot(at: now)
        scheduleNextTransition(after: now)
        let currentBlocks = activeBlocks
        let currentPausedBlocks = pausedBlocks
        let currentPreferences = preferences
        if let schedulingError = BackgroundRefreshManager.shared.schedule(blocks: currentBlocks) {
            backgroundScheduleStatus = "Request failed: \(schedulingError)"
        } else {
            backgroundScheduleStatus = "Refresh requested"
        }
        refreshGeneration &+= 1
        let generation = refreshGeneration
        Task { [weak self] in
            let activityReport = await LiveActivityManager.shared.sync(
                blocks: currentBlocks,
                pausedBlocks: currentPausedBlocks,
                alertSoundFileName: currentPreferences.notificationSoundFileName,
                now: now
            )
            guard let self, generation == self.refreshGeneration else { return }
            let notificationMessage = await NotificationManager.shared.sync(
                blocks: currentBlocks,
                preferences: currentPreferences,
                now: now
            )
            if generation == self.refreshGeneration {
                self.notificationSyncStatus = notificationMessage
                if let activityReport {
                    self.liveActivityStatus = activityReport.message
                }
            }
        }
    }

    func restartLiveActivity() {
        let currentBlocks = activeBlocks
        let currentPausedBlocks = pausedBlocks
        let alertSoundFileName = preferences.notificationSoundFileName
        liveActivityStatus = "Restarting…"
        refreshGeneration &+= 1
        let generation = refreshGeneration
        Task { [weak self] in
            let report = await LiveActivityManager.shared.restart(
                blocks: currentBlocks,
                pausedBlocks: currentPausedBlocks,
                alertSoundFileName: alertSoundFileName
            )
            guard let self, let report, generation == self.refreshGeneration else { return }
            self.liveActivityStatus = report.message
        }
    }

    func sendTestReminder() {
        let currentPreferences = preferences
        notificationTestStatus = "Scheduling…"
        Task { [weak self] in
            let message = await NotificationManager.shared.sendTest(preferences: currentPreferences)
            self?.notificationTestStatus = message
        }
    }

    private func changed() {
        persist()
        refreshSystemFeatures()
    }

    private func handleLiveActivityAction(_ action: BlockLiveActivityAction) {
        switch action {
        case let .setPaused(blockID, dateKey, paused):
            setPaused(paused, blockID: blockID, dateKey: dateKey)
        case let .end(blockID, dateKey):
            endBlock(blockID, dateKey: dateKey)
        }
    }

    private func setPaused(_ paused: Bool, blockID: UUID, dateKey: String) {
        guard let block = blocks.first(where: { $0.id == blockID }),
              let date = DateTools.date(from: dateKey),
              let window = DateTools.window(for: block, on: date) else { return }
        let now = Date()
        let key = scheduleKey(blockID: blockID, dateKey: dateKey)
        if paused {
            guard window.start <= now, now < window.end,
                  !block.completedDates.contains(dateKey) else { return }
            pausedBlocks[key] = now
        } else {
            pausedBlocks.removeValue(forKey: key)
        }
        changed()
    }

    private func endBlock(_ blockID: UUID, dateKey: String) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }),
              canRecordCompletion(for: blocks[index], dateKey: dateKey),
              !blocks[index].completedDates.contains(dateKey) else { return }
        blocks[index].completedDates.insert(dateKey)
        pausedBlocks.removeValue(forKey: scheduleKey(blockID: blockID, dateKey: dateKey))
        resumeTodayAfterEnding(blockID)
        haptic(.success)
        changed()
    }

    private func scheduleNextTransition(after now: Date) {
        transitionTask?.cancel()
        transitionTask = nil
        guard let boundary = DateTools.nextTransition(in: blocks, after: now) else { return }
        let delay = max(0, boundary.timeIntervalSince(now))
        transitionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay), tolerance: .zero)
            } catch {
                return
            }
            guard let self else { return }
            self.transitionTask = nil
            self.refreshSystemFeatures(now: max(Date(), boundary))
        }
    }

    private func scheduleKey(blockID: UUID, dateKey: String) -> String {
        "\(blockID.uuidString):\(dateKey)"
    }

    private func resumeTodayAfterEnding(_ blockID: UUID) {
        guard requestedBlockID == blockID else { return }
        requestedBlockID = nil
        selectedDate = Date()
        followsToday = true
    }

    private func clearExpiredRoute(at now: Date) {
        guard let requestedBlockID,
              let block = blocks.first(where: { $0.id == requestedBlockID }),
              let window = DateTools.window(for: block, on: selectedDate),
              now >= window.end else { return }
        self.requestedBlockID = nil
        selectedDate = now
        followsToday = true
    }

    private func prunePausedBlocks(at now: Date) {
        guard !pausedBlocks.isEmpty else { return }
        let activeKeys = Set(
            DateTools.schedule(for: blocks, around: now, days: 2)
                .filter {
                    $0.start <= now && now < $0.end &&
                    !$0.block.completedDates.contains($0.dateKey)
                }
                .map(\.id)
        )
        let previousCount = pausedBlocks.count
        pausedBlocks = pausedBlocks.filter { activeKeys.contains($0.key) }
        if pausedBlocks.count != previousCount {
            persist()
        }
    }

    private func canRecordCompletion(for block: FocusBlock, dateKey: String) -> Bool {
        guard let date = DateTools.date(from: dateKey),
              let window = DateTools.window(for: block, on: date) else {
            return false
        }
        return Date() >= window.start
    }

    private func persist() {
        let snapshot = AppSnapshot(
            version: 4,
            exportedAt: Date(),
            blocks: blocks,
            preferences: preferences,
            pausedBlocks: pausedBlocks
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: storageURL, options: .atomic)
            if storageStatus == "Ready" || storageStatus == "Saved" {
                storageStatus = "Saved"
            }
        } catch {
            storageStatus = "Save failed: \(error.localizedDescription)"
        }
    }

    private func publishWidgetSnapshot(at now: Date = Date()) {
        let schedule = DateTools.schedule(for: activeBlocks, around: now, days: 2)
        let available = schedule.filter {
            !$0.block.completedDates.contains($0.dateKey)
        }
        let current = available.first { $0.start <= now && now < $0.end }
        let next = available.first { $0.start > now }
        let todayKey = DateTools.key(now)
        let today = schedule.filter { $0.dateKey == todayKey }
        let completedToday = today.filter {
            $0.block.completedDates.contains(todayKey)
        }.count

        let snapshot = IstiqamahWidgetSnapshot(
            updatedAt: now,
            personalMessage: preferences.widgetMessage,
            currentBlock: current.map(widgetSummary),
            nextBlock: next.map(widgetSummary),
            completedToday: completedToday,
            totalToday: today.count,
            currentStreak: currentStreak(at: now)
        )
        if IstiqamahWidgetStore.save(snapshot) {
            widgetSyncStatus = "Updated"
            WidgetCenter.shared.reloadTimelines(ofKind: IstiqamahWidgetStore.focusWidgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: IstiqamahWidgetStore.consistencyWidgetKind)
        } else {
            widgetSyncStatus = "App Group unavailable"
        }
    }

    private func widgetSummary(_ item: ScheduledBlock) -> WidgetBlockSummary {
        WidgetBlockSummary(
            id: item.block.id,
            name: item.block.name,
            dateKey: item.dateKey,
            startDate: item.start,
            endDate: item.end,
            isPaused: pausedBlocks[item.id] != nil
        )
    }

    private func currentStreak(at now: Date) -> Int {
        let completedDates = Set(blocks.flatMap(\.completedDates))
        var date = now
        var streak = 0
        while completedDates.contains(DateTools.key(date)) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
                break
            }
            date = previous
        }
        return streak
    }

    static func validateBackup(_ snapshot: AppSnapshot) throws {
        guard (1...4).contains(snapshot.version) else {
            throw BackupImportError.unsupportedVersion(snapshot.version)
        }
        guard snapshot.blocks.count <= 500 else {
            throw BackupImportError.invalid("The backup contains too many blocks.")
        }
        let blockIDs = snapshot.blocks.map(\.id)
        let blockIDSet = Set(blockIDs)
        guard blockIDSet.count == blockIDs.count else {
            throw BackupImportError.invalid("The backup contains duplicate block identifiers.")
        }

        let pausedBlocks = snapshot.pausedBlocks ?? [:]
        guard pausedBlocks.count <= 500,
              pausedBlocks.keys.allSatisfy({ key in
                  let parts = key.split(separator: ":", omittingEmptySubsequences: false)
                  guard parts.count == 2,
                        let blockID = UUID(uuidString: String(parts[0])),
                        blockIDSet.contains(blockID) else { return false }
                  return DateTools.date(from: String(parts[1])) != nil
              }) else {
            throw BackupImportError.invalid("The backup contains invalid paused-block state.")
        }

        for block in snapshot.blocks {
            guard !block.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  DateTools.isValid(time: block.startTime),
                  DateTools.isValid(time: block.endTime),
                  !block.weekdays.isEmpty,
                  block.weekdays.allSatisfy({ (1...7).contains($0) }),
                  block.actions.count <= 5 else {
                throw BackupImportError.invalid("A block contains an invalid name, time, weekday, or action count.")
            }
            let actionIDs = block.actions.map(\.id)
            guard Set(actionIDs).count == actionIDs.count,
                  block.actions.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  block.completedDates.allSatisfy({ DateTools.date(from: $0) != nil }),
                  block.actions.allSatisfy({ action in
                      action.completedDates.allSatisfy { DateTools.date(from: $0) != nil }
                  }) else {
                throw BackupImportError.invalid("A block contains invalid actions or completion history.")
            }
        }

        let active = snapshot.blocks.filter { $0.archivedAt == nil }
        for index in active.indices {
            for comparison in active.indices where comparison > index {
                if DateTools.overlaps(active[index], active[comparison]) {
                    throw BackupImportError.invalid(
                        "\(active[index].name) overlaps \(active[comparison].name)."
                    )
                }
            }
        }
    }

    private func haptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        guard preferences.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(style)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard preferences.haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static let seedBlocks: [FocusBlock] = [
        FocusBlock(
            name: "Fajr Block",
            startTime: "05:00",
            endTime: "06:30",
            note: "Start the day before the noise.",
            actions: [BlockAction(name: "Pray Fajr"), BlockAction(name: "Read Quran")]
        ),
        FocusBlock(
            name: "Work Hours Discipline",
            startTime: "09:00",
            endTime: "17:00",
            note: "Stay focused. Follow the plan."
        ),
        FocusBlock(
            name: "Evening Block",
            startTime: "19:30",
            endTime: "20:30",
            note: "Close the day with intention."
        ),
        FocusBlock(
            name: "Night Block",
            startTime: "21:30",
            endTime: "22:30",
            note: "Prepare tomorrow before sleep."
        )
    ]

    private static let maximumBackupBytes = 5 * 1_024 * 1_024
}

private enum BackupImportError: LocalizedError {
    case unreadable(String)
    case unsupportedVersion(Int)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case let .unreadable(message):
            "The selected file is not a valid Project Istiqamah backup. \(message)"
        case let .unsupportedVersion(version):
            "Backup version \(version) is not supported by this app."
        case let .invalid(message):
            "The backup could not be restored. \(message)"
        }
    }
}
