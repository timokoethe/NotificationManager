# ``NotificationManager``

Manage local notifications with a small, async-first Swift API.

NotificationManager wraps the system notification center and provides APIs for
requesting authorization, scheduling notifications, querying their state, and
removing them. The package does not deliver notifications itself; delivery is
handled by `UserNotifications`.

## Overview

Before scheduling local notifications, request authorization at a point where
the user understands why notifications are needed:

```swift
import NotificationManager

do {
    let granted = try await NotificationManager.requestAuthorizationThrowing()

    if granted {
        try await NotificationManager.scheduleNotification(
            id: "task-reminder",
            title: "Reminder",
            body: "Your task is due.",
            timeInterval: 60
        )
    }
} catch {
    // Handle authorization or scheduling errors.
}
```

The throwing asynchronous APIs are recommended for new code because they make
validation and notification-center errors observable. Non-async
fire-and-forget overloads are available for compatibility, but handle errors by
printing them from an asynchronous task.

Pending scheduling, replacement, queries, and removal share an internal queue.
Synchronous calls register their operations before returning, so a subsequent
removal waits for earlier additions to finish. Removal methods enqueue work and
return without blocking. Await ``NotificationManager/getPendingNotificationRequests()``
to observe the state after earlier operations complete. Concurrent calls are
ordered at queue registration; direct system notification-center calls are outside
this guarantee.

## Topics

### Authorization

- ``NotificationManager/requestAuthorizationThrowing()``
- ``NotificationManager/requestAuthorization()->_``
- ``NotificationManager/requestAuthorization()->()``
- ``NotificationManager/requestAuthorization(for:)``
- ``NotificationManager/getAuthorizationStatus()``

### Scheduling

- ``NotificationManager/scheduleNotification(id:title:body:timeInterval:)-1ha42``
- ``NotificationManager/scheduleNotification(id:title:body:timeInterval:)-1ipdm``
- ``NotificationManager/scheduleNotification(id:title:body:triggerDate:)-8oxhh``
- ``NotificationManager/scheduleNotification(id:title:body:triggerDate:)-2zqr2``
- ``NotificationManager/scheduleRepeatNotification(id:title:body:timeInterval:)-9tois``
- ``NotificationManager/scheduleRepeatNotification(id:title:body:timeInterval:)-2q2t7``

### Querying Notifications

- ``NotificationManager/getPendingNotificationRequests()``
- ``NotificationManager/getPendingNotificationRequestIDs()``
- ``NotificationManager/getDeliveredNotifications()``
- ``NotificationManager/getDeliveredNotificationIDs()``

### Updating and Removing Notifications

- ``NotificationManager/replaceNotificationRequestFromId(id:newTitle:newBody:newDate:)``
- ``NotificationManager/removePendingNotificationRequests(ids:)``
- ``NotificationManager/removeAllPendingNotificationRequests()``
- ``NotificationManager/removeDeliveredNotifications(ids:)``
- ``NotificationManager/removeAllDeliveredNotificationRequests()``

### Badge

- ``NotificationManager/setBadge(badge:)-5ir8o``
- ``NotificationManager/setBadge(badge:)-7tvfe``
- ``NotificationManager/resetBadge()-yomw``
- ``NotificationManager/resetBadge()-7ejrf``

Badge APIs are available on iOS 16+, macOS 13+, and visionOS 1+.

### Errors

- ``NotificationManagerError``
