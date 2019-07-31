//
//  Notifications.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 08/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import UserNotifications


@available(OSX 10.14, *)
struct Notifications {

    enum Actions: String, CaseIterable {
        case turnOff = "TURN_OFF"
        case show = "SHOW"

        var title: String {
            switch self {
            case .turnOff:
                return "Turn off"
            case .show:
                return "Show"
            }
        }

        var action: UNNotificationAction {
            let options = UNNotificationActionOptions(rawValue: 0)
            return UNNotificationAction(identifier: self.rawValue, title: title, options: options)
        }

        static var metricsMilestone: [Actions] { return [.turnOff, .show] }
    }

    enum Categories: String, CaseIterable {
        case metricsMilestone = "METRICS_MILESTONE"

        var category: UNNotificationCategory {
            switch self {
            case .metricsMilestone:
                return UNNotificationCategory(identifier: self.rawValue,
                                              actions: Actions.metricsMilestone.map { $0.action },
                                              intentIdentifiers: [],
                                              hiddenPreviewsBodyPlaceholder: "",
                                              options: .customDismissAction)
            }
        }
    }

    static func registerCategories(_ notificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories(Set(Categories.allCases.map { $0.category }))

    }

    static func send(milestone: Milestone) {
        guard let tracker = Tracker.shared else {
            print("no tracker")
            return
        }
        if let lastNotified = defaults.object(forKey: DefaultsKeys.lastNotified.rawValue) as? Date {
            // send only one notification per day
            guard lastNotified.truncated() != Current.date().truncated() else { return }
        }
        let content = UNMutableNotificationContent()
        content.title = "New window fiddling milestone"
        switch milestone {
        case .exceededAverage:
            content.body = "Above average mousing today: \(tracker.metricsHistory.currentValue)"
        }
        content.category = Categories.metricsMilestone
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
            if let error = error {
                print("Error while sending notification: \(error)")
            } else {
                defaults.set(Current.date(), forKey: DefaultsKeys.lastNotified.rawValue)
            }
        }
    }

}


@available(OSX 10.14, *)
extension UNMutableNotificationContent {
    var category: Notifications.Categories? {
        set {
            guard let newValue = newValue else { return }
            categoryIdentifier = newValue.rawValue
        }
        get {
            return Notifications.Categories(rawValue: categoryIdentifier)
        }
    }
}


@available(OSX 10.14, *)
extension UNNotificationResponse {
    var action: Notifications.Actions? {
        get {
            return Notifications.Actions(rawValue: actionIdentifier)
        }
    }
}
