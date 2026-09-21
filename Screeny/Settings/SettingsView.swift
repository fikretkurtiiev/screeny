import AppKit
import KeyboardShortcuts
import OSLog
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Capture region:", name: .captureRegion)
            }
            Section {
                LabeledContent("Save folder:") {
                    HStack {
                        Text((preferences.saveFolder.path as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…", action: chooseFolder)
                    }
                }
                TextField("File name:", text: $preferences.fileNamePattern)
                Text("Preview: \(FileNamePattern.fileName(pattern: preferences.fileNamePattern, date: .now))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Text in {braces} is a date format, for example {yyyy-MM-dd} or {HH.mm.ss}.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = preferences.saveFolder
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            preferences.saveFolder = url
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Logger.settings.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            launchAtLogin = service.status == .enabled
        }
    }
}
