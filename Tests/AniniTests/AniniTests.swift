import XCTest
@testable import Anini

final class PathTests: XCTestCase {
    func testExpandTilde() {
        let home = NSHomeDirectory()
        XCTAssertEqual(Path.expand("~/foo"), home + "/foo")
        XCTAssertEqual(Path.expand("~"), home)
    }

    func testExpandAbsoluteUnchanged() {
        XCTAssertEqual(Path.expand("/abs"), "/abs")
        XCTAssertEqual(Path.expand("/usr/local/bin"), "/usr/local/bin")
    }

    func testShellQuotedPreservesEmbeddedSingleQuote() {
        // "it's" must become 'it'\''s' so the shell sees a single literal token.
        XCTAssertEqual(Path.shellQuoted("it's"), "'it'\\''s'")
    }

    func testShellQuotedPlain() {
        XCTAssertEqual(Path.shellQuoted("/tmp/foo bar"), "'/tmp/foo bar'")
    }

    func testSbplEscapesBackslashAndDoubleQuote() {
        XCTAssertEqual(Path.sbplEscaped(#"a\b"c"#), #"a\\b\"c"#)
    }

    func testSbplPlainUnchanged() {
        XCTAssertEqual(Path.sbplEscaped("/Users/test/foo"), "/Users/test/foo")
    }
}

final class WorkspaceConfigTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AniniTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testWorkspacePathSetterExpandsTildeBeforePersisting() {
        let stored = WorkspaceConfig.writeWorkspacePath("~/projects", to: defaults)
        let expected = NSHomeDirectory() + "/projects"
        XCTAssertEqual(stored, expected)
        XCTAssertEqual(defaults.string(forKey: WorkspaceConfig.workspacePathDefaultsKey), expected)
    }

    func testWorkspacePathSetterLeavesAbsoluteAlone() {
        let stored = WorkspaceConfig.writeWorkspacePath("/tmp/wp", to: defaults)
        XCTAssertEqual(stored, "/tmp/wp")
        XCTAssertEqual(defaults.string(forKey: WorkspaceConfig.workspacePathDefaultsKey), "/tmp/wp")
    }
}

final class PermissionPolicyTests: XCTestCase {
    func testCurrentReturnsDedupedTildeExpandedPaths() {
        let policy = PermissionPolicy.current()
        let home = NSHomeDirectory()

        // No path should still contain a literal "~".
        for path in policy.protectedPaths {
            XCTAssertFalse(path.hasPrefix("~"), "path \(path) was not tilde-expanded")
            // Tilde-only paths should expand to a home-prefixed absolute path.
            if path.contains(home) || path.hasPrefix("/") {
                continue
            }
            XCTFail("unexpected non-absolute path: \(path)")
        }

        // Dedup check: protectedPaths must be unique.
        XCTAssertEqual(Set(policy.protectedPaths).count, policy.protectedPaths.count)
    }
}
