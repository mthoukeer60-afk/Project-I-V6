# Dynamic Island and Live Activity Guide

This guide maps the Live Activity implementation so layout changes can stay
isolated from the rest of the app. The redesign started from the source used by
successful GitHub Actions run **Build unsigned iOS IPA #14**, commit
`7d6a38baeda24d53c44d95f26f8a43957526e8c2`, and intentionally replaces that
build's denser presentation with the clean metric layout documented below.

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
| `Sources/Widgets/BlockLiveActivityWidget.swift` | All Lock Screen and Dynamic Island visuals, sizing, metrics, buttons, and previews |
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
| Lock Screen/banner | `lockScreen(_:)` | Clock/pause/checkmark, large timer, circular Pause/Resume and End controls, divider, and metric grid |
| Compact leading | `compactLeading` closure | Running clock, paused symbol, or completed checkmark |
| Compact trailing | `compactTrailing` closure | Empty, so the compact island stays at the system minimum width |
| Minimal | `minimal` and `minimalContent(_:)` | Icon only; used when iOS is showing multiple Live Activities |
| Expanded leading | `DynamicIslandExpandedRegion(.leading)` | Circular Pause/Resume and End controls |
| Expanded trailing | `DynamicIslandExpandedRegion(.trailing)` | Large gold countdown |
| Expanded bottom | `DynamicIslandExpandedRegion(.bottom)` | Elapsed/duration, start, end, and status metric grid |

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
EmptyView()
```

Compact mode is intentionally icon-only. A live timer can reserve a wide ideal
size even when iOS clips its digits, which stretches the black capsule. Keeping
the trailing region empty leaves the island at its system-controlled minimum
width. The countdown remains visible in expanded and Lock Screen presentations.

### Expanded

| Element | Current value |
| --- | --- |
| Leading controls | Two `36 x 36` circular buttons for Pause/Resume and End |
| Countdown | 28-point semibold monospaced font in warm gold |
| Countdown container | Maximum width `120` |
| Bottom metrics | Elapsed/duration, start, end, and status |
| Metric value/label fonts | `12` and `7` |
| Expanded horizontal content margins | `20` |
| Expanded bottom content margin | `20` |

Edit the three `DynamicIslandExpandedRegion` blocks and the two
`.contentMargins` modifiers to change the expanded appearance.

### Lock Screen

| Element | Current value |
| --- | --- |
| Icon | 24-point symbol in a `30 x 30` frame |
| Countdown | 32-point medium monospaced font in warm gold |
| Pause/Resume and End controls | Two `40 x 40` circular buttons |
| Bottom metrics | Elapsed/duration, start, end, and status |
| Outer padding | `16` on all sides |

Edit `lockScreen(_:)` and `activityActions(_:)` for this presentation. These
changes do not control the compact Dynamic Island.

## State behavior

| State | Icon | Countdown | Labels/actions |
| --- | --- | --- | --- |
| Running | Indigo clock | Live timer to `endDate` | Focus status, Elapsed, Pause, End |
| Paused | Pause circle | Frozen duration from `pausedAt` to `endDate` | Paused status, Resume, End |
| Stale/completed | Checkmark | `00:00` | Block Ended, Duration; action buttons hidden |

`context.isStale` controls the completed visuals. In normal synchronization,
`LiveActivityManager` ends completed or expired activities with an immediate
dismissal policy, so the completed presentation may be brief or not visible.

## Functions used by every presentation

- `countdown(_:)` selects live, paused, or completed time text.
- `elapsed(_:)` selects live, paused, or total duration text.
- `metricGrid(_:)` renders elapsed/duration, start, end, and status.
- `activityIcon(_:size:)` selects clock, pause, or checkmark.
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
