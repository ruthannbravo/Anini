# Anini Security & Correctness Audit

Read-only audit of the Anini macOS app (owner-authorized, defensive). Scope: all
Swift sources in `Sources/Anini/`, `Resources/Anini.entitlements`,
`Resources/Info.plist`, `project.yml`, and `scripts/`.

Findings are ordered strictly by severity. File:line references are to the
sources as read during the audit.

---

## Summary by severity

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High     | 4 |
| Medium   | 6 |
| Low      | 4 |

---

## Critical

### C1. Seatbelt sandbox profile uses `(allow default)` — protection is opt-out, not opt-in
**File:** `Sources/Anini/PermissionPolicy.swift:143-151` (`sandboxProfile()`)

The generated SBPL profile is:

```
(version 1)
(allow default)
(deny file-read* file-write* (subpath "<protected path>"))
```

`(allow default)` permits *everything* and then denies a short blocklist of
sensitive subpaths. This is the inverse of a security sandbox. The "kernel
guarantee" that both backends advertise (ClaudeCodeBackend.swift:178-186,
CodexBackend.swift:96-106) only blocks the ~9 hardcoded paths in
`SecurityLayer.sensitivePaths`. The subprocess (and anything it shells out to)
can still freely read/write the entire rest of the disk, send Apple Events,
open network sockets, exec arbitrary binaries, and — critically — touch any
sensitive credential store *not* on the hardcoded list (e.g. `~/.kube/config`,
`~/.docker/config.json`, `~/.config/op`, `~/Library/Messages/chat.db`, browser
cookie stores for Safari/Edge/Brave/Arc, `~/.azure`, `~/.terraform.d`,
1Password/`~/.config/`, any future tool). The sandbox provides essentially no
containment beyond the explicit denylist.

Additionally `subpath` does not protect the directory node itself in all cases
and `deny file-read*` does not stop a process from re-deriving a path via a
hardlink created elsewhere; with `(allow default)` the model can also just
`cp`/`cat` through a symlink it creates outside the denied subpath.

**Impact:** The headline security control (kernel-enforced path protection) is
effectively a thin denylist. Any credential or sensitive file the author did
not anticipate is fully exposed to LLM-driven shell commands.

**Fix:** Invert to default-deny for the credential surface. Either (a) base the
profile on `(deny default)` and explicitly allow only the workspace dir, system
read paths, and required tooling; or (b) at minimum expand the denylist to a
much broader set and deny `file-read*`/`file-write*` on the whole home dir
except the configured workspace. Document that the denylist is exhaustive-by-
necessity if `(allow default)` is kept, and stop describing it as a hard kernel
guarantee.

---

### C2. Executable resolution falls back to `which`, honoring an attacker-influenced `PATH`
**File:** `Sources/Anini/ClaudeCodeBackend.swift:35-58`, `Sources/Anini/CodexBackend.swift:35-57`

`resolveExecutable()` checks a fixed candidate list, then falls back to
`/usr/bin/which claude` (resp. `codex`) using the *inherited* environment
`PATH`. Whatever that resolves to is then executed with the user's full
privileges — and, when full-auto is on, with `--dangerously-skip-permissions` /
`--dangerously-bypass-approvals-and-sandbox`, with the Anthropic/OpenAI API key
injected into its environment (ClaudeCodeBackend.swift:196-198,
CodexBackend.swift:110-112).

If any earlier-in-`PATH` directory is writable by a less-trusted process (a
poisoned `~/.npm-global/bin`, a dev tool that prepends a project-local `bin`, a
compromised Homebrew prefix), a malicious `claude`/`codex` binary is launched
with the API key in its env and no sandbox. The candidate list itself includes
`~/node_modules/.bin/claude` and `~/.npm-global/bin` — directories routinely
written by `npm install` of untrusted packages.

**Impact:** Code-execution / API-key-exfiltration via a planted binary on
`PATH`. The injected `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` and Google tokens (if
reachable) are handed to whatever resolves.

**Fix:** Drop the `which` fallback or restrict resolution to a set of trusted,
non-user-writable absolute paths; verify the resolved binary's code signature /
ownership (root or the user, not group/other writable) before exec. Do not
include `~/node_modules/.bin` in the trusted candidate list.

---

## High

### H1. Claude Bash deny rules are trivially bypassable and are the only barrier in Safe-ish configs
**File:** `Sources/Anini/PermissionPolicy.swift:71-91` (`claudeDenyRules`)

The Bash deny rule is a substring match: `Bash(*<path>*)`. As the code comment
itself admits, "rename/symlink/encode still evade." When `protectedPaths` is
empty (every sensitive path opted out, which the UI permits), **no sandbox is
written at all** (sandboxProfile/writeSandboxProfile return nil at
PermissionPolicy.swift:144 and ClaudeCodeBackend.swift:182), so the substring
deny rules are the *only* protection — and they don't protect anything against
an adversarial or jailbroken model (`cat $(echo L3Vz...| base64 -d)`, reading
via a symlink, `python -c`, etc.). Untrusted LLM output drives the shell here;
treating string-match deny rules as a boundary is a trust-boundary violation.

**Impact:** In any config where the kernel sandbox is off, protected-path
"protection" for Bash is cosmetic.

**Fix:** Always emit a default-deny kernel sandbox (see C1) regardless of the
denylist, so containment never depends on string matching. Keep the deny rules
only as defense-in-depth, not as a standalone control.

### H2. Codex Safe mode (`workspace-write`) still allows reading every credential on disk
**File:** `Sources/Anini/CodexBackend.swift:84-88`

In non-full-auto mode Codex is run with `--sandbox workspace-write`. Per the
inline comment, this "allows reads everywhere but restricts writes." So in Safe
mode Codex can still `cat ~/.aws/credentials`, `cat ~/.ssh/id_ed25519`, read
browser password DBs, etc., and exfiltrate them over any allowed channel — only
*writes* are confined to the cwd. The kernel sandbox-exec wrapper (C1) is the
only thing that would block reads, and it only blocks the hardcoded denylist
with `(allow default)`.

**Impact:** "Safe mode" with Codex does not prevent credential reads/exfil.

**Fix:** Pair `workspace-write` with the default-deny kernel sandbox from C1, or
use a read-restricted Codex sandbox mode. At minimum, document clearly that Safe
mode confines writes only.

### H3. API key and OAuth tokens are placed in subprocess environment with `(allow default)` sandbox and no-network-deny
**File:** `Sources/Anini/ClaudeCodeBackend.swift:196-199`, `Sources/Anini/CodexBackend.swift:108-113`

`ANTHROPIC_API_KEY` / `OPENAI_API_KEY` are injected into the child process
environment. Because the sandbox is `(allow default)` (C1), the child — and any
process it spawns under the same env, since env is inherited — can read these
from `/proc`-equivalent introspection, re-emit them, or POST them anywhere
(network is allowed). Combined with C2 (untrusted binary) or a jailbroken model,
the key is directly exfiltratable. The key is correctly stored in Keychain
(good), but the moment it enters an unsandboxed child env that benefit is lost.

**Impact:** Provider API keys (and, if the child reads them, no Google tokens
are passed here — those stay in Keychain, which is good) are exposed to the
full LLM-driven execution surface.

**Fix:** Prefer the CLI's own credential mechanism over env injection where
possible; restrict the child's network egress in the sandbox profile to only the
provider API host; and ensure the env var is not inherited by grandchild shell
commands the model runs (e.g. unset it in a wrapper before the model's Bash
tool runs, if the CLI supports reading it once at startup).

### H4. `accentColorRGB` read from UserDefaults without length check — out-of-bounds crash on tampered/legacy defaults
**File:** `Sources/Anini/WorkspaceConfig.swift:264-267` (and consumers at 126, SettingsView.swift:231-232)

```swift
let rgb = UserDefaults.standard.array(forKey: "ui_accent_color") as? [Double]
    ?? [0.72, 0.57, 0.93]
accentColorRGB = rgb
accentColor = Color(red: rgb[0], green: rgb[1], blue: rgb[2])
```

If `ui_accent_color` exists but holds fewer than 3 doubles (corrupted defaults,
a downgraded build, or manual `defaults write`), `rgb[0..2]` traps and the app
crashes on launch — before any UI is shown, so the user cannot recover from
within the app. The `didSet` at line 123-128 has the same issue, as does the
SettingsView preset comparison/use.

**Impact:** Hard crash loop on startup from malformed persisted state.

**Fix:** Validate `rgb.count == 3` (and value ranges) before assigning; fall back
to the default otherwise. Make `accentColor` derivation total/safe.

---

## Medium

### M1. UTF-8 stream chunks decoded per-read; multibyte characters split across pipe reads are dropped
**File:** `Sources/Anini/ClaudeCodeBackend.swift:206-211`, `Sources/Anini/CodexBackend.swift:121-124`

`String(data: handle.availableData, encoding: .utf8)` is called on each raw pipe
chunk. A multibyte UTF-8 sequence (emoji, accented French/Italian characters —
which this app surfaces heavily) can land on a chunk boundary, making the decode
return `nil`; the `guard ... else { return }` then **discards the entire chunk**,
including the bytes already received. For Claude this can drop a whole JSON line
(losing assistant text or the session_id); for Codex it silently loses output.

**Fix:** Accumulate raw `Data` and decode incrementally at safe boundaries, or
buffer undecodable trailing bytes and prepend them to the next chunk.

### M2. `stderr` pipe never drained until termination — deadlock risk on verbose stderr
**File:** `Sources/Anini/ClaudeCodeBackend.swift:233`, `Sources/Anini/CodexBackend.swift:139`

`stderrPipe` has no `readabilityHandler`; it's only read with
`readDataToEndOfFile()` inside the termination handler, and only on the error
path. If a child writes more than the OS pipe buffer (~64KB) to stderr while
running, it blocks on write, never exits, and the termination handler never
fires — the `withCheckedThrowingContinuation` then never resumes, hanging the
`send()` task indefinitely (and leaking the process). Long verbose runs make
this reachable.

**Fix:** Attach a readability handler to stderr that drains into a buffer, or
redirect stderr to the same pipe as stdout.

### M3. `interrupt()` sends SIGINT to `sandbox-exec`, may orphan the real child / leave temp files
**File:** `Sources/Anini/ClaudeCodeBackend.swift:68-70,243-244`, `Sources/Anini/CodexBackend.swift:149-150,164`

When sandboxed, `process` is `/usr/bin/sandbox-exec` and the actual
`claude`/`codex` is its child. `interrupt()` / `prior?.interrupt()` SIGINTs only
`sandbox-exec`. Depending on signal forwarding, the grandchild CLI (and any Bash
subprocesses *it* spawned) can be orphaned and keep running with the API key and
sandbox still active. If the parent dies without the termination handler firing,
the temp `.sb`/`.json` files persist (cleanupOrphans mitigates only after 1h).

**Fix:** Run the child in its own process group and signal the group, or use
`interrupt()` plus a short-timeout `terminate()`/kill of the process group.

### M4. App is not App-Sandboxed; entitlements + Info.plist grant broad automation with no containment
**File:** `Sources/Anini/Resources/Anini.entitlements`, `Sources/Anini/Resources/Info.plist:27-36`, `project.yml:30-33`

The entitlements file contains only `personal-information.calendars`; there is
no `com.apple.security.app-sandbox`. Combined with `NSAppleEventsUsageDescription`,
`NSAppleScriptEnabled`, and `NSSystemAdministrationUsageDescription`, the app
runs fully outside the App Sandbox with broad Apple Event / admin intent. For a
full-Mac-control assistant this is partly by design, but it means there is *no*
OS-level backstop around the app itself — the only containment for LLM actions
is the per-subprocess sandbox-exec wrapper, which C1/H1/H2 show is weak. This
should be a conscious, documented decision; `NSSystemAdministrationUsageDescription`
in particular invites privileged operations.

**Fix:** Document the no-sandbox decision explicitly; drop entitlements/usage
strings that aren't actually used (e.g. remove the System Administration string
if no privileged helper exists) to reduce the granted surface.

### M5. Audit log written world-readable in plaintext; records session IDs and command metadata
**File:** `Sources/Anini/SecurityLayer.swift:130-149`

`~/.anini/audit.log` is created with default permissions (typically 0644) and
the directory at default perms. It records session IDs and exit codes
(ClaudeCodeBackend.swift:228). Session IDs can be used with `claude --resume` to
continue/inspect a conversation. Any local user/process can read the log. The
log is also opened/closed (`FileHandle`) on every event with no failure
handling — minor, but the readability/permissions is the real issue.

**Fix:** Create the file/dir with 0600/0700 (`FileManager` attributes or
`fchmod`). Consider not logging session IDs, or treat them as sensitive.

### M6. Screenshot PNGs written to shared temp dir, predictable names, never deleted
**File:** `Sources/Anini/ChatViewModel.swift:158-165`

Screenshots are written to `NSTemporaryDirectory() + "anini_screen_<unix
seconds>.png"`. The path is predictable (1-second resolution), the temp dir is
readable by the user's other processes, and the files are never cleaned up — a
growing pile of full-screen captures (which may contain passwords, private
messages, etc.) accumulates in temp. The screenshot path is then handed to the
LLM to Read (ClaudeCodeBackend.swift:140-144), expanding exposure.

**Fix:** Write to a 0700 app-private subdir with an unpredictable name; delete
the file after the turn completes; sweep old screenshots on launch alongside
`cleanupOrphans`.

---

## Low

### L1. `result.text.isEmpty` / `!text.isEmpty` success heuristic masks real failures
**File:** `Sources/Anini/ClaudeCodeBackend.swift:230`, `Sources/Anini/CodexBackend.swift:136`

A non-zero exit is treated as success whenever *any* text was captured
(`proc.terminationStatus == 0 || !result.text.isEmpty`). A run that partially
streamed text and then crashed/errored is reported to the user as a normal
completed answer, hiding the failure (and any partial/incorrect state).

**Fix:** Surface non-zero exit as an error (or at least an appended warning) even
when partial text exists.

### L2. Screenshot capture mutates `@Published` state off the MainActor
**File:** `Sources/Anini/ChatViewModel.swift:135-165`

`captureScreen()` launches a detached `Task` (not `@MainActor`-isolated) that
sets `screenCaptureError`, `needsScreenPermission`, and `pendingScreenshot`
(via `saveAndSet`) directly. `ChatViewModel` is `@MainActor`, but the closure
body runs in the `Task`'s context; these `@Published` mutations should be hopped
to the main actor to avoid publishing changes off-main (purple-runtime warnings
/ UI races).

**Fix:** Annotate the `Task` as `@MainActor` or wrap state mutations in
`await MainActor.run { ... }`.

### L3. OAuth token exchange swallows all errors into one generic message
**File:** `Sources/Anini/GoogleCalendarManager.swift:160-165`

`try?` collapses network failures, non-200 responses, and JSON-shape mismatches
into a single "Token exchange failed." with no logging, making connection
problems undiagnosable. The HTTP status is discarded (`_`).

**Fix:** Inspect the status code and include a distinguishable message; log the
underlying error locally.

### L4. `caffeinate` / drop-handler process error paths are silent (`try?`)
**File:** `Sources/Anini/ChatViewModel.swift:34`, `Sources/Anini/ContentView.swift:112`

`try? p.run()` for `caffeinate` and the relaunch shell (`/bin/sh -c "... open
'<path>'"`) silently ignore launch failures. The relaunch command interpolates
`Bundle.main.bundleURL.path` into a single-quoted shell string without escaping
embedded single quotes — safe for normal app paths, but brittle if the bundle
ever lives under a path containing a quote. Low likelihood, noted for
completeness.

**Fix:** Handle/log run failures; shell-quote the path via `Path.shellQuoted`.

---

## Notes / positive observations

- API keys and Google tokens are stored in Keychain, not UserDefaults — correct.
- PKCE is implemented correctly for the Google OAuth flow
  (GoogleCalendarManager.swift:119-134), with `prefersEphemeralWebBrowserSession`.
- `dangerouslySkipPermissions` is correctly *not* inferred from "all
  capabilities enabled" (ClaudeCodeBackend.swift:149-166) — a deliberate,
  good safety choice.
- Process ownership is guarded by a lock with swap/clear/snapshot helpers,
  avoiding the obvious interrupt-vs-launch race.
- Deny rules are passed via `--settings` file rather than argv, keeping
  protected paths out of `ps` output (PermissionPolicy.swift:93-109) — good.

The two Critical items (C1 default-allow sandbox, C2 PATH-based binary
resolution) are the ones that most undermine the app's stated security model and
should be addressed first.
