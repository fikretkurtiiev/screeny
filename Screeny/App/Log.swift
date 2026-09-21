import OSLog

extension Logger {
    private static let base = Bundle.main.bundleIdentifier ?? "dev.screeny.Screeny"

    static let app = Logger(subsystem: "\(base).app", category: "App")
    static let capture = Logger(subsystem: "\(base).capture", category: "Capture")
    static let overlay = Logger(subsystem: "\(base).overlay", category: "Overlay")
    static let export = Logger(subsystem: "\(base).export", category: "Export")
    static let settings = Logger(subsystem: "\(base).settings", category: "Settings")
}
