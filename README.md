# NotificationManager

[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](https://opensource.org/license/mit)
[![Build](https://github.com/timokoethe/NotificationManager/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/timokoethe/NotificationManager/actions/workflows/build.yml)
[![Test](https://github.com/timokoethe/NotificationManager/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/timokoethe/NotificationManager/actions/workflows/test.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftimokoethe%2FNotificationManager%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/timokoethe/NotificationManager)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftimokoethe%2FNotificationManager%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/timokoethe/NotificationManager)

NotificationManager is a lightweight Swift package for requesting notification authorization and managing local notifications.

## Requirements

- Swift 5.9+
- Xcode 15.0+
- iOS 13.0+
- macOS 10.15+
- visionOS 1.0+

## Installation

Add the package in Xcode using **File > Add Package Dependencies** and enter:

```text
https://github.com/timokoethe/NotificationManager.git
```

Add `NotificationManager` to your target and import it:

```swift
import NotificationManager
```

## Authorization

Request the standard alert, sound, and badge permissions at a point where the user understands why notifications are needed:

```swift
do {
    let granted = try await NotificationManager.requestAuthorizationThrowable()

    if granted {
        // Notifications are authorized.
    }
} catch {
    // Handle the authorization error.
}
```

To request custom options:

```swift
import UserNotifications

let granted = try await NotificationManager.requestAuthorization(
    for: [.alert, .sound, .badge, .provisional]
)
```

Read the current authorization status:

```swift
let status = await NotificationManager.getAuthorizationStatus()
```

## Scheduling

The asynchronous APIs validate their input and propagate errors from `UNUserNotificationCenter`.

Schedule a notification after a time interval:

```swift
try await NotificationManager.scheduleNotification(
    id: UUID().uuidString,
    title: "Reminder",
    body: "Your task is due.",
    timeInterval: 10
)
```

Schedule a notification for a date:

```swift
let deliveryDate = Date().addingTimeInterval(60)

try await NotificationManager.scheduleNotification(
    id: "task-reminder",
    title: "Reminder",
    body: "Your task is due.",
    triggerDate: deliveryDate
)
```

Schedule a repeating notification:

```swift
try await NotificationManager.scheduleRepeatNotification(
    id: "hourly-reminder",
    title: "Reminder",
    body: "Take a short break.",
    timeInterval: 3_600
)
```

Repeating notifications require an interval of at least 60 seconds.

For compatibility, synchronous fire-and-forget overloads are also available. They print scheduling errors instead of returning them:

```swift
NotificationManager.scheduleNotification(
    id: "task-reminder",
    title: "Reminder",
    body: "Your task is due.",
    timeInterval: 10
)
```

## Error Handling

Input validation uses `NotificationManagerError`:

```swift
do {
    try await NotificationManager.scheduleRepeatNotification(
        id: "reminder",
        title: "Reminder",
        body: "This interval is too short.",
        timeInterval: 30
    )
} catch NotificationManagerError.repeatingTimeIntervalTooShort {
    // Repeating intervals must be at least 60 seconds.
} catch {
    // Handle errors from the notification center.
}
```

Available validation errors:

- `invalidTimeInterval`
- `repeatingTimeIntervalTooShort`
- `triggerDateMustBeInFuture`

## Pending Notifications

Fetch all pending requests:

```swift
import UserNotifications

let requests: [UNNotificationRequest] =
    await NotificationManager.getPendingNotificationRequests()
```

Fetch only their identifiers:

```swift
let identifiers = await NotificationManager.getPendingNotificationRequestsIds()
```

## Replacing Notifications

Replace a pending notification while keeping its identifier:

```swift
try await NotificationManager.replaceNotificationRequestFromId(
    id: "task-reminder",
    newTitle: "Updated reminder",
    newBody: "The task deadline has changed.",
    newDate: Date().addingTimeInterval(300)
)
```

If no pending request has the supplied identifier, the method returns without making changes.

## Removing Notifications

```swift
NotificationManager.removePendingNotificationRequests(
    ids: ["task-reminder", "hourly-reminder"]
)

NotificationManager.removeAllPendingNotificationRequests()
NotificationManager.removeAllDeliveredNotificationRequests()
```

## Badge Count

Badge updates are available on iOS 16+, macOS 13+, and visionOS 1+:

```swift
try await NotificationManager.setBadge(badge: 3)
try await NotificationManager.resetBadge()
```

## Contributing

Bug reports, feature requests, and pull requests are welcome through the GitHub repository.

## License

NotificationManager is available under the [MIT License](LICENSE).
