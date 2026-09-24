import XCTest
@testable import ProjectIstiqamah

final class DateToolsTests: XCTestCase {
    func testTimePickerValuesRoundTripAsCanonicalTimes() throws {
        let day = try XCTUnwrap(DateTools.date(from: "2026-09-17"))
        let selectedTime = try XCTUnwrap(DateTools.date(for: "23:45", on: day))

        XCTAssertEqual(DateTools.timeString(from: selectedTime), "23:45")
    }

    func testLegacyPreferencesReceiveDefaultSnoozeDelay() throws {
        let json = Data(#"{"haptics":true,"reminders":true,"reminderMinutes":10,"reminderSound":"system"}"#.utf8)

        let preferences = try JSONDecoder().decode(AppPreferences.self, from: json)

        XCTAssertEqual(preferences.snoozeMinutes, 5)
        XCTAssertEqual(preferences.widgetMessage, "Keep showing up.")
        XCTAssertEqual(preferences.plainWidgetText, "")
        XCTAssertNil(preferences.customReminderSoundFileName)
    }

    func testSnoozeDelayIsClampedToSupportedRange() {
        XCTAssertEqual(AppPreferences(snoozeMinutes: 1).snoozeMinutes, 5)
        XCTAssertEqual(AppPreferences(snoozeMinutes: 8).snoozeMinutes, 10)
        XCTAssertEqual(AppPreferences(snoozeMinutes: 30).snoozeMinutes, 15)
    }

    func testCustomSoundRequiresSafeCAFFileName() {
        let invalid = AppPreferences(
            reminderSound: .custom,
            customReminderSoundFileName: "../ringtone.m4r"
        )
        let valid = AppPreferences(
            reminderSound: .custom,
            customReminderSoundFileName: "istiqamah-custom.caf",
            customReminderSoundDisplayName: "My tone"
        )

        XCTAssertEqual(invalid.reminderSound, .system)
        XCTAssertNil(invalid.customReminderSoundFileName)
        XCTAssertEqual(valid.reminderSound, .custom)
        XCTAssertEqual(valid.notificationSoundFileName, "istiqamah-custom.caf")
    }

    func testWidgetMessageIsSingleLineAndLengthBounded() {
        let value = "first line\n" + String(repeating: "a", count: 90)
        let normalized = AppPreferences.normalizedWidgetMessage(value)

        XCTAssertEqual(normalized.count, 100)
        XCTAssertEqual(normalized, "first line " + String(repeating: "a", count: 89))
        XCTAssertFalse(normalized.contains("\n"))
    }

    func testPlainWidgetTextPersistsIndependentlyAndIsLengthBounded() throws {
        let preferences = AppPreferences(
            widgetMessage: "Reminder stays separate",
            plainWidgetText: "Another\n" + String(repeating: "b", count: 120)
        )
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))

        XCTAssertEqual(restored.widgetMessage, "Reminder stays separate")
        XCTAssertEqual(restored.plainWidgetText.count, 100)
        XCTAssertFalse(restored.plainWidgetText.contains("\n"))
    }

    func testWidgetSnapshotRoundTrips() throws {
        let snapshot = IstiqamahWidgetSnapshot.placeholder
        let restored = try JSONDecoder().decode(
            IstiqamahWidgetSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(restored, snapshot)
    }

    func testLegacyWidgetSnapshotWithoutPlainTextStillDecodes() throws {
        let json = Data(#"{"updatedAt":0,"personalMessage":"Saved reminder","completedToday":0,"totalToday":0,"currentStreak":0}"#.utf8)
        let snapshot = try JSONDecoder().decode(IstiqamahWidgetSnapshot.self, from: json)

        XCTAssertEqual(snapshot.messageText(override: ""), "Saved reminder")
        XCTAssertEqual(snapshot.plainWidgetText, "")
    }

    func testPlainTextWidgetUsesOnlyItsOwnSnapshotText() {
        let snapshot = IstiqamahWidgetSnapshot(
            updatedAt: Date(),
            personalMessage: "Reminder text",
            plainText: "Separate plain text",
            currentBlock: nil,
            nextBlock: nil,
            completedToday: 0,
            totalToday: 0,
            currentStreak: 0
        )

        XCTAssertEqual(snapshot.plainWidgetText, "Separate plain text")
        XCTAssertEqual(snapshot.messageText(override: ""), "Reminder text")
        XCTAssertEqual(IstiqamahWidgetStore.plainTextWidgetKind, "ProjectIstiqamah.PlainTextWidget")
    }

    func testMessageWidgetUsesEditedTextOrAppMessage() {
        let snapshot = IstiqamahWidgetSnapshot.placeholder
        XCTAssertEqual(snapshot.messageText(override: ""), "Keep showing up.")
        XCTAssertEqual(snapshot.messageText(override: "  Stay steady  "), "Stay steady")
        XCTAssertEqual(snapshot.messageText(override: "  One line\nthen another  "), "One line then another")
        XCTAssertEqual(snapshot.messageText(override: String(repeating: "a", count: 120)).count, 100)
        XCTAssertEqual(IstiqamahWidgetSnapshot.empty().personalMessage, "Keep showing up.")
    }

    func testPulseWidgetResolvesActiveBlockAtTimelineBoundaries() throws {
        let snapshot = IstiqamahWidgetSnapshot.placeholder
        let current = try XCTUnwrap(snapshot.currentBlock)
        let next = try XCTUnwrap(snapshot.nextBlock)

        XCTAssertNil(snapshot.runningBlock(at: current.startDate.addingTimeInterval(-1)))
        XCTAssertEqual(snapshot.runningBlock(at: current.startDate)?.id, current.id)
        XCTAssertNil(snapshot.runningBlock(at: current.endDate))
        XCTAssertEqual(snapshot.runningBlock(at: next.startDate)?.id, next.id)
        XCTAssertNil(snapshot.runningBlock(at: next.endDate))
        XCTAssertEqual(IstiqamahWidgetStore.pulseWidgetKind, "ProjectIstiqamah.PulseWidget")
    }

    func testWidgetStoreUsesConfiguredAppGroup() {
        XCTAssertEqual(
            IstiqamahWidgetStore.appGroupIdentifier,
            "group.com.projectistiqamah.shared"
        )
    }

    func testWidgetStoreDerivesSideStoreGroupFromMainAppBundleIdentifier() {
        XCTAssertEqual(
            IstiqamahWidgetStore.candidateAppGroupIdentifiers(
                for: "com.projectistiqamah.app.TEAM123456"
            ),
            [
                "group.com.projectistiqamah.shared",
                "group.com.projectistiqamah.shared.TEAM123456"
            ]
        )
    }

    func testWidgetStoreDerivesSameSideStoreGroupFromSideStoreWidgetBundleIdentifier() {
        XCTAssertEqual(
            IstiqamahWidgetStore.candidateAppGroupIdentifiers(
                for: "com.projectistiqamah.app.TEAM123456.widgets"
            ),
            [
                "group.com.projectistiqamah.shared",
                "group.com.projectistiqamah.shared.TEAM123456"
            ]
        )
    }

    func testWidgetStoreSupportsDirectSuffixResigningLayout() {
        XCTAssertEqual(
            IstiqamahWidgetStore.candidateAppGroupIdentifiers(
                for: "com.projectistiqamah.app.widgets.TEAM123456"
            ),
            [
                "group.com.projectistiqamah.shared",
                "group.com.projectistiqamah.shared.TEAM123456"
            ]
        )
    }

    func testWidgetStoreDoesNotTreatWidgetNameAsTeamSuffix() {
        XCTAssertEqual(
            IstiqamahWidgetStore.candidateAppGroupIdentifiers(
                for: "com.projectistiqamah.app.widgets"
            ),
            ["group.com.projectistiqamah.shared"]
        )
    }

    func testProgressWidgetDeepLinkSelectsProgressDestination() throws {
        let url = try XCTUnwrap(URL(string: "project-istiqamah://progress"))

        XCTAssertEqual(AppRoute(url: url).destination, .progress)
    }

    func testLegacyBlockDecodesWithEveryDaySchedule() throws {
        let json = Data(#"{"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","startTime":"09:00","endTime":"10:00","note":"","actions":[],"completedDates":[]}"#.utf8)
        let block = try JSONDecoder().decode(FocusBlock.self, from: json)

        XCTAssertEqual(block.weekdays, FocusBlock.everyDay)
        XCTAssertNil(block.archivedAt)
    }

    func testWindowOnlyExistsOnSelectedWeekdays() throws {
        let day = try XCTUnwrap(DateTools.date(from: "2026-09-14"))
        let weekday = Calendar.current.component(.weekday, from: day)
        let block = FocusBlock(
            name: "Selected day",
            startTime: "09:00",
            endTime: "10:00",
            note: "",
            weekdays: [weekday]
        )
        let nextDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: day))

        XCTAssertNotNil(DateTools.window(for: block, on: day))
        XCTAssertNil(DateTools.window(for: block, on: nextDay))
    }

    func testOvernightBlocksOverlapAcrossWeekdayBoundary() {
        let mondayNight = FocusBlock(
            name: "Monday night",
            startTime: "23:00",
            endTime: "01:00",
            note: "",
            weekdays: [2]
        )
        let tuesdayMorning = FocusBlock(
            name: "Tuesday morning",
            startTime: "00:30",
            endTime: "01:30",
            note: "",
            weekdays: [3]
        )

        XCTAssertTrue(DateTools.overlaps(mondayNight, tuesdayMorning))
    }

    func testSameTimeOnDifferentWeekdaysDoesNotOverlap() {
        let monday = FocusBlock(
            name: "Monday",
            startTime: "09:00",
            endTime: "10:00",
            note: "",
            weekdays: [2]
        )
        let tuesday = FocusBlock(
            name: "Tuesday",
            startTime: "09:00",
            endTime: "10:00",
            note: "",
            weekdays: [3]
        )

        XCTAssertFalse(DateTools.overlaps(monday, tuesday))
    }

    func testArchivedBlockDoesNotProduceScheduleWindow() throws {
        let day = try XCTUnwrap(DateTools.date(from: "2026-09-14"))
        let block = FocusBlock(
            name: "Archived",
            startTime: "09:00",
            endTime: "10:00",
            note: "",
            archivedAt: day
        )

        XCTAssertNil(DateTools.window(for: block, on: day))
    }

    func testArchiveMetadataRoundTripsWithCompletionHistory() throws {
        let archivedAt = try XCTUnwrap(DateTools.date(from: "2026-09-17"))
        let original = FocusBlock(
            name: "Archived",
            startTime: "09:00",
            endTime: "10:00",
            note: "",
            completedDates: ["2026-09-16"],
            weekdays: [2, 4, 6],
            archivedAt: archivedAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let restored = try decoder.decode(FocusBlock.self, from: encoder.encode(original))

        XCTAssertEqual(restored.completedDates, original.completedDates)
        XCTAssertEqual(restored.weekdays, original.weekdays)
        XCTAssertEqual(restored.archivedAt, original.archivedAt)
    }

    @MainActor
    func testBackupValidationRejectsOverlappingActiveBlocks() {
        let first = FocusBlock(name: "One", startTime: "09:00", endTime: "10:00", note: "")
        let second = FocusBlock(name: "Two", startTime: "09:30", endTime: "10:30", note: "")
        let snapshot = AppSnapshot(
            version: 4,
            exportedAt: Date(),
            blocks: [first, second],
            preferences: AppPreferences()
        )

        XCTAssertThrowsError(try AppStore.validateBackup(snapshot))
    }

    @MainActor
    func testBackupValidationRejectsPausedStateForUnknownBlock() {
        let block = FocusBlock(name: "Known", startTime: "09:00", endTime: "10:00", note: "")
        let snapshot = AppSnapshot(
            version: 4,
            exportedAt: Date(),
            blocks: [block],
            preferences: AppPreferences(),
            pausedBlocks: ["00000000-0000-0000-0000-000000000001:2026-09-17": Date()]
        )

        XCTAssertThrowsError(try AppStore.validateBackup(snapshot))
    }
}
