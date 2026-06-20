# Contributing to NotificationManager

Thanks for helping improve NotificationManager.

NotificationManager is a Swift Package for managing local notifications with `UserNotifications`.

## Getting Started

Clone the repository and open the package in Xcode, or work from the command line:

```sh
swift build
swift test
```

Requirements:

- Xcode 15.0+
- Swift 5.9+
- macOS 10.15+, iOS 13.0+, or visionOS 1.0+

## Guidelines

- Keep pull requests small and focused.
- Follow the existing Swift style and public API shape.
- Keep the package lightweight and avoid unnecessary dependencies.
- Preserve supported platform availability when adding APIs.
- Include tests for behavior that can be covered without requiring real notification delivery.
- Include clear manual test steps when behavior depends on notification authorization, scheduling, badges, or platform-specific behavior.

## Issues

Use GitHub Issues for bugs and feature requests.

For bugs, please include:

- NotificationManager version or commit
- Swift and Xcode version
- Platform and OS version
- Minimal Swift code example
- Steps to reproduce and expected behavior

For feature requests, describe the notification workflow, affected platforms, and any proposed Swift API.

For security issues, follow [SECURITY.md](SECURITY.md).
