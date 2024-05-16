import Foundation
import UserNotifications

/// This represents the main class for managing local notifications. To get the functions
/// work, permission needs to be requested from the user.
public struct NotificationManager {
    // MARK: Variables in Context
    // Instance of the UNUserNotificationCenter to get access to all methods.
    private static let center = UNUserNotificationCenter.current()
    
    // MARK: Authorization
    /// Requests authorization for alerts, sound and badges for local notifications.
    /// If the authorization process returns an error, the error message is printed to the console.
    public static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("Error: " + error.localizedDescription)
            }
        }
    }
    
    /// Requests authorization for alerts, sound and badges for local notifications in an asynchronous way.
    /// If the authorization process returns an error, the error message is printed to the console.
    /// - Returns: true if authorization process went good, otherwise false
    public static func requestAuthorization() async -> Bool {
        var status = false
        do {
            try await status = center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Error: " + error.localizedDescription)
        }
        return status
    }
    
    /// Requests authorization for alerts, sound and badges for local notifications in an asynchronous way.
    /// If the authorization process returns an error, the error is thrown.
    /// - Returns: true if authorization process went good, otherwise false
    public static func requestAuthorizationThrowable() async throws -> Bool {
        var status = false
        try await status = center.requestAuthorization(options: [.alert, .sound, .badge])
        return status
    }
    
    /// Retrieves the authorization settings for your app.
    /// - Returns: Constants indicating whether the app is allowed to schedule notifications.
    public static func getAuthorizationStatus() async -> UNAuthorizationStatus {
        var notificationSettings: UNNotificationSettings
        notificationSettings = await center.notificationSettings()
        return notificationSettings.authorizationStatus
    }
    
    // MARK: Schedule
    /// Schedules a notification to arrive at a certain point of time from now.
    /// - Parameters:
    ///   - id: unique id of the notification
    ///   - title: title of the notification that should be shown
    ///   - body: body of the notification that should be shown
    ///   - triggerDate: exact date when the notification should arrive
    public static func scheduleNotification(id: String, title: String, body: String, triggerDate: Date) {
        if triggerDate > Date() {
            //Content
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let timeInterval = triggerDate.timeIntervalSince(Date())
            
            //Trigger
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            
            //Request
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            
            //Schedule
            center.add(request) { (error) in
                if let error = error {
                    print("Error: " + error.localizedDescription)
                }
             }
        }
    }
    
    /// Schedules a notification to arrive after a certain time interval in seconds from now.
    /// - Parameters:
    ///   - id: unique id of the notification
    ///   - title: title of the notification that should be shown
    ///   - body: body of the notification that should be shown
    ///   - timeInterval: time interval in seconds from now when the notification should arrive
    public static func scheduleNotification(id: String, title: String, body: String, timeInterval: Int) {
        if timeInterval > 0 {
            //Content
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            //Trigger
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeInterval), repeats: false)
            
            //Request
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            
            //Schedule
            center.add(request) { (error) in
                if let error = error {
                    print("Error: " + error.localizedDescription)
                }
             }
        }
    }
    
    // MARK: Fetch
    /// Fetches all of your app’s local notifications that are pending delivery.
    /// - Returns: array containing all pending notification requests
    public static func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        var notificationRequests: [UNNotificationRequest]
        notificationRequests = await center.pendingNotificationRequests()
        return notificationRequests
    }
    
    /// Fetches all of your app’s local notifications identifiers that are pending delivery.
    /// - Returns: array containing all identifiers of pending notification requests
    public static func getPendingNotificationRequestsIds() async -> [String] {
        var notificationRequests: [UNNotificationRequest]
        var notificationIds = [String]()
        notificationRequests = await center.pendingNotificationRequests()
        
        guard notificationRequests.isEmpty else {
            print("Hey")
            for notificationRequest in notificationRequests {
                notificationIds.append(notificationRequest.identifier)
            }
            return notificationIds
        }
        
        return notificationIds
    }
    
    // MARK: Update
    /// Updates an already scheduled notification according to new parameters. If the notification's id
    /// does not exist, nothing happens.
    /// - Parameters:
    ///   - id: unique id of the notification
    ///   - newTitle: new title of the notification
    ///   - newBody: new body of the notification
    ///   - newDate: new exact date when the notification should arrive
    public static func replaceNotificationRequestFromId(id: String, newTitle: String, newBody: String, newDate: Date) async throws {
        let requests = await center.pendingNotificationRequests()
        guard !requests.isEmpty else { return }
        guard requests.contains(where: {$0.identifier == id}) else { return }
        
        // Remove old notification
        center.removePendingNotificationRequests(withIdentifiers: [id])
        
        // New content
        let newContent = UNMutableNotificationContent()
        newContent.title = newTitle
        newContent.body = newBody
        
        // New Trigger
        let newTimeInterval = newDate.timeIntervalSince(Date())
        let newTrigger = UNTimeIntervalNotificationTrigger(timeInterval: newTimeInterval, repeats: false)
        
        // New Request
        let newRequest = UNNotificationRequest(identifier: id, content: newContent, trigger: newTrigger)
        try await center.add(newRequest)
    }
    
    // MARK: Remove
    /// Removes all pending notifications. Attention: Removed pending notifications cannot be restored.
    public static func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: Others
    @available(macOS 13.0, *)
    /// Updates the applications badge count.
    /// - Parameter badge: badge count
    public static func setBadge(badge: Int) {
        UNUserNotificationCenter.current().setBadgeCount(badge)
    }
    
    @available(macOS 13.0, *)
    /// Resets the applicaitons badge count.
    public static func resetBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
