import Foundation
import SwiftUI

enum RiskLevel {
    case critical, high, medium

    var label: String {
        switch self {
        case .critical: return "Critical"
        case .high:     return "High"
        case .medium:   return "Medium"
        }
    }

    var color: Color {
        switch self {
        case .critical: return .red
        case .high:     return .orange
        case .medium:   return Color(red: 0.85, green: 0.65, blue: 0.1)
        }
    }
}

struct SensitivePath: Identifiable {
    let id: String          // same as path, used as the key for unprotectedPaths
    let path: String
    let label: String       // human-readable short name
    let reason: String      // one-line summary
    let whatIsHere: String  // plain-language explanation of what lives at this path
    let ifExposed: String   // what could go wrong
    let riskLevel: RiskLevel
}

class SecurityLayer {
    static let shared = SecurityLayer()

    let sensitivePaths: [SensitivePath] = [
        SensitivePath(
            id: "~/.ssh",
            path: "~/.ssh",
            label: "SSH Private Keys",
            reason: "Server & Git authentication credentials",
            whatIsHere: "Your SSH key files — id_rsa, id_ed25519, and similar. These are cryptographic credentials that prove your identity to remote servers without a password. GitHub, GitLab, cloud servers, and internal infrastructure all commonly use SSH keys.",
            ifExposed: "Anyone who reads these files can impersonate you on every server where your public key is registered. That means pushing code to your repos as you, logging into production servers, or accessing any cloud VM tied to your key — all without your knowledge.",
            riskLevel: .critical
        ),
        SensitivePath(
            id: "~/.gnupg",
            path: "~/.gnupg",
            label: "GPG Keys",
            reason: "Signing, encryption & digital identity",
            whatIsHere: "Your GPG (GNU Privacy Guard) private keys. Used to digitally sign Git commits (proving they came from you), encrypt files and emails, and verify your identity in developer toolchains.",
            ifExposed: "An attacker can sign commits as you — making malicious code appear to come from your verified identity. They can also decrypt any messages or files encrypted for you, and impersonate you in any system that trusts your GPG signature.",
            riskLevel: .critical
        ),
        SensitivePath(
            id: "~/.aws",
            path: "~/.aws",
            label: "AWS Credentials",
            reason: "Amazon cloud account access",
            whatIsHere: "Your AWS access key ID and secret, stored in ~/.aws/credentials. Used by the AWS CLI, Terraform, SDKs, and most cloud tooling to authenticate API requests on your behalf.",
            ifExposed: "Depending on your IAM permissions, an attacker can spin up EC2 instances (and run up your bill), read or delete S3 buckets, access databases, exfiltrate data, or pivot to other services. AWS credential leaks are one of the most common causes of cloud account compromise.",
            riskLevel: .critical
        ),
        SensitivePath(
            id: "~/.config/gcloud",
            path: "~/.config/gcloud",
            label: "Google Cloud Credentials",
            reason: "GCP authentication tokens",
            whatIsHere: "Access tokens and OAuth credentials stored after running `gcloud auth login`. Used by the gcloud CLI and Google Cloud SDKs to authenticate requests to GCP services.",
            ifExposed: "Access to Google Cloud Platform services within your project permissions — Cloud Storage, BigQuery, Compute Engine, Cloud SQL, and more. Tokens here are short-lived but refresh automatically, so exposure is effectively persistent.",
            riskLevel: .high
        ),
        SensitivePath(
            id: "~/.config/gh",
            path: "~/.config/gh",
            label: "GitHub CLI Token",
            reason: "GitHub account access via gh CLI",
            whatIsHere: "The OAuth token used by the `gh` command-line tool. Grants API access to GitHub on your behalf — including private repositories, organization membership, and account settings.",
            ifExposed: "Can read your private repos, create or delete repositories, manage issues and pull requests, modify CI/CD settings, and access anything the GitHub API exposes under your account. GitHub tokens with broad scope are high-value targets.",
            riskLevel: .high
        ),
        SensitivePath(
            id: "~/Library/Keychains",
            path: "~/Library/Keychains",
            label: "macOS Keychain",
            reason: "All saved passwords & certificates on this Mac",
            whatIsHere: "The macOS Keychain databases — encrypted stores for website passwords, WiFi passwords, app credentials, SSL certificates, and private keys used by your system and applications.",
            ifExposed: "The files are encrypted, so raw access doesn't immediately reveal passwords. However, an attacker with shell access can use the `security` command to query the Keychain while you're logged in, potentially dumping credentials without your master password.",
            riskLevel: .critical
        ),
        SensitivePath(
            id: "chrome_login_data",
            path: "~/Library/Application Support/Google/Chrome/Default/Login Data",
            label: "Chrome Saved Passwords",
            reason: "All passwords saved in Chrome",
            whatIsHere: "A SQLite database containing every username and password you've saved in Chrome, encrypted using your macOS login credentials via the Chrome Safe Storage Keychain entry.",
            ifExposed: "With shell access, the database can be copied and decrypted using your macOS password (which the AI already has access to execute commands as you). This is a standard technique in credential-theft malware. Every site you've saved a password for is at risk.",
            riskLevel: .critical
        ),
        SensitivePath(
            id: "firefox_profiles",
            path: "~/Library/Application Support/Firefox/Profiles",
            label: "Firefox Saved Passwords",
            reason: "Passwords, cookies & session data",
            whatIsHere: "Your Firefox profile directory. Contains key4.db and logins.json (saved passwords), cookies.sqlite (all active browser sessions), and browsing history.",
            ifExposed: "Saved passwords can be extracted — more easily if you haven't set a Firefox master password. Cookies expose active login sessions for sites you're currently logged into, which can be used to hijack those sessions without needing your password at all.",
            riskLevel: .high
        ),
        SensitivePath(
            id: "~/.netrc",
            path: "~/.netrc",
            label: ".netrc Credentials",
            reason: "Plaintext network usernames & passwords",
            whatIsHere: "A plaintext configuration file used by curl, ftp, wget, and some package managers to store usernames and passwords for network services (FTP servers, private registries, APIs, etc.).",
            ifExposed: "Unlike most credential stores, .netrc is not encrypted. Credentials here are readable as plain text with no decryption step. Any system user — or process running as you — can read it directly.",
            riskLevel: .critical
        ),
        SensitivePath(
            id: "~/.npmrc",
            path: "~/.npmrc",
            label: "npm Auth Tokens",
            reason: "Private package registry access",
            whatIsHere: "Your npm configuration file, which often contains authentication tokens for private npm registries — npm Enterprise, GitHub Packages, Artifactory, or custom registries used by your team.",
            ifExposed: "Can publish malicious packages to registries you have write access to. Supply chain attacks (injecting bad code into packages your team depends on) often start with a stolen npm token. Read access also exposes private packages and their source code.",
            riskLevel: .high
        ),
    ]

    private let auditLogURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".anini")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("audit.log")
    }()

    func log(_ event: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(event)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: auditLogURL.path),
           let handle = try? FileHandle(forWritingTo: auditLogURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: auditLogURL)
        }
    }
}
