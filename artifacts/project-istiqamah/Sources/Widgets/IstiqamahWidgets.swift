import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct FocusWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Focus"
    static var description = IntentDescription("Choose what the Focus widget shows.")

    @Parameter(title: "Show personal message", default: true)
    var showPersonalMessage: Bool

    @Parameter(title: "Show next block", default: true)
    var showNextBlock: Bool
}

struct ConsistencyWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Consistency"
    static var description = IntentDescription("Choose the progress shown in the widget.")

    @Parameter(title: "Show streak", default: true)
    var showStreak: Bool

    @Parameter(title: "Show personal message", default: true)
    var showPersonalMessage: Bool
}

struct MessageWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Message"
    static var description = IntentDescription("Display your intention, or set text for this widget only.")

    @Parameter(title: "Widget text (optional)", default: "")
    var customText: String
}

private struct FocusWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: IstiqamahWidgetSnapshot
    let configuration: FocusWidgetConfigurationIntent
}

private struct ConsistencyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: IstiqamahWidgetSnapshot
    let configuration: ConsistencyWidgetConfigurationIntent
}

private struct MessageWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: IstiqamahWidgetSnapshot
    let configuration: MessageWidgetConfigurationIntent
}

private struct FocusWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FocusWidgetEntry {
        FocusWidgetEntry(
            date: Date(),
            snapshot: .placeholder,
            configuration: FocusWidgetConfigurationIntent()
        )
    }

    func snapshot(
        for configuration: FocusWidgetConfigurationIntent,
        in context: Context
    ) async -> FocusWidgetEntry {
        FocusWidgetEntry(
            date: Date(),
            snapshot: context.isPreview ? .placeholder : loadedSnapshot(),
            configuration: configuration
        )
    }

    func timeline(
        for configuration: FocusWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<FocusWidgetEntry> {
        let snapshot = loadedSnapshot()
        let dates = WidgetTimelineDates.entries(for: snapshot)
        let entries = dates.map {
            FocusWidgetEntry(date: $0, snapshot: snapshot, configuration: configuration)
        }
        return Timeline(entries: entries, policy: .after(WidgetTimelineDates.reloadDate(after: dates)))
    }

    private func loadedSnapshot() -> IstiqamahWidgetSnapshot {
        IstiqamahWidgetStore.load() ?? .empty()
    }
}

private struct ConsistencyWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConsistencyWidgetEntry {
        ConsistencyWidgetEntry(
            date: Date(),
            snapshot: .placeholder,
            configuration: ConsistencyWidgetConfigurationIntent()
        )
    }

    func snapshot(
        for configuration: ConsistencyWidgetConfigurationIntent,
        in context: Context
    ) async -> ConsistencyWidgetEntry {
        ConsistencyWidgetEntry(
            date: Date(),
            snapshot: context.isPreview ? .placeholder : loadedSnapshot(),
            configuration: configuration
        )
    }

    func timeline(
        for configuration: ConsistencyWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<ConsistencyWidgetEntry> {
        let snapshot = loadedSnapshot()
        let dates = WidgetTimelineDates.entries(for: snapshot)
        let entries = dates.map {
            ConsistencyWidgetEntry(date: $0, snapshot: snapshot, configuration: configuration)
        }
        return Timeline(entries: entries, policy: .after(WidgetTimelineDates.reloadDate(after: dates)))
    }

    private func loadedSnapshot() -> IstiqamahWidgetSnapshot {
        IstiqamahWidgetStore.load() ?? .empty()
    }
}

private struct MessageWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MessageWidgetEntry {
        MessageWidgetEntry(
            date: Date(),
            snapshot: .placeholder,
            configuration: MessageWidgetConfigurationIntent()
        )
    }

    func snapshot(
        for configuration: MessageWidgetConfigurationIntent,
        in context: Context
    ) async -> MessageWidgetEntry {
        MessageWidgetEntry(
            date: Date(),
            snapshot: context.isPreview ? .placeholder : loadedSnapshot(),
            configuration: configuration
        )
    }

    func timeline(
        for configuration: MessageWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<MessageWidgetEntry> {
        let date = Date()
        let entry = MessageWidgetEntry(date: date, snapshot: loadedSnapshot(), configuration: configuration)
        return Timeline(entries: [entry], policy: .after(date.addingTimeInterval(30 * 60)))
    }

    private func loadedSnapshot() -> IstiqamahWidgetSnapshot {
        IstiqamahWidgetStore.load() ?? .empty()
    }
}

private enum WidgetTimelineDates {
    static func entries(for snapshot: IstiqamahWidgetSnapshot, now: Date = Date()) -> [Date] {
        var dates = [now]
        for block in [snapshot.currentBlock, snapshot.nextBlock].compactMap({ $0 }) {
            if block.startDate > now { dates.append(block.startDate) }
            if block.endDate > now { dates.append(block.endDate) }
        }
        return Array(Set(dates)).sorted()
    }

    static func reloadDate(after dates: [Date]) -> Date {
        max(dates.last ?? Date(), Date()).addingTimeInterval(30 * 60)
    }
}

struct IstiqamahFocusWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: IstiqamahWidgetStore.focusWidgetKind,
            intent: FocusWidgetConfigurationIntent.self,
            provider: FocusWidgetProvider()
        ) { entry in
            FocusWidgetView(entry: entry)
        }
        .configurationDisplayName("Istiqamah Focus")
        .description("See the running block, the next block, and your personal intention.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct IstiqamahConsistencyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: IstiqamahWidgetStore.consistencyWidgetKind,
            intent: ConsistencyWidgetConfigurationIntent.self,
            provider: ConsistencyWidgetProvider()
        ) { entry in
            ConsistencyWidgetView(entry: entry)
        }
        .configurationDisplayName("Istiqamah Consistency")
        .description("Keep today's completion and your current streak visible.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct IstiqamahMessageWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: IstiqamahWidgetStore.messageWidgetKind,
            intent: MessageWidgetConfigurationIntent.self,
            provider: MessageWidgetProvider()
        ) { entry in
            MessageWidgetView(entry: entry)
        }
        .configurationDisplayName("Istiqamah Message")
        .description("Keep your intention visible on your Home Screen or Lock Screen.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

private struct MessageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: MessageWidgetEntry

    private var text: String {
        entry.snapshot.messageText(override: entry.configuration.customText)
    }

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                lockScreenMessage
            } else {
                homeScreenMessage
            }
        }
        .widgetURL(URL(string: "project-istiqamah://today"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.09, green: 0.12, blue: 0.10), Color(red: 0.12, green: 0.17, blue: 0.14)]
                    : [Color(red: 0.97, green: 0.98, blue: 0.96), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var lockScreenMessage: some View {
        HStack(alignment: .center, spacing: 8) {
            IstiqamahMark(primary: .primary, secondary: .primary.opacity(0.55))
                .frame(width: 23, height: 23)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text("MY INTENTION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.9)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var homeScreenMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IstiqamahMark(
                    primary: colorScheme == .dark
                        ? Color(red: 0.56, green: 0.83, blue: 0.72)
                        : Color(red: 0.21, green: 0.42, blue: 0.36),
                    secondary: Color(red: 0.66, green: 0.84, blue: 0.76)
                )
                .frame(width: 25, height: 25)
                .widgetAccentable()
                Text("MY INTENTION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(text)
                .font(.title3.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Text("PROJECT ISTIQAMAH")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .padding(5)
    }
}

private struct FocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: FocusWidgetEntry

    private var runningBlock: WidgetBlockSummary? {
        if let current = entry.snapshot.currentBlock,
           current.startDate <= entry.date,
           entry.date < current.endDate {
            return current
        }
        if let next = entry.snapshot.nextBlock,
           next.startDate <= entry.date,
           entry.date < next.endDate {
            return next
        }
        return nil
    }

    private var upcomingBlock: WidgetBlockSummary? {
        guard entry.configuration.showNextBlock,
              let next = entry.snapshot.nextBlock,
              next.startDate > entry.date else { return nil }
        return next
    }

    private var displayBlock: WidgetBlockSummary? { runningBlock ?? upcomingBlock }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                accessoryInline
            case .accessoryRectangular:
                accessoryRectangular
            case .systemMedium:
                systemMedium
            default:
                systemSmall
            }
        }
        .widgetURL(displayBlock?.deepLink ?? URL(string: "project-istiqamah://today"))
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var accessoryInline: some View {
        Label {
            Text(accessorySummary)
        } icon: {
            Image(systemName: runningBlock == nil ? "calendar" : "timer")
        }
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            IstiqamahMark(primary: .primary, secondary: .primary.opacity(0.55))
                .frame(width: 28, height: 28)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text(runningBlock == nil ? "UP NEXT" : "FOCUS NOW")
                    .font(.system(size: 9, weight: .bold))
                Text(displayBlock?.name ?? "Plan your next block")
                    .font(.headline)
                    .lineLimit(1)
                compactTiming
                    .font(.caption2)
            }
        }
    }

    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 9) {
            brandHeader
            Spacer(minLength: 0)
            Text(displayBlock?.name ?? "Ready for your next block")
                .font(.headline)
                .foregroundStyle(primaryText)
                .lineLimit(2)
            compactTiming
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            if entry.configuration.showPersonalMessage {
                Text(personalMessage)
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(4)
    }

    private var systemMedium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                brandHeader
                Text(displayBlock?.name ?? "Your day is clear")
                    .font(.title3.bold())
                    .foregroundStyle(primaryText)
                    .lineLimit(2)
                compactTiming
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(border)

            VStack(alignment: .leading, spacing: 8) {
                if entry.configuration.showPersonalMessage {
                    Text(personalMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(primaryText)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Label(
                    "\(entry.snapshot.completedToday)/\(entry.snapshot.totalToday) today",
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(4)
    }

    private var brandHeader: some View {
        HStack(spacing: 7) {
            IstiqamahMark(primary: accent, secondary: mint)
                .frame(width: 24, height: 24)
                .widgetAccentable()
            Text(runningBlock == nil ? "UP NEXT" : "FOCUS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(secondaryText)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var compactTiming: some View {
        if let runningBlock {
            if runningBlock.isPaused {
                Label("Paused", systemImage: "pause.fill")
            } else {
                Text(runningBlock.endDate, style: .timer)
                    .monospacedDigit()
            }
        } else if let upcomingBlock {
            Text(upcomingBlock.startDate, style: .time)
        } else {
            Text("Open the app to plan")
        }
    }

    private var accessorySummary: String {
        if let runningBlock { return "\(runningBlock.name) · focus now" }
        if let upcomingBlock { return "\(upcomingBlock.name) · up next" }
        return "Open Project Istiqamah to plan"
    }

    private var personalMessage: String {
        let trimmed = entry.snapshot.personalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Keep showing up." : trimmed
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [background, surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.07, blue: 0.06)
            : Color(red: 0.97, green: 0.98, blue: 0.96)
    }

    private var surface: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.14, blue: 0.13)
            : .white
    }

    private var primaryText: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.96, blue: 0.95)
            : Color(red: 0.09, green: 0.13, blue: 0.11)
    }

    private var secondaryText: Color {
        colorScheme == .dark
            ? Color(red: 0.62, green: 0.67, blue: 0.65)
            : Color(red: 0.41, green: 0.45, blue: 0.44)
    }

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 0.56, green: 0.83, blue: 0.72)
            : Color(red: 0.21, green: 0.42, blue: 0.36)
    }

    private var mint: Color {
        colorScheme == .dark
            ? Color(red: 0.66, green: 0.89, blue: 0.79)
            : Color(red: 0.66, green: 0.84, blue: 0.76)
    }

    private var border: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.20, blue: 0.18)
            : Color(red: 0.87, green: 0.89, blue: 0.87)
    }
}

private struct ConsistencyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: ConsistencyWidgetEntry

    private var progress: Double {
        guard entry.snapshot.totalToday > 0 else { return 0 }
        return min(1, Double(entry.snapshot.completedToday) / Double(entry.snapshot.totalToday))
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                accessoryCircular
            case .accessoryRectangular:
                accessoryRectangular
            case .systemMedium:
                systemMedium
            default:
                systemSmall
            }
        }
        .widgetURL(URL(string: "project-istiqamah://progress"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [background, surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accessoryCircular: some View {
        Gauge(value: progress) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text("\(entry.snapshot.completedToday)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.configuration.showStreak ? "chart.line.uptrend.xyaxis" : "checkmark.circle.fill")
                .font(.title2)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.configuration.showStreak
                    ? "\(entry.snapshot.currentStreak) day streak"
                    : "\(entry.snapshot.completedToday) of \(entry.snapshot.totalToday) today")
                    .font(.headline)
                ProgressView(value: progress)
                    .tint(.primary)
            }
        }
    }

    private var systemSmall: some View {
        VStack(spacing: 10) {
            HStack {
                IstiqamahMark(primary: accent, secondary: mint)
                    .frame(width: 24, height: 24)
                    .widgetAccentable()
                Spacer()
                if entry.configuration.showStreak {
                    Label("\(entry.snapshot.currentStreak)", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.bold())
                        .foregroundStyle(accent)
                }
            }
            ProgressRing(progress: progress, accent: accent, track: track)
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(entry.snapshot.completedToday)")
                            .font(.title.bold())
                        Text("OF \(entry.snapshot.totalToday)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(secondaryText)
                    }
                }
            Text("TODAY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(secondaryText)
        }
        .padding(3)
    }

    private var systemMedium: some View {
        HStack(spacing: 18) {
            ProgressRing(progress: progress, accent: accent, track: track)
                .frame(width: 92, height: 92)
                .overlay {
                    VStack(spacing: 1) {
                        Text("\(entry.snapshot.completedToday)/\(entry.snapshot.totalToday)")
                            .font(.title3.bold())
                        Text("TODAY")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(secondaryText)
                    }
                }
            VStack(alignment: .leading, spacing: 8) {
                Text("CONSISTENCY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(secondaryText)
                if entry.configuration.showStreak {
                    Text("\(entry.snapshot.currentStreak) day streak")
                        .font(.title2.bold())
                        .foregroundStyle(primaryText)
                }
                if entry.configuration.showPersonalMessage {
                    Text(personalMessage)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(4)
    }

    private var personalMessage: String {
        let trimmed = entry.snapshot.personalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Keep showing up." : trimmed
    }

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.07, blue: 0.06)
            : Color(red: 0.97, green: 0.98, blue: 0.96)
    }

    private var surface: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.14, blue: 0.13)
            : .white
    }

    private var primaryText: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.96, blue: 0.95)
            : Color(red: 0.09, green: 0.13, blue: 0.11)
    }

    private var secondaryText: Color {
        colorScheme == .dark
            ? Color(red: 0.62, green: 0.67, blue: 0.65)
            : Color(red: 0.41, green: 0.45, blue: 0.44)
    }

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 0.56, green: 0.83, blue: 0.72)
            : Color(red: 0.21, green: 0.42, blue: 0.36)
    }

    private var mint: Color {
        colorScheme == .dark
            ? Color(red: 0.66, green: 0.89, blue: 0.79)
            : Color(red: 0.66, green: 0.84, blue: 0.76)
    }

    private var track: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.20, blue: 0.18)
            : Color(red: 0.87, green: 0.89, blue: 0.87)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let accent: Color
    let track: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: 9)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .accessibilityLabel("Today's completion")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}
