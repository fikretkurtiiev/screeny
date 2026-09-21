import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // ⇧⌘S is "Save As…/Duplicate" in many apps; registering it globally takes it over, which is why Settings can rebind or clear it.
    static let captureRegion = Self("captureRegion", default: .init(.s, modifiers: [.command, .shift]))
}
