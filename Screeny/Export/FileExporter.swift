import AppKit
import OSLog
import UniformTypeIdentifiers

@MainActor
enum FileExporter {
    /// Shows a save panel starting in the default folder with a name from the pattern.
    static func save(_ png: Data, preferences: Preferences, date: Date = .now) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.directoryURL = preferences.saveFolder
        panel.nameFieldStringValue = FileNamePattern.fileName(pattern: preferences.fileNamePattern, date: date)

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url, options: .atomic)
        } catch {
            Logger.export.error("Saving to \(url.path, privacy: .private) failed: \(error.localizedDescription, privacy: .public)")
            NSAlert(error: error).runModal()
        }
    }
}
