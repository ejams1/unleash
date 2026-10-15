# Changelog

## [Unreleased]

### Fixed
- Diagnostics no longer land in captured values: every helper that logs while
  its stdout is read by a caller (`data_mount=$(resolve_data_volume)`) returned
  the log lines instead of the value, which broke bypass, suppress, heal,
  persist, firewall, whitelist, status, backup and restore in Recovery.
- `audit` no longer aborts with `cfg: unbound variable`, and `audit --json`
  reaches the JSON code path again.
- `unleash-standalone.sh` (Homebrew, curl install, release asset) now carries
  every module: it was missing init, suggest, remediate, predict, telemetry
  and discord, all of which exited with `command not found`.
- `doctor` exists: it was documented in the help and the docs but had no
  dispatch branch.
- `--log-file` / `--webhook` without a value no longer drop the whole argument
  list and fall through to the interactive menu.
- `--dry-run` / `unleash test` really does simulate: the previous build wrote
  pf anchors, LaunchDaemons and hosts entries while claiming not to.
- `vpn-kill --interface utunX` no longer reads the flag as the interface name,
  and its pf anchor blocks before the VPN pass rule, which made the
  "VPN only" claim false.
- `config set KEY value` accepts a value containing `/` (a webhook URL used to
  kill the script through the sed replacement).
- Serial-prefix lookup no longer prints a here-document warning on every run.
- Migration Assistant / Configurator detection reads the right directory name.
- Cluster of smaller fixes: `profiles -C -output stdout-xml` instead of
  `-output xml` (which writes files into the CWD), "0\n0" counts that broke
  `[ -gt ]` tests and produced invalid JSON in `report --json`, the relative
  `.unleash-backup` path used by `history`/`uninstall`, telemetry accepting
  `on`/`off` as documented, the pf anchors writing the boot-time path instead
  of the Recovery mount path, and `dscl` accounts gaining GeneratedUID plus a
  home directory owned by the new user.

### Added
- `tests/smoke.sh`: portable end-to-end checks (no bats, no macOS) covering
  command dispatch, the standalone artifact, captured-value hygiene, dry run,
  argument parsing and JSON output, wired into both CI configs.
- Portability guard rail: the scripts may not use `dirname`, `basename`,
  `readlink` or `realpath`, and `make compat` / CI enforce it. Every use is
  replaced with parameter expansion, so the tool now runs in a minimal
  Recovery environment where those binaries are absent.

## [2.0.0] — 2026-06-20

### Added
- **init** wizard: interactive setup with MA scan, firewall, monitor, persist prompts
- **suggest** command: risk-based recommendations (analyzes system, suggests commands)
- **remediate** command: per-org MDM cleanup (JAMF, Mosyle, Addigy, Kandji, VMware)
- **predict** command: serial number lookup (predicts org enrollment from prefix)
- **telemetry** command: opt-in anonymous usage stats
- **discord-bot** command: Discord DM alerts when MDM is detected
- Jekyll docs config (_config.yml, Gemfile)
- Nix package (default.nix)
- Dockerfile for testing
- GPG signature verification in self-update
- GPG signing script for releases
- Per-command `--help` / `-h` flag
- CircleCI config as free CI alternative
- CI.md with local CI docs

### Changed
- GPG verification added to self-update flow
- Version bumped to 2.0.0

## [1.6.1] — 2026-06-20

### Added
- Per-command `--help` / `-h` flag (`unleash bypass --help`, etc.)
- CI rewritten to use zero-cost actions only (no Docker-based actions)
- LICENSE added to standalone binary header

### Fixed
- demo.svg typo (`xml:place` → `xml:space`) fixed
- wiki/Home.md removed from main repo (belongs in wiki)
- Per-command help integrated into dispatch

## [1.6.0] — 2026-06-20

### Added
- **Homebrew tap**: `brew install mateussiqueira/unleash/unleash`
- **GitHub Pages**: full command reference at https://mateussiqueira.github.io/unleash/
- **README.pt-BR.md**: Brazilian Portuguese translation
- **Bats tests**: doctor, whitelist, config, check, history, uninstall modules
- **docs/index.md**: landing page for GitHub Pages

### Changed
- Version bumped to 1.6.0
- Homebrew formula in separate tap repository

## [1.5.0] — 2026-06-20

### Added
- **report**: Human-readable or JSON-format system audit report
- **demo**: Simulated MDM bypass flow (no real changes)
- **vpn-kill**: pf kill-switch that blocks MDM outside VPN tunnel
- Third-party firewall detection (Little Snitch, LuLu, Radio Silence)

### Fixed
- Migration Assistant artifact cleanup now covers all users

## [1.4.0] — 2026-06-20

### Added
- **doctor**: Pre-flight diagnostics (root, Recovery, libs, disk, dependencies)
- **update**: Self-update from GitHub releases
- **uninstall**: Complete removal with 4 safety prompts
- **reinstall**: Atomic update (uninstall + install)

## [1.3.0] — 2026-06-20

### Added
- **config**: Persistent settings in ~/.unleash.conf
- **test** command / `--dry-run` global flag
- **history / history-clear**: Event log viewer
- Structured logging (levels, timestamps, color, file output)
- CLI aliases for every command

### Changed
- README rewritten (140 → 489 lines) — comprehensive command reference

## [1.2.0] — 2026-06-20

### Added
- **check**: Pre-format / pre-upgrade assessment (will this Mac lock after wipe?)
- **monitor**: Background daemon that watches MDM every 5 minutes and auto-heals
- **monitor-stop**: Stop the background monitor
- **monitor-status**: Check if monitor is running
- GitHub repo About section updated with description and topics

## [1.1.0] — 2026-06-20

### Added
- Project files: CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md
- GitHub issue templates (bug, feature, compatibility)
- GitHub Actions CI (ShellCheck, syntax check, markdown lint)
- Badges and professional README layout

### Changed
- Humanized code: removed AI artifacts, file headers, section comments
- README rewritten from scratch (625 → 140 lines)

## [1.0.0] — 2026-06-20

### Added
- Initial release of unleash — Unified MDM Bypass for macOS
- **bypass**: Full MDM bypass with admin user creation (Recovery mode)
- **suppress**: Suppress MDM enrollment without creating a user
- **heal**: Auto-heal — check and re-apply suppression after macOS updates
- **persist**: Install LaunchDaemon for boot-time auto-heal
- **unpersist**: Remove the persistence LaunchDaemon
- **firewall**: Block Apple MDM IP ranges via pf (DoH-proof)
- **firewall-off**: Remove pf firewall MDM block
- **harden**: Live-OS hardening (kill MDM, remove profiles, flush DNS)
- **audit**: Deep MDM audit (profiles, certs, agents, risk scoring)
- **whitelist**: Selective block (block MDM only, keep iCloud/App Store)
- **backup/restore**: Save and revert all changes
- **dualboot**: Target external or dual-boot volumes
- **status**: MDM status check with deep audit mode
- User-level MDM artifact cleanup (Preferences, Caches, LaunchAgents)
- Expanded domain blocking (13 Apple MDM domains + org MDM host)
- 4 enrollment daemon overrides (launchd disabled.plist)
- Intel T2 and Apple Silicon support
- DFU/IPSW restore guide in documentation
- macOS Tahoe 26.x compatibility
