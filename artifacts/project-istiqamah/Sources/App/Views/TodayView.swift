import Combine
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var now = Date()
    let onStartBlock: () -> Void
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var selectedKey: String { DateTools.key(store.selectedDate) }
    private var isToday: Bool { selectedKey == DateTools.key(Date()) }

    private var selectedSchedule: [ScheduledBlock] {
        store.activeBlocks.compactMap { block in
            guard let window = DateTools.window(for: block, on: store.selectedDate) else { return nil }
            return ScheduledBlock(
                block: block,
                dateKey: DateTools.key(window.start),
                start: window.start,
                end: window.end
            )
        }.sorted { $0.start < $1.start }
    }

    private var featuredBlock: ScheduledBlock? {
        guard isToday else { return nil }
        if let running = DateTools.activeBlock(in: store.activeBlocks, at: now) {
            return running
        }
        return selectedSchedule.first {
            now < $0.start && !$0.block.completedDates.contains($0.dateKey)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateCard
                    if let featuredBlock {
                        focusCard(featuredBlock)
                        if phase(for: featuredBlock) == .running {
                            actionsCard(featuredBlock)
                        }
                    } else {
                        startBlockCard
                    }
                    dayList
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Project I")
            .foregroundStyle(AppTheme.primaryText)
        }
        .onReceive(timer) { now = $0 }
        .onReceive(store.$timelineDate) { now = $0 }
    }

    private var startBlockCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.primary)
            Text("No block is scheduled")
                .font(.headline)
            Text("Create a block or adjust its time in Blocks.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Start a block", systemImage: "plus") {
                onStartBlock()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .istiqamahCard()
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CURRENT DATE")
                .font(.caption2.bold())
                .tracking(1.4)
                .foregroundStyle(AppTheme.secondaryText)
            HStack {
                Button { moveDay(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text(DateTools.displayDate(store.selectedDate))
                        .font(.headline)
                    if !isToday {
                        Button("Return to today") { store.selectDate(Date()) }
                            .font(.caption)
                    }
                }
                Spacer()
                Button { moveDay(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
            }
        }
        .padding(18)
        .istiqamahCard()
    }

    private func focusCard(_ item: ScheduledBlock) -> some View {
        let phase = phase(for: item)
        let completed = item.block.completedDates.contains(item.dateKey)
        let pausedAt = store.pauseDate(for: item)
        let effectiveNow = pausedAt ?? now
        let remaining = phase == .upcoming
            ? item.start.timeIntervalSince(now)
            : item.end.timeIntervalSince(effectiveNow)
        let duration = max(1, item.end.timeIntervalSince(item.start))
        let progress = phase == .running
            ? max(0, min(1, effectiveNow.timeIntervalSince(item.start) / duration))
            : phase == .ended ? 1 : 0
        let isActivelyRunning = phase == .running && pausedAt == nil

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(phase.label)
                    .font(.caption2.bold())
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                Image(systemName: pausedAt == nil ? (phase == .running ? "clock.fill" : "timer") : "pause.circle.fill")
                    .foregroundStyle(AppTheme.primary)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeating.speed(0.7),
                        isActive: isActivelyRunning
                    )
            }
            Text(item.block.name)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
            Text(DateTools.clock(seconds: remaining))
                .font(.system(size: 46, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
            ProgressView(value: progress)
                .tint(AppTheme.primary)
            HStack {
                Text(pausedAt == nil
                    ? "\(item.block.startTime) – \(item.block.endTime)"
                    : "Paused · slot ends at \(item.block.endTime)"
                )
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if phase == .running {
                    Button(pausedAt == nil ? "Pause" : "Resume") {
                        store.togglePause(item)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.primary)
                }
                if phase == .running {
                    Button(completed ? "Completed" : "End") {
                        store.toggleBlock(item.block.id, dateKey: item.dateKey)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                }
            }
            .font(.caption)
        }
        .padding(20)
        .istiqamahCard()
    }

    @ViewBuilder
    private func actionsCard(_ item: ScheduledBlock) -> some View {
        if !item.block.actions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIONS")
                    .font(.caption2.bold())
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.secondaryText)
                ForEach(item.block.actions) { action in
                    actionRow(action, in: item)
                }
            }
            .padding(18)
            .istiqamahCard()
        }
    }

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(isToday ? "TODAY'S SYSTEM" : "SELECTED DAY'S SYSTEM")
                    .font(.caption2.bold())
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text("\(selectedSchedule.count) \(selectedSchedule.count == 1 ? "BLOCK" : "BLOCKS")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            .padding(.bottom, 8)

            ForEach(selectedSchedule) { item in
                systemBlockRow(item)

                if item.id != selectedSchedule.last?.id {
                    Divider()
                        .overlay(AppTheme.divider)
                        .padding(.leading, 54)
                }
            }
        }
        .padding(18)
        .istiqamahCard()
    }

    private func systemBlockRow(_ item: ScheduledBlock) -> some View {
        let completed = item.block.completedDates.contains(item.dateKey)
        let status = systemStatus(for: item, completed: completed)
        let canToggleCompletion = completed || now >= item.end

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        store.toggleBlock(item.block.id, dateKey: item.dateKey)
                    }
                } label: {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(completed ? AppTheme.completed : AppTheme.tertiaryText)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .background(completed ? AppTheme.completed.opacity(0.12) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(PressedScaleButtonStyle())
                .disabled(!canToggleCompletion)
                .opacity(canToggleCompletion ? 1 : 0.55)
                .accessibilityLabel(completed
                    ? "Mark \(item.block.name) incomplete"
                    : "Mark \(item.block.name) complete"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.block.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Label("\(item.block.startTime) – \(item.block.endTime)", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Text(status.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 26)
                    .background(status.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            if item.block.actions.isEmpty {
                Text("No actions")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.leading, 54)
            } else {
                VStack(spacing: 4) {
                    ForEach(item.block.actions) { action in
                        actionRow(action, in: item)
                    }
                }
                .padding(.leading, 54)
            }
        }
        .padding(.vertical, 10)
    }

    private func actionRow(_ action: BlockAction, in item: ScheduledBlock) -> some View {
        let completed = action.completedDates.contains(item.dateKey)
        let canToggle = completed || now >= item.start

        return HStack(spacing: 10) {
            Text(action.name)
                .font(.subheadline)
                .foregroundStyle(completed ? AppTheme.secondaryText : AppTheme.primaryText)
                .strikethrough(completed, color: AppTheme.secondaryText)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    store.toggleAction(action.id, in: item.block.id, dateKey: item.dateKey)
                }
            } label: {
                Label(completed ? "Done" : "Mark done", systemImage: completed ? "checkmark" : "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completed ? AppTheme.completed : AppTheme.primaryText)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 36)
                    .background(completed ? AppTheme.completed.opacity(0.14) : AppTheme.elevatedSurface)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(completed ? AppTheme.completed.opacity(0.26) : AppTheme.border)
                    }
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressedScaleButtonStyle())
            .disabled(!canToggle)
            .opacity(canToggle ? 1 : 0.5)
            .accessibilityLabel(completed
                ? "Mark \(action.name) incomplete"
                : "Mark \(action.name) done"
            )
        }
        .frame(minHeight: 44)
    }

    private func systemStatus(for item: ScheduledBlock, completed: Bool) -> SystemBlockStatus {
        if completed { return .completed }
        if now < item.start { return .upcoming }
        if now < item.end { return .running }
        return .incomplete
    }

    private func moveDay(_ amount: Int) {
        let date = Calendar.current.date(byAdding: .day, value: amount, to: store.selectedDate) ?? store.selectedDate
        store.selectDate(date)
    }

    private func phase(for item: ScheduledBlock) -> BlockPhase {
        if now < item.start { return .upcoming }
        if now < item.end { return .running }
        return .ended
    }
}

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum SystemBlockStatus {
    case completed
    case running
    case upcoming
    case incomplete

    var title: String {
        switch self {
        case .completed: "DONE"
        case .running: "RUNNING"
        case .upcoming: "UPCOMING"
        case .incomplete: "UNDONE"
        }
    }

    var color: Color {
        switch self {
        case .completed: AppTheme.completed
        case .running: AppTheme.primary
        case .upcoming: AppTheme.info
        case .incomplete: AppTheme.warning
        }
    }
}

private enum BlockPhase {
    case upcoming
    case running
    case ended

    var label: String {
        switch self {
        case .upcoming: "NEXT BLOCK"
        case .running: "RUNNING BLOCK"
        case .ended: "BLOCK ENDED"
        }
    }
}
