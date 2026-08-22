# AGENTS.md

## Project

- This repository is a lightweight Swift package for local notification management.
- Keep changes focused, dependency-free where practical, and compatible with the platform versions declared in `Package.swift`.
- Follow the existing Swift style and preserve source compatibility unless a breaking change is explicitly requested.

## Changes

- Put library code in `Sources/NotificationManager` and tests in `Tests/NotificationManagerTests`.
- Add or update XCTest coverage for behavior changes. Use the notification-center abstraction instead of relying on real notification delivery.
- Update public documentation and `README.md` when changing the public API or user-facing behavior.

## Verification

Run before finishing:

```sh
swift test
```

For platform-sensitive changes, also build the affected destination with the `NotificationManager` scheme and code signing disabled.
