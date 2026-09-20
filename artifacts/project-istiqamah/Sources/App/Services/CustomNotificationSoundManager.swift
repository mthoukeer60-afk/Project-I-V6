import AVFoundation
import Foundation

struct ImportedNotificationSound: Sendable {
    let fileName: String
    let displayName: String
}

enum CustomNotificationSoundManager {
    static let maximumDuration: TimeInterval = 30
    private static let installedFileName = "istiqamah-custom.caf"

    static func importSound(from sourceURL: URL) async throws -> ImportedNotificationSound {
        try await Task.detached(priority: .userInitiated) {
            try importSoundSynchronously(from: sourceURL)
        }.value
    }

    private static func importSoundSynchronously(
        from sourceURL: URL
    ) throws -> ImportedNotificationSound {
        let hasSecurityAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let input = try AVAudioFile(forReading: sourceURL)
        guard input.processingFormat.sampleRate > 0 else {
            throw SoundImportError.unreadable
        }
        let duration = Double(input.length) / input.processingFormat.sampleRate
        guard duration > 0 else { throw SoundImportError.unreadable }
        guard duration <= maximumDuration else {
            throw SoundImportError.tooLong(duration)
        }

        let fileManager = FileManager.default
        let library = try fileManager.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let soundsDirectory = library.appendingPathComponent("Sounds", isDirectory: true)
        try fileManager.createDirectory(
            at: soundsDirectory,
            withIntermediateDirectories: true
        )

        let temporaryURL = soundsDirectory.appendingPathComponent(
            "istiqamah-import-\(UUID().uuidString).caf"
        )
        do {
            try transcodeLinearPCM(input: input, destination: temporaryURL)
            let outputSize = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard outputSize > 0 else { throw SoundImportError.unreadable }
            let installedURL = soundsDirectory.appendingPathComponent(installedFileName)
            if fileManager.fileExists(atPath: installedURL.path) {
                _ = try fileManager.replaceItemAt(installedURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: installedURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = sourceName.isEmpty ? "Imported Sound" : sourceName
        return ImportedNotificationSound(
            fileName: installedFileName,
            displayName: String(displayName.prefix(50))
        )
    }

    private static func transcodeLinearPCM(
        input: AVAudioFile,
        destination: URL
    ) throws {
        let format = input.processingFormat
        let output = try AVAudioFile(
            forWriting: destination,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096) else {
            throw SoundImportError.unreadable
        }

        while input.framePosition < input.length {
            let remaining = input.length - input.framePosition
            let frameCount = AVAudioFrameCount(min(Int64(buffer.frameCapacity), remaining))
            try input.read(into: buffer, frameCount: frameCount)
            guard buffer.frameLength > 0 else { break }
            try output.write(from: buffer)
        }
    }
}

private enum SoundImportError: LocalizedError {
    case unreadable
    case tooLong(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "The selected file could not be decoded as audio."
        case let .tooLong(duration):
            "Choose a clip no longer than 30 seconds. This file is \(Int(duration.rounded())) seconds."
        }
    }
}
