# Project Istiqamah

Project Istiqamah is a private, local-first time-blocking and consistency app
built natively for iPhone with SwiftUI. It helps you define intentional blocks,
break them into small actions, record completion, and review consistency.

The native application lives in [`artifacts/project-istiqamah`](artifacts/project-istiqamah).

## Native iOS architecture

- SwiftUI application and navigation
- ActivityKit Live Activity plus configurable Home Screen and Lock Screen widgets
- BackgroundTasks refresh for best-effort system wakeups
- Codable JSON persistence in Application Support
- UserNotifications reminders, start alerts, and completion alerts
- Charts-based seven-day progress dashboard
- XcodeGen project definition committed as `project.json`
- No Expo, React Native, JavaScript bundle, CocoaPods, account, or backend

## What works now

| Area | Implemented behavior |
| --- | --- |
| App navigation | Native SwiftUI tabs for Today, Blocks, Progress, and Settings |
| Block planning | Create and edit weekday schedules with native time pickers, use Reorder mode to swap complete schedule slots, and archive or restore blocks without losing completion history |
| Daily view | Previous/next-day navigation, return to today, a running block with live actions or the next upcoming block, and a Start a block shortcut when nothing remains scheduled |
| Completion | Mark blocks and individual actions complete after their start time; Today's System shows date-specific Done/Undone action status |
| Progress | Weekday-aware seven-day chart, completed-block total, practiced-day count, consistency percentage, current streak, and active or archived per-block totals |
| Reminders | Time-sensitive alerts before a block, when it starts, and when it ends; start alerts offer I Know and configurable 5/10/15-minute Snooze actions, and dismissing one snoozes it |
| Reminder sounds | System notification, iOS 26 system ringtone, three bundled tones, and a user-imported audio clip up to 30 seconds converted to notification-safe CAF audio |
| Live Activities | Starts or updates the current block, removes completed or outdated activities, schedules upcoming starts on iOS 26, and provides status, refresh, and restart controls in Settings |
| Background refresh | Reloads saved blocks during system-granted background time, refreshes notifications and Live Activities, and schedules the next best-effort wakeup near a block transition |
| Dynamic Island | Branded compact mark and remaining time; touch-and-hold expanded controls, large timer, and four-column block metrics |
| Lock Screen | Branded timer header with circular Pause/Resume and End controls, divider, and elapsed/start/end/status metrics |
| Widgets | Separate configurable Focus and Consistency widgets for Home Screen and Lock Screen, backed by shared app data and an optional personal message |
| Deep links | Notification and Live Activity taps open the Today tab on the relevant date and block; an ended-block link can record completion |
| Local data | Codable JSON persistence in Application Support, visible save/recovery failures, preservation of unreadable data, and exclusion of private app data from device/iCloud backup |
| Preferences | Reminder toggle, early-reminder and snooze timing, bundled/system/imported sound choice, widget message, haptic toggle, notification permission status, and shortcut to iOS Settings |
| Backup | Pretty-printed JSON export and validated, size-bounded restore through native share and file-import sheets |
| Verification | XCTest coverage for schedules, migration, archives, and backup validation; UI navigation/reorder smoke test; Lock Screen and compact/expanded Dynamic Island preview fixtures |
| CI package | Manual or version-tag GitHub Action builds the app and embedded Live Activity extension into an unsigned IPA |

The code and project configuration for these behaviors are present. The JSON
project definition, property lists, embedded widget target, sound resources,
and unsigned-IPA workflow can be checked without launching the app. A complete
runtime check of notifications, Lock Screen presentation, and Dynamic Island
presentation requires a signed build on a physical iPhone with notification
and Live Activity permissions enabled.

## Build requirements

- macOS with Xcode 26 or later
- XcodeGen
- iOS 18 or later deployment target

Generate the Xcode project:

```bash
cd artifacts/project-istiqamah
xcodegen generate --spec project.json
open ProjectIstiqamah.xcodeproj
```

Choose an Apple development team in Xcode, then run the `ProjectIstiqamah`
scheme on an iPhone. Live Activities require a physical supported device for
complete Dynamic Island testing.

Run the native test targets from Xcode with Product → Test, or from macOS:

```bash
xcodebuild test \
  -project ProjectIstiqamah.xcodeproj \
  -scheme ProjectIstiqamah \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Unsigned IPA

The GitHub workflow in `.github/workflows/build-ios-ipa.yml` generates the
Xcode project, builds the native app and widget extension, and publishes an
unsigned IPA artifact. See [`docs/github-actions-ios.md`](docs/github-actions-ios.md).

## Repository structure

| Path | Purpose |
| --- | --- |
| `artifacts/project-istiqamah/Sources/App` | SwiftUI app, persistence, notifications, and ActivityKit lifecycle |
| `artifacts/project-istiqamah/Sources/Shared` | Activity attributes shared with the widget extension |
| `artifacts/project-istiqamah/Sources/Widgets` | Native WidgetKit and Dynamic Island UI |
| `artifacts/project-istiqamah/Config` | Generated app and extension property-list paths |
| `artifacts/project-istiqamah/Resources/Sounds` | Bundled Linear PCM reminder sounds |
| `artifacts/project-istiqamah/project.json` | XcodeGen project source of truth |

## Current limitations and next work

- Existing Expo AsyncStorage data is not automatically migrated; export it
  before installing the native rewrite if it must be retained.
- Scheduled Live Activity starts require iOS 26. On iOS 18–25, the current
  block starts its Live Activity whenever the app is active and notifications
  remain the background fallback.
- iOS does not allow this app to run continuously. Background App Refresh is
  system-controlled and may run later than requested or not run at all, so it
  cannot guarantee an exact Live Activity start.
- Immediate WhatsApp-style remote updates require an APNs provider and backend.
  This local-first app has no account or server, so it does not register or
  upload push tokens.
- Dynamic Island is available only on supported iPhone models. Its running,
  paused, and completed states use the same compact branded mark and state-aware
  timer/status content. iOS controls when compact, minimal, and expanded
  presentations appear; an app cannot auto-hide only the Dynamic Island after
  ten seconds while keeping the same Live Activity on the Lock Screen.
- iOS doesn't expose the full built-in tone or ringtone catalog to third-party
  apps. Project Istiqamah offers the system notification, the system ringtone
  where available, bundled tones, and imported clips instead.
- App and widget targets use the `group.com.projectistiqamah.shared` App Group.
  A signed build must enable that App Group for both bundle identifiers so the
  widgets can read current app data. The shared snapshot is written atomically
  to the App Group container, and the runtime also recognizes an Istiqamah App
  Group identifier rewritten consistently by a sideload signer. In Settings,
  `Widget data` reports when the installed signature has no usable shared group.
- Lock Screen widgets and Live Activities are independent system surfaces. If a
  person installs one of the accessory widgets, iOS can show it in the widget
  area while the running block Live Activity remains visible below it.
- An unsigned IPA must be signed before it can be installed on an iPhone.
- Standard time-sensitive notification sounds still respect the device's notification, silent-mode, and Focus settings. Clock-style overrides require AlarmKit on iOS 26 or Apple's restricted Critical Alerts entitlement.
- Templates, tags, and search are not implemented.
- Screen Time integration still requires Apple's Family Controls entitlement.
- Accessibility and localization need a complete device audit.
- Dynamic Island preview fixtures still require Xcode and a supported iPhone
  to confirm the final system-controlled geometry and transitions.

## Data and privacy

Task content and preferences stay in the app's Application Support directory,
which is excluded from device and iCloud backups. Data leaves the device only
when the user explicitly shares an exported backup.

## License

MIT
