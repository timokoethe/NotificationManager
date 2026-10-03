import Foundation
import UserNotifications
import XCTest
@testable import NotificationManager

final class NotificationManagerTests: XCTestCase {
    private var center: TestNotificationCenter!

    override func setUp() {
        super.setUp()
        center = TestNotificationCenter()
        NotificationManager.center = center
    }

    override func tearDown() {
        NotificationManager.resetCenter()
        center = nil
        super.tearDown()
    }

    func testSynchronousSchedulingThenRemovalLeavesNoPendingRequest() async {
        for kind in [SynchronousScheduleKind.interval, .date, .repeating] {
            scheduleSynchronously(kind, id: "request-id")
            NotificationManager.removePendingNotificationRequests(ids: ["request-id"])

            let requests = await NotificationManager.getPendingNotificationRequests()
            XCTAssertTrue(requests.isEmpty)
        }
        XCTAssertEqual(center.addedRequests.count, 3)
    }

    func testRemovalWaitsForSuspendedAddToFinish() async {
        let started = expectation(description: "Add started")
        let gate = AddGate(started: started)
        center.beforeAdd = { await gate.wait() }
        scheduleSynchronously(.interval, id: "request-id")
        await fulfillment(of: [started], timeout: 2)

        NotificationManager.removePendingNotificationRequests(ids: ["request-id"])
        await gate.release()

        let requests = await NotificationManager.getPendingNotificationRequests()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(center.addedRequests.count, 1)
    }

    func testRemoveAllFollowsEarlierSchedules() async {
        scheduleSynchronously(.interval, id: "first")
        scheduleSynchronously(.repeating, id: "second")
        NotificationManager.removeAllPendingNotificationRequests()

        let requests = await NotificationManager.getPendingNotificationRequests()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(center.addedRequests.count, 2)
    }

    func testScopedRemovalPreservesOtherAndLaterRequests() async {
        scheduleSynchronously(.interval, id: "other")
        scheduleSynchronously(.interval, id: "request-id")
        NotificationManager.removePendingNotificationRequests(ids: ["request-id"])
        scheduleSynchronously(.date, id: "request-id")

        let requests = await NotificationManager.getPendingNotificationRequests()
        XCTAssertEqual(Set(requests.map(\.identifier)), ["other", "request-id"])
        XCTAssertEqual(center.addedRequests.count, 3)
    }

    func testFailedAddDoesNotPreventLaterRemoval() async {
        center.addError = TestError.addFailed
        scheduleSynchronously(.interval, id: "request-id")
        NotificationManager.removeAllPendingNotificationRequests()

        let requests = await NotificationManager.getPendingNotificationRequests()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(center.removedAllPendingRequests)
    }

    func testThrowingAddDoesNotBlockQueueAfterFailure() async {
        center.addError = TestError.addFailed
        await XCTAssertThrowsErrorAsync(
            try await NotificationManager.scheduleNotification(
                id: "request-id", title: "Title", body: "Body", timeInterval: 10
            )
        ) { error in
            XCTAssertEqual(error as? TestError, .addFailed)
        }
        NotificationManager.removeAllPendingNotificationRequests()

        _ = await NotificationManager.getPendingNotificationRequests()
        XCTAssertTrue(center.removedAllPendingRequests)
    }

    func testReplacementSeesEarlierSynchronousSchedule() async throws {
        scheduleSynchronously(.interval, id: "request-id")
        try await NotificationManager.replaceNotificationRequestFromId(
            id: "request-id", newTitle: "Replacement", newBody: "Body",
            newDate: Date().addingTimeInterval(120)
        )

        let requests = await NotificationManager.getPendingNotificationRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.content.title, "Replacement")
    }

    // Keep overload selection in a synchronous context.
    private func scheduleSynchronously(_ kind: SynchronousScheduleKind, id: String) {
        switch kind {
        case .interval:
            NotificationManager.scheduleNotification(id: id, title: "Title", body: "Body", timeInterval: 10)
        case .date:
            NotificationManager.scheduleNotification(
                id: id, title: "Title", body: "Body", triggerDate: Date().addingTimeInterval(120)
            )
        case .repeating:
            NotificationManager.scheduleRepeatNotification(id: id, title: "Title", body: "Body", timeInterval: 60)
        }
    }

    func testDefaultAuthorizationRequestsOnlyAlertSoundAndBadge() async throws {
        center.authorizationGranted = true

        let granted = try await NotificationManager.requestAuthorizationThrowing()

        XCTAssertTrue(granted)
        XCTAssertEqual(center.requestedAuthorizationOptions, [.alert, .sound, .badge])
    }

    func testCustomAuthorizationReturnsResult() async throws {
        center.authorizationGranted = true

        let granted = try await NotificationManager.requestAuthorization(for: [.provisional])

        XCTAssertTrue(granted)
        XCTAssertEqual(center.requestedAuthorizationOptions, [.provisional])
    }

    func testScheduleNotificationCreatesExpectedRequest() async throws {
        try await NotificationManager.scheduleNotification(
            id: "request-id",
            title: "Title",
            body: "Body",
            timeInterval: 10
        )

        let request = try XCTUnwrap(center.addedRequests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(request.identifier, "request-id")
        XCTAssertEqual(request.content.title, "Title")
        XCTAssertEqual(request.content.body, "Body")
        XCTAssertEqual(trigger.timeInterval, 10)
        XCTAssertFalse(trigger.repeats)
    }

    func testScheduleNotificationRejectsNonPositiveInterval() async {
        await XCTAssertThrowsErrorAsync(
            try await NotificationManager.scheduleNotification(
                id: "request-id",
                title: "Title",
                body: "Body",
                timeInterval: 0
            )
        ) { error in
            XCTAssertEqual(error as? NotificationManagerError, .invalidTimeInterval)
        }
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testScheduleNotificationPropagatesCenterError() async {
        center.addError = TestError.addFailed

        await XCTAssertThrowsErrorAsync(
            try await NotificationManager.scheduleNotification(
                id: "request-id",
                title: "Title",
                body: "Body",
                timeInterval: 10
            )
        ) { error in
            XCTAssertEqual(error as? TestError, .addFailed)
        }
    }

    func testRepeatingNotificationRejectsIntervalBelowSixtySeconds() async {
        await XCTAssertThrowsErrorAsync(
            try await NotificationManager.scheduleRepeatNotification(
                id: "request-id",
                title: "Title",
                body: "Body",
                timeInterval: 59
            )
        ) { error in
            XCTAssertEqual(error as? NotificationManagerError, .repeatingTimeIntervalTooShort)
        }
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testRepeatingNotificationAcceptsSixtySeconds() async throws {
        try await NotificationManager.scheduleRepeatNotification(
            id: "request-id",
            title: "Title",
            body: "Body",
            timeInterval: 60
        )

        let request = try XCTUnwrap(center.addedRequests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 60)
        XCTAssertTrue(trigger.repeats)
    }

    func testDateSchedulingRejectsPastDate() async {
        await XCTAssertThrowsErrorAsync(
            try await NotificationManager.scheduleNotification(
                id: "request-id",
                title: "Title",
                body: "Body",
                triggerDate: Date().addingTimeInterval(-1)
            )
        ) { error in
            XCTAssertEqual(error as? NotificationManagerError, .triggerDateMustBeInFuture)
        }
    }

    func testReplaceAddsSameIdentifierWithoutRemovingOldRequestFirst() async throws {
        center.pendingRequests = [
            UNNotificationRequest(
                identifier: "request-id",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        ]

        try await NotificationManager.replaceNotificationRequestFromId(
            id: "request-id",
            newTitle: "New title",
            newBody: "New body",
            newDate: Date().addingTimeInterval(120)
        )

        XCTAssertEqual(center.removedIdentifierGroups, [])
        XCTAssertEqual(center.addedRequests.first?.identifier, "request-id")
        XCTAssertEqual(center.addedRequests.first?.content.title, "New title")
        XCTAssertEqual(center.addedRequests.first?.content.body, "New body")
    }

    func testReplaceRejectsPastDateWithoutChangingExistingRequest() async {
        center.pendingRequests = [
            UNNotificationRequest(
                identifier: "request-id",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        ]

        await XCTAssertThrowsErrorAsync(
            try await NotificationManager.replaceNotificationRequestFromId(
                id: "request-id",
                newTitle: "New title",
                newBody: "New body",
                newDate: Date().addingTimeInterval(-1)
            )
        ) { error in
            XCTAssertEqual(error as? NotificationManagerError, .triggerDateMustBeInFuture)
        }

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertTrue(center.removedIdentifierGroups.isEmpty)
    }

    func testPendingRequestIdentifiersAreMappedDirectly() async {
        center.pendingRequests = [
            UNNotificationRequest(identifier: "first", content: UNMutableNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "second", content: UNMutableNotificationContent(), trigger: nil)
        ]

        let identifiers = await NotificationManager.getPendingNotificationRequestIDs()

        XCTAssertEqual(identifiers, ["first", "second"])
    }

    func testDeliveredNotificationsAreReturned() async {
        center.deliveredNotificationValues = [
            makeDeliveredNotification(identifier: "first"),
            makeDeliveredNotification(identifier: "second")
        ]

        let notifications = await NotificationManager.getDeliveredNotifications()

        XCTAssertEqual(notifications.map(\.request.identifier), ["first", "second"])
    }

    func testDeliveredNotificationIdentifiersAreMappedDirectly() async {
        center.deliveredNotificationValues = [
            makeDeliveredNotification(identifier: "first"),
            makeDeliveredNotification(identifier: "second")
        ]

        let identifiers = await NotificationManager.getDeliveredNotificationIDs()

        XCTAssertEqual(identifiers, ["first", "second"])
    }

    func testRemoveDeliveredNotificationsPassesIdentifiersThrough() {
        NotificationManager.removeDeliveredNotifications(ids: ["first", "second"])

        XCTAssertEqual(center.removedDeliveredIdentifierGroups, [["first", "second"]])
    }
}

private final class TestNotificationCenter: UserNotificationCenter {
    var authorizationGranted = false
    var authorizationStatusValue: UNAuthorizationStatus = .notDetermined
    var requestedAuthorizationOptions: UNAuthorizationOptions?
    var addedRequests: [UNNotificationRequest] = []
    var addError: Error?
    var beforeAdd: (() async -> Void)?
    var pendingRequests: [UNNotificationRequest] = []
    var deliveredNotificationValues: [UNNotification] = []
    var removedIdentifierGroups: [[String]] = []
    var removedDeliveredIdentifierGroups: [[String]] = []
    var removedAllPendingRequests = false
    var removedAllDeliveredNotifications = false
    var badgeCounts: [Int] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        return authorizationGranted
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        await beforeAdd?()
        if let addError {
            throw addError
        }
        addedRequests.append(request)
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func deliveredNotifications() async -> [UNNotification] {
        deliveredNotificationValues
    }

    func removeAllPendingNotificationRequests() {
        removedAllPendingRequests = true
        pendingRequests.removeAll()
    }

    func removeAllDeliveredNotifications() {
        removedAllDeliveredNotifications = true
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierGroups.append(identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifierGroups.append(identifiers)
    }

    func setBadgeCount(_ count: Int) async throws {
        badgeCounts.append(count)
    }
}

private enum TestError: Error, Equatable {
    case addFailed
}

private func makeDeliveredNotification(identifier: String) -> UNNotification {
    let request = UNNotificationRequest(
        identifier: identifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    )

    return UNNotification(coder: TestNotificationCoder(request: request))!
}

private final class TestNotificationCoder: NSCoder {
    private let request: UNNotificationRequest

    init(request: UNNotificationRequest) {
        self.request = request
    }

    override var allowsKeyedCoding: Bool {
        true
    }

    override func decodeObject(forKey key: String) -> Any? {
        key == "request" ? request : nil
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

private enum SynchronousScheduleKind {
    case interval, date, repeating
}

private actor AddGate {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?

    init(started: XCTestExpectation) {
        self.started = started
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
