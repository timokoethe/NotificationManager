import Foundation
import UserNotifications

/// This represents the main class for managing local notifications. To get the functions
/// work, permission needs to be requested.
public struct NotificationManager {
    
    /// Requests permission for alerts, sound and badges for local notifications.
    /// If the authorization process returns an error, the error message is printed
    /// to the console.
    public static func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("Error" + error.localizedDescription)
            }
        }
    }
    
    /// Schedules a notification to arriveon a certain point of time from now.
    /// - Parameters:
    ///   - id: unique id of the notification
    ///   - title: title of the notification that should be shown
    ///   - body: body of the notification that should be show
    ///   - triggerDate: exact date when the notification should arrive
    public static func addNotification(id: String, title: String, body: String, triggerDate: Date) {
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
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print("Error: " + error.localizedDescription)
                }
             }
        }
    }
}
