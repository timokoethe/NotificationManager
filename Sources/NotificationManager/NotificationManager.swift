import Foundation
import UserNotifications

protocol UserNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func addNotificationRequest(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func deliveredNotifications() async -> [UNNotification]
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
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
    private static let pendingOperations = PendingNotificationOperations()
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
    ///
    /// This fire-and-forget overload prints authorization errors instead of
    /// returning them to the caller. Prefer the throwing asynchronous overload
    /// when the result or error needs to be handled explicitly.
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
    /// - Note: Authorization errors are printed and result in `false`. Use
    ///   ``requestAuthorizationThrowing()`` to propagate errors.
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
    /// - Throws: An error from the system notification center.
    public static func requestAuthorizationThrowing() async throws -> Bool {
        try await center.requestAuthorization(options: defaultAuthorizationOptions)
    }

    /// Requests authorization for alerts, sounds, and badges.
    /// - Returns: Whether the user granted authorization.
    /// - Throws: An error from the system notification center.
    @available(*, deprecated, renamed: "requestAuthorizationThrowing()")
    public static func requestAuthorizationThrowable() async throws -> Bool {
        try await requestAuthorizationThrowing()
    }

    /// Requests authorization for the supplied options.
    /// - Parameter options: The notification authorization options to request.
    /// - Returns: Whether the user granted authorization.
    /// - Throws: An error from the system notification center.
    @discardableResult
    public static func requestAuthorization(for options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    /// Retrieves the current notification authorization status.
    /// - Returns: The current authorization status reported by the system.
    public static func getAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    // MARK: Schedule

    /// Schedules a notification for a future date and reports scheduling errors.
    /// - Parameters:
    ///   - id: A stable identifier for the notification request.
    ///   - title: The title shown in the notification.
    ///   - body: The body shown in the notification.
    ///   - triggerDate: The future date at which the notification should be delivered.
    /// - Throws: ``NotificationManagerError/triggerDateMustBeInFuture`` or an
    ///   error from the system notification center.
    public static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        triggerDate: Date
    ) async throws {
        let notificationCenter = center
        try await pendingOperations.enqueue {
            let interval = triggerDate.timeIntervalSinceNow
            guard interval > 0 else {
                throw NotificationManagerError.triggerDateMustBeInFuture
            }
            let request = try makeRequest(id: id, title: title, body: body, timeInterval: interval, repeats: false)
            try await notificationCenter.addNotificationRequest(request)
        }.value
    }

    /// Schedules a notification for a future date without waiting for completion.
    /// - Parameters:
    ///   - id: A stable identifier for the notification request.
    ///   - title: The title shown in the notification.
    ///   - body: The body shown in the notification.
    ///   - triggerDate: The future date at which the notification should be delivered.
    /// - Note: Validation and scheduling errors are printed instead of returned
    ///   to the caller.
    public static func scheduleNotification(id: String, title: String, body: String, triggerDate: Date) {
        scheduleWithoutWaiting {
            let interval = triggerDate.timeIntervalSinceNow
            guard interval > 0 else {
                throw NotificationManagerError.triggerDateMustBeInFuture
            }
            return try makeRequest(id: id, title: title, body: body, timeInterval: interval, repeats: false)
        }
    }

    /// Schedules a notification after a positive number of seconds and reports scheduling errors.
    /// - Parameters:
    ///   - id: A stable identifier for the notification request.
    ///   - title: The title shown in the notification.
    ///   - body: The body shown in the notification.
    ///   - timeInterval: The delay before delivery, in seconds.
    /// - Throws: ``NotificationManagerError/invalidTimeInterval`` or an error
    ///   from the system notification center.
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

    /// Schedules a notification after a positive number of seconds without waiting for completion.
    /// - Parameters:
    ///   - id: A stable identifier for the notification request.
    ///   - title: The title shown in the notification.
    ///   - body: The body shown in the notification.
    ///   - timeInterval: The delay before delivery, in seconds.
    /// - Note: Validation and scheduling errors are printed instead of returned
    ///   to the caller.
    public static func scheduleNotification(id: String, title: String, body: String, timeInterval: Int) {
        scheduleWithoutWaiting {
            try makeRequest(id: id, title: title, body: body, timeInterval: TimeInterval(timeInterval), repeats: false)
        }
    }

    /// Schedules a repeating notification and reports scheduling errors.
    /// - Parameters:
    ///   - id: A stable identifier for the notification request.
    ///   - title: The title shown in the notification.
    ///   - body: The body shown in the notification.
    ///   - timeInterval: The interval between deliveries, in seconds. It must
    ///     be at least 60 seconds.
    /// - Throws: ``NotificationManagerError/invalidTimeInterval``,
    ///   ``NotificationManagerError/repeatingTimeIntervalTooShort``, or an
    ///   error from the system notification center.
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

    /// Schedules a repeating notification without waiting for completion.
    /// - Parameters:
    ///   - id: A stable identifier for the notification request.
    ///   - title: The title shown in the notification.
    ///   - body: The body shown in the notification.
    ///   - timeInterval: The interval between deliveries, in seconds. It must
    ///     be at least 60 seconds.
    /// - Note: Validation and scheduling errors are printed instead of returned
    ///   to the caller.
    public static func scheduleRepeatNotification(id: String, title: String, body: String, timeInterval: Int) {
        scheduleWithoutWaiting {
            try makeRequest(id: id, title: title, body: body, timeInterval: TimeInterval(timeInterval), repeats: true)
        }
    }

    private static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        timeInterval: TimeInterval,
        repeats: Bool
    ) async throws {
        let request = try makeRequest(id: id, title: title, body: body, timeInterval: timeInterval, repeats: repeats)
        let notificationCenter = center
        try await pendingOperations.enqueue {
            try await notificationCenter.addNotificationRequest(request)
        }.value
    }

    private static func scheduleWithoutWaiting(_ makeRequest: @escaping () throws -> UNNotificationRequest) {
        let notificationCenter = center
        pendingOperations.enqueue {
            do {
                let request = try makeRequest()
                try await notificationCenter.addNotificationRequest(request)
            } catch {
                print("Error: " + error.localizedDescription)
            }
        }
    }

    private static func makeRequest(
        id: String,
        title: String,
        body: String,
        timeInterval: TimeInterval,
        repeats: Bool
    ) throws -> UNNotificationRequest {
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
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    // MARK: Fetch

    /// Fetches all pending local notification requests.
    /// - Returns: The requests that are scheduled and awaiting delivery.
    public static func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        let notificationCenter = center
        return await pendingOperations.enqueue {
            await notificationCenter.pendingNotificationRequests()
        }.value
    }

    /// Fetches the identifiers of all pending local notification requests.
    /// - Returns: The identifiers of requests that are awaiting delivery.
    public static func getPendingNotificationRequestIDs() async -> [String] {
        await getPendingNotificationRequests().map(\.identifier)
    }

    /// Fetches the identifiers of all pending local notification requests.
    /// - Returns: The identifiers of requests that are awaiting delivery.
    @available(*, deprecated, renamed: "getPendingNotificationRequestIDs()")
    public static func getPendingNotificationRequestsIds() async -> [String] {
        await getPendingNotificationRequestIDs()
    }

    /// Fetches all delivered local notifications.
    /// - Returns: The notifications that the system has delivered to the app.
    public static func getDeliveredNotifications() async -> [UNNotification] {
        await center.deliveredNotifications()
    }

    /// Fetches the identifiers of all delivered local notifications.
    /// - Returns: The identifiers of notifications delivered by the system.
    public static func getDeliveredNotificationIDs() async -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    // MARK: Update

    /// Replaces an existing pending notification. If the identifier does not exist, nothing happens.
    /// - Parameters:
    ///   - id: The identifier of the pending request to replace.
    ///   - newTitle: The replacement notification title.
    ///   - newBody: The replacement notification body.
    ///   - newDate: The future delivery date for the replacement request.
    /// - Throws: ``NotificationManagerError/triggerDateMustBeInFuture`` or an
    ///   error from the system notification center.
    public static func replaceNotificationRequestFromId(
        id: String,
        newTitle: String,
        newBody: String,
        newDate: Date
    ) async throws {
        let notificationCenter = center
        try await pendingOperations.enqueue {
            let requests = await notificationCenter.pendingNotificationRequests()
            guard requests.contains(where: { $0.identifier == id }) else {
                return
            }

            let timeInterval = newDate.timeIntervalSinceNow
            guard timeInterval > 0 else {
                throw NotificationManagerError.triggerDateMustBeInFuture
            }

            let request = try makeRequest(
                id: id,
                title: newTitle,
                body: newBody,
                timeInterval: timeInterval,
                repeats: false
            )
            try await notificationCenter.addNotificationRequest(request)
        }.value
    }

    // MARK: Remove

    /// Enqueues removal of all pending notifications after earlier pending operations.
    /// - Note: Returns without waiting. Await ``getPendingNotificationRequests()``
    ///   to observe the state after removal.
    public static func removeAllPendingNotificationRequests() {
        let notificationCenter = center
        pendingOperations.enqueue {
            notificationCenter.removeAllPendingNotificationRequests()
        }
    }

    /// Removes all delivered notifications.
    public static func removeAllDeliveredNotificationRequests() {
        center.removeAllDeliveredNotifications()
    }

    /// Enqueues removal of pending notifications after earlier pending operations.
    /// - Parameter ids: The identifiers of pending requests to remove.
    /// - Note: Returns without waiting. Await ``getPendingNotificationRequests()``
    ///   to observe the state after removal.
    public static func removePendingNotificationRequests(ids: [String]) {
        let notificationCenter = center
        pendingOperations.enqueue {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Removes delivered notifications with the supplied identifiers.
    /// - Parameter ids: The identifiers of delivered notifications to remove.
    public static func removeDeliveredNotifications(ids: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: Badge

    /// Updates the application's badge count.
    /// - Parameter badge: The number to display on the app icon. Pass zero to
    ///   remove the badge.
    /// - Throws: An error from the system notification center.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    public static func setBadge(badge: Int) async throws {
        try await center.setBadgeCount(badge)
    }

    /// Updates the application's badge count without waiting for completion.
    /// - Parameter badge: The number to display on the app icon. Pass zero to
    ///   remove the badge.
    /// - Note: Errors are printed instead of returned to the caller.
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
    /// - Throws: An error from the system notification center.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    public static func resetBadge() async throws {
        try await center.setBadgeCount(0)
    }

    /// Resets the application's badge count without waiting for completion.
    /// - Note: Errors are printed instead of returned to the caller.
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

/// Registers operations synchronously, then waits for each predecessor to finish.
/// A serial task chain also preserves ordering across suspension points.
private final class PendingNotificationOperations {
    private let lock = NSLock()
    private var tail: Task<Void, Never>?

    @discardableResult
    func enqueue<Value>(_ operation: @escaping () async -> Value) -> Task<Value, Never> {
        lock.lock()
        defer { lock.unlock() }
        let previous = tail
        let task = Task {
            await previous?.value
            return await operation()
        }
        tail = Task { _ = await task.value }
        return task
    }

    @discardableResult
    func enqueue<Value>(_ operation: @escaping () async throws -> Value) -> Task<Value, Error> {
        lock.lock()
        defer { lock.unlock() }
        let previous = tail
        let task = Task {
            await previous?.value
            return try await operation()
        }
        // Failure must not prevent later operations (especially removals).
        tail = Task { _ = try? await task.value }
        return task
    }
}
