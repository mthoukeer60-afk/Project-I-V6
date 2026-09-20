# Dynamic Island and Live Activity Guide

This guide maps the Live Activity implementation so layout changes can stay
isolated from the rest of the app. The code baseline is the source used by
successful GitHub Actions run **Build unsigned iOS IPA #14**, commit
`7d6a38baeda24d53c44d95f26f8a43957526e8c2`.

Run: <https://github.com/MasalaOats/Project-I-V5/actions/runs/35307583613>

## How the pieces connect

```text
FocusBlock schedule / AppStore
             |
             v
LiveActivityManager creates and updates ActivityContent
             |
             v
BlockActivityAttributes.ContentState
             |
             v
BlockLiveActivityWidget renders Lock Screen + Dynamic Island
             |
             v
Pause / Resume / End intents return actions to AppStore
```

## File map

| File | Responsibility |
| --- | --- |
| `Sources/Widgets/BlockLiveActivityWidget.swift` | All Lock Screen and Dynamic Island visuals, sizing, labels, progress, buttons, and previews |
| `Sources/Widgets/ProjectIstiqamahWidgets.swift` | Registers the Live Activity widget extension |
| `Sources/Shared/BlockActivityAttributes.swift` | Defines the block identity, content state, pause state, dates, and deep link |
| `Sources/Shared/BlockLiveActivityIntents.swift` | Implements Pause/Resume and End button intents |
| `Sources/App/Services/LiveActivityManager.swift` | Starts, updates, schedules, restarts, and dismisses Live Activities |
| `Sources/App/AppStore.swift` | Synchronizes app data and handles actions returned by Live Activity intents |
| `Sources/App/Services/BackgroundRefreshManager.swift` | Requests best-effort Live Activity synchronization while the app is in the background |
| `project.json` | Declares the widget extension, shared sources, Live Activity support, and app/extension bundle identifiers |
| `Config/WidgetInfo.plist` | WidgetKit extension configuration generated into the project |

## Presentation map

There is one `BlockLiveActivityWidget`, with several system-selected
presentations:

| Presentation | Code to edit in `BlockLiveActivityWidget.swift` | Current Build #14 content |
| --- | --- | --- |
| Lock Screen/banner | `lockScreen(_:)` | Icon, status, title, remaining time, progress, elapsed time, schedule, Pause/Resume, and End |
| Compact leading | `compactLeading` closure | Running flame, paused flame, or completed checkmark |
| Compact trailing | `compactTrailing` and `compactTimer(_:)` | Remaining countdown or `00:00` |
| Minimal | `minimal` and `minimalContent(_:)` | Icon only; used when iOS is showing multiple Live Activities |
| Expanded leading | `DynamicIslandExpandedRegion(.leading)` | Activity icon |
| Expanded trailing | `DynamicIslandExpandedRegion(.trailing)` | Large countdown and Remaining/Complete label |
| Expanded bottom | `DynamicIslandExpandedRegion(.bottom)` | Status, title, progress, elapsed/duration, Pause/Resume, and End |

iOS chooses compact, minimal, or expanded presentation. Normally one active
Live Activity uses compact mode. A long press opens expanded mode. The app can
change the content inside each region, but it cannot set the Dynamic Island's
outer hardware/system dimensions.

## Current sizing controls

All values below are SwiftUI points.

### Compact

```swift
// Leading side
activityIcon(context, size: 12)
    .frame(width: 16, height: 16)

// Trailing side
countdown(context)
    .font(.system(size: 12, weight: .semibold, design: .monospaced))
    .minimumScaleFactor(0.72)
    .lineLimit(1)
```

Build #14 does not force a width on the trailing timer. To experiment with the
small running appearance, change only `compactTimer(_:)`. A fixed `.frame(width:)`
can clip longer hour-based timers; `.frame(minWidth:)` can let the compact view
grow. Check both a short value such as `12:12` and a long value such as
`3:12:12` before settling on either approach.

### Expanded

| Element | Current value |
| --- | --- |
| Leading icon | 16-point symbol in a `20 x 20` frame |
| Countdown | 24-point semibold monospaced font |
| Countdown container | Maximum width `104` |
| Status/title fonts | `10` and `14` |
| Progress frame | Height `2`, visually scaled to half height |
| Elapsed timer | 12-point semibold monospaced font |
| Pause/Resume and End buttons | Height `44` |
| Expanded horizontal content margins | `24` |
| Expanded bottom content margin | `24` |

Edit the three `DynamicIslandExpandedRegion` blocks and the two
`.contentMargins` modifiers to change the expanded appearance.

### Lock Screen

| Element | Current value |
| --- | --- |
| Icon | 16-point symbol in a `22 x 22` frame |
| Title | 16-point semibold font |
| Countdown | 22-point semibold monospaced font |
| Countdown container | Maximum width `110` |
| Outer padding | `14` horizontal and vertical |
| Pause/Resume and End buttons | Height `44` |

Edit `lockScreen(_:)` and `activityActions(_:)` for this presentation. These
changes do not control the compact Dynamic Island.

## State behavior

| State | Icon | Countdown | Labels/actions |
| --- | --- | --- | --- |
| Running | Animated flame | Live timer to `endDate` | Focus, Remaining, Elapsed, Pause, End |
| Paused | Inactive flame | Frozen duration from `pausedAt` to `endDate` | Paused, Resume, End |
| Stale/completed | Checkmark | `00:00` | Block Ended, Complete, Duration; action buttons hidden |

`context.isStale` controls the completed visuals. In normal synchronization,
`LiveActivityManager` ends completed or expired activities with an immediate
dismissal policy, so the completed presentation may be brief or not visible.

## Functions used by every presentation

- `countdown(_:)` selects live, paused, or completed time text.
- `elapsed(_:)` selects live, paused, or total duration text.
- `progress(_:)` renders live, paused, or completed progress.
- `activityIcon(_:size:)` selects flame or checkmark.
- `statusLabel(_:)` returns Focus, Paused, or Block Ended.
- `blockTitle(_:)` returns the block name or Block complete.
- `dynamicIslandActions(_:)` renders expanded Pause/Resume and End buttons.
- `activityActions(_:)` renders the equivalent Lock Screen buttons.

## Preview and device checks

The bottom of `BlockLiveActivityWidget.swift` contains Xcode previews for:

- Lock Screen
- Dynamic Island Compact
- Dynamic Island Minimal
- Dynamic Island Expanded
- A normal block and a long-duration block

After a layout change, check all previews and then verify on a supported
physical iPhone. In particular, test running, paused, long-duration, and stale
states. Xcode previews are useful for content layout, but the device and iOS
still control the final island geometry and transition timing.

Generate and open the project on macOS with:

```bash
cd artifacts/project-istiqamah
xcodegen generate --spec project.json
open ProjectIstiqamah.xcodeproj
```
