# Security Policy

The orchestrator runs locally and is intentionally powerful: it executes shell
helpers, writes hook configuration into `~/.claude/`, and (via the npm
`postinstall` and the `curl | bash` installer) runs install code on your
machine. We take reports about that surface seriously.

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.9.x   | ✅ (current) |
| < 0.9   | ❌ (please upgrade) |

Security fixes land on the latest released line. Check your version with
`orchestrator --version`.

## Reporting a vulnerability

**Please do not open a public issue for security problems.** Disclose privately
so a fix can ship before details are public:

- Preferred: GitHub **private vulnerability reporting** on this repository
  (the **Security** tab → **Report a vulnerability**).
<!-- maintainers: add a monitored security contact address here if preferred, e.g. security@your-domain -->

Please include: affected version (`orchestrator --version`), install channel
(npm / Homebrew / curl / source), your OS + runtime, a description of the
issue, and minimal reproduction steps or a proof of concept if you have one.

## What to expect

- Acknowledgement of your report on a best-effort basis (this is a small
  project; we aim for a few business days).
- An assessment and, for confirmed issues, a fix on the supported line plus a
  coordinated disclosure timeline.
- Credit in the release notes if you'd like it.

## Scope notes

In scope: the installers (`packaging/install/*`, npm `postinstall`), release
artifact integrity (signing / checksums), the dispatch + hook surfaces, and any
path where untrusted input could lead to unintended code execution or file
writes outside the project tree.

Out of scope: vulnerabilities in your own project's code, in Claude Code /
Codex / Cursor themselves, or in third-party tools the orchestrator integrates
with optionally (e.g. `gh`, `conversus`) — report those upstream.

Release artifacts are signed (Sigstore keyless) and shipped with a
`SHA256SUMS`; verification steps are in
[`references/installation.md`](references/installation.md#verifying-integrity).
