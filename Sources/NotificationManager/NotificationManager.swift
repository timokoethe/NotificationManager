import Foundation
import UserNotifications

protocol UserNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func addNotificationRequest(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    func setBadgeCount(_ count: Int) async throws
}

extension UNUserNotificationCenter: UserNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await add(request)
    }
}

/// Errors produced while validating a notification request.
public enum NotificationManagerError: Error, Equatable {
    /// A non-repeating notification must have a positive time interval.
    case invalidTimeInterval
    /// A repeating notification must have a time interval of at least 60 seconds.
    case repeatingTimeIntervalTooShort
    /// A date-based notification must be scheduled for a future date.
    case triggerDateMustBeInFuture
}

extension NotificationManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidTimeInterval:
            return "The notification time interval must be greater than zero."
        case .repeatingTimeIntervalTooShort:
            return "Repeating notifications require a time interval of at least 60 seconds."
        case .triggerDateMustBeInFuture:
            return "The notification trigger date must be in the future."
        }
    }
}

/// Manages local notification authorization, scheduling, querying, and removal.
public struct NotificationManager {
    private static let defaultAuthorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
    private static var centerOverride: (any UserNotificationCenter)?
    static var center: any UserNotificationCenter {
        get { centerOverride ?? UNUserNotificationCenter.current() }
        set { centerOverride = newValue }
    }

    static func resetCenter() {
        centerOverride = nil
    }

    // MARK: Authorization

    /// Requests authorization for alerts, sounds, and badges.
    public static func requestAuthorization() {
        Task {
            do {
                _ = try await center.requestAuthorization(options: defaultAuthorizationOptions)
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }

    /// Requests authorization for alerts, sounds, and badges.
    /// - Returns: Whether the user granted authorization.
    public static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: defaultAuthorizationOptions)
        } catch {
            print("Error: " + error.localizedDescription)
            return false
        }
    }

    /// Requests authorization for alerts, sounds, and badges.
    /// - Returns: Whether the user granted authorization.
    public static func requestAuthorizationThrowable() async throws -> Bool {
        try await center.requestAuthorization(options: defaultAuthorizationOptions)
    }

    /// Requests authorization for the supplied options.
    /// - Parameter options: The notification authorization options to request.
    /// - Returns: Whether the user granted authorization.
    @discardableResult
    public static func requestAuthorization(for options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    /// Retrieves the current notification authorization status.
    public static func getAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    // MARK: Schedule

    /// Schedules a notification for a future date and reports scheduling errors.
    public static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        triggerDate: Date
    ) async throws {
        let timeInterval = triggerDate.timeIntervalSinceNow
        guard timeInterval > 0 else {
            throw NotificationManagerError.triggerDateMustBeInFuture
        }

        try await scheduleNotification(
            id: id,
            title: title,
            body: body,
            timeInterval: timeInterval,
            repeats: false
        )
    }

    /// Schedules a notification for a future date.
    public static func scheduleNotification(id: String, title: String, body: String, triggerDate: Date) {
        Task {
            do {
                try await scheduleNotification(id: id, title: title, body: body, triggerDate: triggerDate)
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }

    /// Schedules a notification after a positive number of seconds and reports scheduling errors.
    public static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        timeInterval: Int
    ) async throws {
        try await scheduleNotification(
            id: id,
            title: title,
            body: body,
            timeInterval: TimeInterval(timeInterval),
            repeats: false
        )
    }

    /// Schedules a notification after a positive number of seconds.
    public static func scheduleNotification(id: String, title: String, body: String, timeInterval: Int) {
        Task {
            do {
                try await scheduleNotification(id: id, title: title, body: body, timeInterval: timeInterval)
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }

    /// Schedules a repeating notification and reports scheduling errors.
    public static func scheduleRepeatNotification(
        id: String,
        title: String,
        body: String,
        timeInterval: Int
    ) async throws {
        try await scheduleNotification(
            id: id,
            title: title,
            body: body,
            timeInterval: TimeInterval(timeInterval),
            repeats: true
        )
    }

    /// Schedules a repeating notification. Repeating intervals must be at least 60 seconds.
    public static func scheduleRepeatNotification(id: String, title: String, body: String, timeInterval: Int) {
        Task {
            do {
                try await scheduleRepeatNotification(
                    id: id,
                    title: title,
                    body: body,
                    timeInterval: timeInterval
                )
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }

    private static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        timeInterval: TimeInterval,
        repeats: Bool
    ) async throws {
        guard timeInterval > 0 else {
            throw NotificationManagerError.invalidTimeInterval
        }
        guard !repeats || timeInterval >= 60 else {
            throw NotificationManagerError.repeatingTimeIntervalTooShort
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.addNotificationRequest(request)
    }

    // MARK: Fetch

    /// Fetches all pending local notification requests.
    public static func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    /// Fetches the identifiers of all pending local notification requests.
    public static func getPendingNotificationRequestsIds() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    // MARK: Update

    /// Replaces an existing pending notification. If the identifier does not exist, nothing happens.
    public static func replaceNotificationRequestFromId(
        id: String,
        newTitle: String,
        newBody: String,
        newDate: Date
    ) async throws {
        let requests = await center.pendingNotificationRequests()
        guard requests.contains(where: { $0.identifier == id }) else {
            return
        }

        let timeInterval = newDate.timeIntervalSinceNow
        guard timeInterval > 0 else {
            throw NotificationManagerError.triggerDateMustBeInFuture
        }

        // Adding a request with an existing identifier atomically replaces the old request.
        try await scheduleNotification(
            id: id,
            title: newTitle,
            body: newBody,
            timeInterval: timeInterval,
            repeats: false
        )
    }

    // MARK: Remove

    /// Removes all pending notifications.
    public static func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    /// Removes all delivered notifications.
    public static func removeAllDeliveredNotificationRequests() {
        center.removeAllDeliveredNotifications()
    }

    /// Removes pending notifications with the supplied identifiers.
    public static func removePendingNotificationRequests(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Badge

    /// Updates the application's badge count.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    public static func setBadge(badge: Int) async throws {
        try await center.setBadgeCount(badge)
    }

    /// Updates the application's badge count.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    public static func setBadge(badge: Int) {
        Task {
            do {
                try await setBadge(badge: badge)
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }

    /// Resets the application's badge count.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    public static func resetBadge() async throws {
        try await center.setBadgeCount(0)
    }

    /// Resets the application's badge count.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    public static func resetBadge() {
        Task {
            do {
                try await resetBadge()
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }
}
