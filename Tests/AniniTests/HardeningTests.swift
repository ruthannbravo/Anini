import XCTest
@testable import Anini

/// Tests for the security-hardening changes: default-deny sandbox profile and
/// trusted-executable resolution.
final class HardeningTests: XCTestCase {

    // MARK: - ExecutableTrust (C2)

    func testTrustedExecutableRejectsMissing() {
        XCTAssertFalse(ExecutableTrust.isTrustedExecutable("/nonexistent/binary/xyz"))
    }

    func testTrustedExecutableAcceptsSystemBinary() {
        // /bin/ls is a regular file, root-owned, and not group/other-writable.
        XCTAssertTrue(ExecutableTrust.isTrustedExecutable("/bin/ls"))
    }

    func testTrustedExecutableRejectsNonExecutableRegularFile() {
        let tmp = NSTemporaryDirectory() + "anini-trust-\(UUID().uuidString).txt"
        FileManager.default.createFile(atPath: tmp, contents: Data("x".utf8),
                                       attributes: [.posixPermissions: 0o644])
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        XCTAssertFalse(ExecutableTrust.isTrustedExecutable(tmp))
    }

    func testTrustedExecutableRejectsGroupOrWorldWritable() {
        let tmp = NSTemporaryDirectory() + "anini-trust-\(UUID().uuidString).sh"
        FileManager.default.createFile(atPath: tmp, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o777])
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        // Owned by the current user and executable, but world-writable → rejected.
        XCTAssertFalse(ExecutableTrust.isTrustedExecutable(tmp))
    }

    func testTrustedExecutableAcceptsSymlinkToTrustedTarget() {
        // The official `claude` installer ships ~/.local/bin/claude as a symlink
        // into ~/.local/share/claude/versions/<v>. A symlink whose real target
        // is a user-owned, non-group/other-writable regular file is trusted —
        // we vet the resolved target, not the link.
        let target = NSTemporaryDirectory() + "anini-trust-target-\(UUID().uuidString)"
        let link = NSTemporaryDirectory() + "anini-trust-link-\(UUID().uuidString)"
        FileManager.default.createFile(atPath: target, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o755])
        try? FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
        defer {
            try? FileManager.default.removeItem(atPath: link)
            try? FileManager.default.removeItem(atPath: target)
        }
        XCTAssertTrue(ExecutableTrust.isTrustedExecutable(link))
    }

    func testTrustedExecutableRejectsSymlinkToWritableTarget() {
        // Following the symlink must not launder an untrusted target: a link to
        // a world-writable file is still rejected because the resolved target
        // fails the permission check.
        let target = NSTemporaryDirectory() + "anini-trust-target-\(UUID().uuidString).sh"
        let link = NSTemporaryDirectory() + "anini-trust-link-\(UUID().uuidString)"
        FileManager.default.createFile(atPath: target, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o777])
        try? FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
        defer {
            try? FileManager.default.removeItem(atPath: link)
            try? FileManager.default.removeItem(atPath: target)
        }
        XCTAssertFalse(ExecutableTrust.isTrustedExecutable(link))
    }

    func testTrustedExecutableRejectsBrokenSymlink() {
        let link = NSTemporaryDirectory() + "anini-trust-link-\(UUID().uuidString)"
        try? FileManager.default.createSymbolicLink(
            atPath: link, withDestinationPath: NSTemporaryDirectory() + "anini-missing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(atPath: link) }
        XCTAssertFalse(ExecutableTrust.isTrustedExecutable(link))
    }

    // MARK: - Sandbox profile (C1 / H1 / H2)

    func testSandboxProfileAlwaysEmitted() {
        // Containment must never depend on the bypassable string-match deny
        // rules, so a profile is always produced.
        let policy = PermissionPolicy(allowFullAuto: false, protectedPaths: [],
                                      workspace: "/Users/test/work")
        XCTAssertNotNil(policy.sandboxProfile())
    }

    func testSandboxProfileDeniesHomeAndReallowsWorkspace() {
        let home = Path.expand("~")
        let policy = PermissionPolicy(allowFullAuto: false, protectedPaths: [],
                                      workspace: "/Users/test/work")
        let profile = policy.sandboxProfile() ?? ""
        XCTAssertTrue(profile.contains("(deny file-read* file-write* (subpath \"\(home)\"))"),
                      "the home credential surface must be denied by default")
        XCTAssertTrue(profile.contains("(allow file-read* file-write* (subpath \"/Users/test/work\"))"),
                      "the workspace must be re-allowed")
    }

    func testSandboxProfileDeniesProtectedPaths() {
        let policy = PermissionPolicy(allowFullAuto: false,
                                      protectedPaths: ["/secret/path"],
                                      workspace: "/Users/test/work")
        let profile = policy.sandboxProfile() ?? ""
        XCTAssertTrue(profile.contains("/secret/path"))
        XCTAssertTrue(profile.contains("deny"))
    }

    func testSandboxProfileWhenWorkspaceIsHomeStillDeniesCredentialDirs() {
        // When the workspace is the home dir itself, we cannot blanket-deny
        // home; we must still deny the known credential subtrees.
        let home = Path.expand("~")
        let policy = PermissionPolicy(allowFullAuto: false, protectedPaths: [],
                                      workspace: home)
        let profile = policy.sandboxProfile() ?? ""
        XCTAssertFalse(profile.contains("(deny file-read* file-write* (subpath \"\(home)\"))"),
                       "must not blanket-deny home when home is the workspace")
        XCTAssertTrue(profile.contains("deny"),
                      "credential subtrees must still be denied")
    }
}
