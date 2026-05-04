# Changelog

All notable changes to syncgit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-04

### Added

- `gc` subcommand for explicit garbage collection of absorbed and TTL-expired PR refs
- `show <ref>` subcommand for previewing peer PRs before absorbing
- `abort` subcommand for rolling back to the pre-merge or pre-squash snapshot
- `squash` subcommand for collapsing self-authored commits since last broadcast
- `--version` / `-V` flag
- `SYNCGIT_TTL_DAYS` env var (default 14) for TTL-based ref cleanup
- `SYNCGIT_MERGE_STRATEGY` env var (default `merge`, alternative `rebase`)
- Multi-peer merge that preserves every absorbed peer's commit SHA via merge-commit chain
- Per-worktree git identity pinned at init for author-based filtering
- Advisory lock at `.syncgit/lock` to prevent concurrent merge/push/verify races
- Test suite with 9 black-box scenarios in `tests/`
- GitHub Actions CI on macOS and Linux

### Fixed

- Pending refs sort by ref-name timestamp suffix instead of committerdate (clock-stable)
- Inbound peer refs now garbage-collected when ancestor of HEAD
- TTL-expired refs are dropped regardless of absorb status
- Chain-merge conflicts auto-rollback to the original branch with retry guidance
- Snapshot overwrite refused when a previous merge is mid-flight
- Abort restores the original branch context if HEAD was detached during conflict
- Per-peer push success tracked; broadcast incomplete is reported and local ref not recorded
- TS collision risk eliminated with random suffix
- Peer ids validated at init to reject path-traversal patterns

## [Initial commit] — 2025-01-01

### Added

- Initial release with `init`, `peers`, `status`, `fetch`, `stage`, `merge`, `verify`, `push` subcommands
- Linear rebase merge strategy
