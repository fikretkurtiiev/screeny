import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let saveFolder = "saveFolder"
        static let fileNamePattern = "fileNamePattern"
    }

    private let defaults: UserDefaults

    var saveFolder: URL {
        didSet { defaults.set(saveFolder.path, forKey: Key.saveFolder) }
    }

    var fileNamePattern: String {
        didSet { defaults.set(fileNamePattern, forKey: Key.fileNamePattern) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        saveFolder = defaults.string(forKey: Key.saveFolder).map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Self.defaultSaveFolder
        fileNamePattern = defaults.string(forKey: Key.fileNamePattern) ?? FileNamePattern.defaultPattern
    }

    static var defaultSaveFolder: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}
