# NotificationManager
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](https://opensource.org/license/mit)
[![Build](https://github.com/timokoethe/NotificationManager/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/timokoethe/NotificationManager/actions/workflows/build.yml)
[![Test](https://github.com/timokoethe/NotificationManager/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/timokoethe/NotificationManager/actions/workflows/test.yml)

NotificationManager is a Swift Package to make your code easier for managing local notifications.
This package is supposed to make it possible to manage notifications in a highly intuitive way.
It shall also appear as minimalistic as possible.

## Requirements
- Xcode 15.0+
- macOS 10.15+
- iOS 13.0+
- watchOS 6.0+
- tvOS 12.0+
- visionOS 1.0+

## Installation
1.  Copy the resource url:
```
https://github.com/timokoethe/NotificationManager.git
```
2.  Open your Xcode project.
3.  Navigate to _File_ / _Add Package Dependency_.
4.  Paste the resource url at the top right corner in _Search or Enter Package URL_.
5.  Choose the right target under _Add to project_.
6.  To complete hit _Add Package_.

## Setup
1. Importing the Framework <br>
In any Swift file where you want to use NotificationManager, add the following import statement:
```import NotificationManager```

2. Request notification authorization <br>
Before your app can send notifications, you need to request permission from the user. This is typically done when the app first launches. Add the following code to your App struct or the place wherever you want to ask the user to permit:
```
import SwiftUI
import UserNotifications
import NotificationManager

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationAuthorization()
                }
        }
    }
}
```

## Usage
- Scheduling a Notification <br>
Once you have authorization, you can schedule notifications. Here's an example of how to schedule a notification that should arrive after 10 seconds using NotificationManager by pushing a button:

```
import SwiftUI
import NotificationManager

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Schedule") {
                NotificationManager.scheduleNotification(id: UUID().uuidString, title: "Title", body: "Body", triggerDate: Date()+10)
            }
        }
    }
}
```

- Getting pending notifications
Once you have scheduled one or more notifications you can get all pending:
```
import SwiftUI
import NotificationManager

struct ContentView: View {
    @State private var notifications = [UNNotificationRequest]()
    var body: some View {
        VStack {
            Button("Get") {
                Task {
                    notifications = await NotificationManager.getPendingNotificationRequests()
                }
            }
        }
    }
}
```

- Removing all pending notifications <br>
After scheduling several notifications you can remove them easily:
```
import SwiftUI
import NotificationManager

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Remove") {
                NotificationManager.removeAllPendingNotificationRequests()
            }
        }
    }
}
```

## Contributing
We welcome contributions from the community to help improve NotificationManager. If you encounter any bugs, have feature requests, or would like to contribute code, please feel free to open an issue or submit a pull request on our GitHub repository.

## Support
If you have any questions, feedback, or need assistance with NotificationManager, please don't hesitate to contact us. We're here to help!

## License
NotificationManager is released under the [MIT License](https://opensource.org/license/mit).

Feel free to adjust and expand upon this template to better suit your project's needs!
