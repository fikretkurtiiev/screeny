import Foundation
@testable import Screeny
import Testing

struct FileNamePatternTests {
    private let utc = TimeZone(identifier: "UTC")!
    /// 2026-09-21 14:05:09 UTC
    private let date = Date(timeIntervalSince1970: 1_789_999_509)

    @Test func formatsDefaultPattern() {
        #expect(FileNamePattern.fileName(pattern: FileNamePattern.defaultPattern, date: date, timeZone: utc) == "Screeny 2026-09-21 at 14.05.09.png")
    }

    @Test func replacesPathUnsafeCharacters() {
        #expect(FileNamePattern.fileName(pattern: "a/b {HH:mm}", date: date, timeZone: utc) == "a-b 14-05.png")
    }

    @Test func leavesUnclosedBraceLiteral() {
        #expect(FileNamePattern.fileName(pattern: "shot {yyyy", date: date, timeZone: utc) == "shot {yyyy.png")
    }

    @Test func fallsBackWhenEmpty() {
        #expect(FileNamePattern.fileName(pattern: "  ", date: date, timeZone: utc) == "Screenshot.png")
    }

    @Test func doesNotDoubleTheExtension() {
        #expect(FileNamePattern.fileName(pattern: "shot.PNG", date: date, timeZone: utc) == "shot.PNG")
    }
}
