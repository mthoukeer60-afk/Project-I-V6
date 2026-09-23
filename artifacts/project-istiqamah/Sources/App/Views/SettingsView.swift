import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var backupURL: URL?
    @State private var backupError: String?
    @State private var soundImportError: String?
    @State private var showingBackupImporter = false
    @State private var showingSoundImporter = false
    @State private var confirmingBackupRestore = false
    @State private var notificationStatus = "Checking…"
    @State private var backgroundRefreshStatus = "Checking…"

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Haptic feedback", isOn: preferenceBinding(\.haptics))
                    Toggle("Block reminders", isOn: preferenceBinding(\.reminders))
                    Stepper(
                        "Remind me \(store.preferences.reminderMinutes) minutes early",
                        value: reminderBinding,
                        in: 5...15,
                        step: 5
                    )
                    Picker("Snooze block alert", selection: snoozeBinding) {
                        ForEach(AppPreferences.snoozeOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    Picker("Reminder sound", selection: reminderSoundBinding) {
                        ForEach(availableReminderSounds) { sound in
                            Text(reminderSoundTitle(sound)).tag(sound)
                        }
                    }
                }

                Section("Live blocks") {
                    Label("Dynamic Island & Lock Screen", systemImage: "clock.fill")
                        .foregroundStyle(AppTheme.primary)
                    LabeledContent("Status", value: store.liveActivityStatus)
                    LabeledContent("Reminder sync", value: store.notificationSyncStatus)
                    LabeledContent("Background refresh", value: backgroundRefreshStatus)
                    LabeledContent("Refresh request", value: store.backgroundScheduleStatus)
                    Text("ActivityKit schedules upcoming blocks on iOS 26 and starts the current block when the app is active on earlier supported versions.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("iOS chooses when background refresh runs, so notifications remain the reliable fallback for exact block times.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("The Dynamic Island stays compact while a block is active and expands on touch and hold. iOS controls when that compact presentation is shown or hidden.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Refresh Live Activities") {
                        store.refreshSystemFeatures()
                    }
                    Button("Restart current Live Activity") {
                        store.restartLiveActivity()
                    }
                }

                Section("Notifications") {
                    LabeledContent("Permission", value: notificationStatus)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Send test reminder", systemImage: "speaker.wave.2") {
                        store.sendTestReminder()
                    }
                    Button("Import short sound", systemImage: "music.note") {
                        showingSoundImporter = true
                    }
                    if let customName = store.preferences.customReminderSoundDisplayName {
                        LabeledContent("Imported sound", value: customName)
                    }
                    Text("Apple doesn't expose its full tone library to apps. Choose the system notification, the system ringtone on iOS 26, an included tone, or import audio up to 30 seconds. Imported files are converted to notification-safe CAF audio.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    if let notificationTestStatus = store.notificationTestStatus {
                        Text(notificationTestStatus)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    if let soundImportStatus = store.soundImportStatus {
                        Text(soundImportStatus)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    if let soundImportError {
                        Text(soundImportError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.error)
                    }
                }

                Section("Widgets") {
                    TextField(
                        "Personal widget message",
                        text: widgetMessageBinding,
                        axis: .vertical
                    )
                    .lineLimit(2...3)
                    LabeledContent("Widget data", value: store.widgetSyncStatus)
                    Button("Refresh Widgets", systemImage: "arrow.clockwise") {
                        store.refreshSystemFeatures()
                    }
                    Text("Add Focus, Consistency, or Message from the widget gallery. The wide Message widget shows your text from here, or you can set a separate message in Edit Widget. Lock Screen widgets can appear alongside a running Live Activity. If an older Lock Screen widget still shows a sync prompt after updating the app, remove it and add it again.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("Your data") {
                    Button("Prepare JSON backup", systemImage: "square.and.arrow.up") {
                        do {
                            backupURL = try store.exportBackup()
                            backupError = nil
                        } catch {
                            backupURL = nil
                            backupError = "Backup failed: \(error.localizedDescription)"
                        }
                    }
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Share backup", systemImage: "paperplane")
                        }
                    }
                    Button("Restore JSON backup", systemImage: "arrow.counterclockwise") {
                        confirmingBackupRestore = true
                    }
                    LabeledContent("Local storage", value: store.storageStatus)
                    if let backupError {
                        Text(backupError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.error)
                    }
                    Text("Data is stored privately in the app's Application Support directory.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("About") {
                    LabeledContent("Project Istiqamah", value: "1.0.0")
                    Text("A private practice of showing up, one block at a time.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Settings")
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.primary)
            .task {
                await loadNotificationStatus()
                loadBackgroundRefreshStatus()
            }
            .confirmationDialog(
                "Restore backup?",
                isPresented: $confirmingBackupRestore,
                titleVisibility: .visible
            ) {
                Button("Choose backup file", role: .destructive) {
                    showingBackupImporter = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Restoring replaces the current blocks, history, and preferences after the file passes validation.")
            }
            .fileImporter(
                isPresented: $showingSoundImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                importSound(result)
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                restoreBackup(result)
            }
        }
    }

    private func importSound(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            soundImportError = nil
            store.importCustomReminderSound(from: url)
        case let .failure(error):
            soundImportError = "Sound import failed: \(error.localizedDescription)"
        }
    }

    private func restoreBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try store.importBackup(from: url)
            backupURL = nil
            backupError = nil
        } catch {
            backupError = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { value in store.updatePreferences { $0[keyPath: keyPath] = value } }
        )
    }

    private var reminderBinding: Binding<Int> {
        Binding(
            get: { store.preferences.reminderMinutes },
            set: { value in store.updatePreferences { $0.reminderMinutes = value } }
        )
    }

    private var reminderSoundBinding: Binding<ReminderSound> {
        Binding(
            get: { store.preferences.reminderSound },
            set: { value in store.updatePreferences { $0.reminderSound = value } }
        )
    }

    private var widgetMessageBinding: Binding<String> {
        Binding(
            get: { store.preferences.widgetMessage },
            set: { value in
                store.updatePreferences {
                    $0.widgetMessage = AppPreferences.normalizedWidgetMessage(value)
                }
            }
        )
    }

    private var availableReminderSounds: [ReminderSound] {
        ReminderSound.allCases.filter { sound in
            if sound == .custom {
                return store.preferences.customReminderSoundFileName != nil
            }
            if sound == .systemRingtone {
                if #available(iOS 26.0, *) { return true }
                return false
            }
            return true
        }
    }

    private func reminderSoundTitle(_ sound: ReminderSound) -> String {
        if sound == .custom,
           let customName = store.preferences.customReminderSoundDisplayName {
            return customName
        }
        return sound.title
    }

    private var snoozeBinding: Binding<Int> {
        Binding(
            get: { store.preferences.snoozeMinutes },
            set: { value in store.updatePreferences { $0.snoozeMinutes = value } }
        )
    }

    private func loadNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = switch settings.authorizationStatus {
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .denied: "Denied"
        case .notDetermined: "Not requested"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }

    private func loadBackgroundRefreshStatus() {
        backgroundRefreshStatus = switch UIApplication.shared.backgroundRefreshStatus {
        case .available: "Available"
        case .denied: "Disabled"
        case .restricted: "Restricted"
        @unknown default: "Unknown"
        }
    }
}
