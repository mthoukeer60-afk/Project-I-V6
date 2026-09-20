import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct BlockLiveActivityWidget: Widget {
    private let accent = Color(red: 0.40, green: 0.43, blue: 0.96)

    private enum CompactMetrics {
        static let iconPointSize: CGFloat = 12
        static let iconFrameSize: CGFloat = 16
        static let timerMinimumWidth: CGFloat = 40
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.055, green: 0.055, blue: 0.065))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    activityIcon(context, size: 16)
                        .frame(width: 20, height: 20)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        countdown(context)
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .minimumScaleFactor(0.72)
                        Text(context.isStale ? "COMPLETE" : "REMAINING")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 104, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(statusLabel(context))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(accent)
                            Text(blockTitle(context))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        progress(context)
                            .labelsHidden()
                            .progressViewStyle(.linear)
                            .tint(accent)
                            .scaleEffect(y: 0.5)
                            .frame(height: 2)

                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                elapsed(context)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(context.isStale ? "DURATION" : "ELAPSED")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                            Spacer(minLength: 6)
                            dynamicIslandActions(context)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                compactIcon(context)
                    .accessibilityLabel("\(blockTitle(context)), \(statusLabel(context))")
            } compactTrailing: {
                compactTimer(context)
            } minimal: {
                minimalContent(context)
            }
            .widgetURL(context.attributes.deepLink)
            .keylineTint(accent)
            .contentMargins(.horizontal, 24, for: .expanded)
            .contentMargins(.bottom, 24, for: .expanded)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        VStack(spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                activityIcon(context, size: 16)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusLabel(context))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(blockTitle(context))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    countdown(context)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.75)
                    Text(context.isStale ? "COMPLETE" : "REMAINING")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 110, alignment: .trailing)
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            progress(context)
                .labelsHidden()
                .progressViewStyle(.linear)
                .tint(accent)
                .scaleEffect(y: 0.55)
                .frame(height: 2)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        elapsed(context)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(context.isStale ? "DURATION" : "ELAPSED")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(lockScreenTimeLabel(context))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                activityActions(context)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func activityActions(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if !context.isStale {
            Button(intent: SetBlockPausedIntent(
                blockID: context.attributes.blockID,
                dateKey: context.attributes.dateKey,
                paused: !context.state.isPaused
            )) {
                Label(
                    context.state.isPaused ? "Resume" : "Pause",
                    systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(intent: EndBlockIntent(
                blockID: context.attributes.blockID,
                dateKey: context.attributes.dateKey
            )) {
                Label("End", systemImage: "stop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.16))
                    }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dynamicIslandActions(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if !context.isStale {
            Button(intent: SetBlockPausedIntent(
                blockID: context.attributes.blockID,
                dateKey: context.attributes.dateKey,
                paused: !context.state.isPaused
            )) {
                Label(
                    context.state.isPaused ? "Resume" : "Pause",
                    systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(intent: EndBlockIntent(
                blockID: context.attributes.blockID,
                dateKey: context.attributes.dateKey
            )) {
                Label("End", systemImage: "stop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.16))
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func compactTimer(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        countdown(context)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .frame(minWidth: CompactMetrics.timerMinimumWidth, alignment: .trailing)
            .foregroundStyle(accent)
            .accessibilityLabel("Time remaining")
    }

    private func compactIcon(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        activityIcon(context, size: CompactMetrics.iconPointSize)
            .frame(
                width: CompactMetrics.iconFrameSize,
                height: CompactMetrics.iconFrameSize
            )
            .fixedSize()
    }

    private func minimalContent(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        compactIcon(context)
    }

    @ViewBuilder
    private func elapsed(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if context.isStale {
            Text(formattedDuration(context.state.endDate.timeIntervalSince(context.state.startDate)))
                .monospacedDigit()
        } else if let pausedAt = context.state.pausedAt {
            Text(formattedDuration(pausedAt.timeIntervalSince(context.state.startDate)))
                .monospacedDigit()
        } else {
            Text(context.state.startDate, style: .timer)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if context.isStale {
            Text("00:00")
                .monospacedDigit()
                .lineLimit(1)
        } else if let pausedAt = context.state.pausedAt {
            Text(formattedDuration(context.state.endDate.timeIntervalSince(pausedAt)))
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text(context.state.endDate, style: .timer)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func progress(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if context.isStale {
            ProgressView(value: 1)
        } else if let pausedAt = context.state.pausedAt {
            ProgressView(value: progressValue(at: pausedAt, context: context))
        } else {
            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: false
            )
        }
    }

    @ViewBuilder
    private func activityIcon(
        _ context: ActivityViewContext<BlockActivityAttributes>,
        size: CGFloat
    ) -> some View {
        if context.isStale {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityLabel("Block ended")
        } else {
            flame(size: size, isActive: !context.state.isPaused)
        }
    }

    private func flame(size: CGFloat, isActive: Bool) -> some View {
        FlameIcon(size: size, isActive: isActive)
    }

    private func statusLabel(_ context: ActivityViewContext<BlockActivityAttributes>) -> String {
        if context.isStale { return "BLOCK ENDED" }
        if context.state.isPaused { return "PAUSED" }
        return "FOCUS"
    }

    private func blockTitle(_ context: ActivityViewContext<BlockActivityAttributes>) -> String {
        context.isStale ? "Block complete" : context.state.blockName
    }

    private func lockScreenTimeLabel(_ context: ActivityViewContext<BlockActivityAttributes>) -> String {
        if context.isStale { return "Completed" }
        if context.state.isPaused { return "Paused · \(context.state.timeLabel)" }
        return context.state.timeLabel
    }

    private func progressValue(
        at date: Date,
        context: ActivityViewContext<BlockActivityAttributes>
    ) -> Double {
        let duration = max(1, context.state.endDate.timeIntervalSince(context.state.startDate))
        return max(0, min(1, date.timeIntervalSince(context.state.startDate) / duration))
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct FlameIcon: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let size: CGFloat
    let isActive: Bool

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange, .red],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .symbolEffect(
                .variableColor.iterative,
                options: .repeating.speed(0.68),
                isActive: isActive && !isLuminanceReduced
            )
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(isActive ? "Block running" : "Block paused")
    }
}

#if DEBUG
private let previewAttributes = BlockActivityAttributes(
    blockID: UUID(),
    dateKey: "2026-09-17"
)

private let previewState = BlockActivityAttributes.ContentState(
    blockName: "Deep Work Session",
    startDate: Date().addingTimeInterval(-20 * 60),
    endDate: Date().addingTimeInterval(40 * 60),
    timeLabel: "09:00 – 10:00",
    pausedAt: nil
)

private let previewLongState = BlockActivityAttributes.ContentState(
    blockName: "Physics Revision and Practice",
    startDate: Date().addingTimeInterval(-35 * 60),
    endDate: Date().addingTimeInterval(3 * 60 * 60),
    timeLabel: "18:35 – 22:10",
    pausedAt: nil
)

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}
#endif
