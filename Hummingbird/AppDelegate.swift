//
//  AppDelegate.swift
//  Test
//
//  Created by Sven A. Schmidt on 02/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Cocoa
import UserNotifications


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    var statusItem: NSStatusItem!
    @IBOutlet weak var enabledMenuItem: NSMenuItem!
    @IBOutlet weak var statsMenuItem: NSMenuItem!
    @IBOutlet weak var versionMenuItem: NSMenuItem!

    lazy var preferencesController: PreferencesController = {
        return PreferencesController(windowNibName: "HBPreferencesController")
    }()

}


// App lifecycle
extension AppDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusMenu.delegate = self
        defaults.register(defaults: DefaultPreferences)

        if #available(OSX 10.14, *) { // set up notification actions
            Notifications.registerCategories()
            UNUserNotificationCenter.current().delegate = self
        }

        if isTrusted() {
            print("trusted")
            enable()
        } else {
            print("trust check FAILED")
            enabledMenuItem.state = .off
            // we now try to enable, because the trust prompt only kicks in then
            Tracker.enable()
            enabledMenuItem.state = (Tracker.isActive ? .on : .off)
        }
    }

    override func awakeFromNib() {
        statusItem = {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.menu = statusMenu
            statusItem.image = NSImage(named: "MenuIcon")
            statusItem.alternateImage = NSImage(named: "MenuIconHighlight")
            statusItem.highlightMode = true
            return statusItem
        }()
        statusMenu.autoenablesItems = false
        versionMenuItem.title = "Version: \(version)"
    }

}


extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        do {
            let hidden = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
            versionMenuItem.isHidden = !hidden
        }
        if let tracker = Tracker.shared {
            statsMenuItem.title = "\(tracker.metricsHistory.currentValue)"
        }
    }
}


// Helpers
extension AppDelegate {

    func isTrusted() -> Bool {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [prompt: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func enable() {
        Tracker.enable()
        enabledMenuItem.state = (Tracker.isActive ? .on : .off)
        if !Tracker.isActive {
            let alert = NSAlert()
            alert.messageText = "Failed to activate"
            alert.informativeText = """
            An error occurred while activating the mechanism to track mouse events.
            
            This can happen when the application has not been granted Accessibility access in "System Preferences" → "Security & Privacy" → "Privacy" → "Accessibility".
            """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func disable() {
        Tracker.disable()
        enabledMenuItem.state = (Tracker.isActive ? .on : .off)
    }

    var version: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(shortVersion) (\(bundleVersion))"
    }

}


// IBActions
extension AppDelegate {

    @IBAction func toggleEnabled(_ sender: Any) {
        if enabledMenuItem.state == .on {
            disable()
        } else {
            enable()
        }
    }

    @IBAction func statsClicked(_ sender: Any) {
        if #available(OSX 10.14, *) {
            if _isDebugAssertConfiguration() {
                Notifications.send()
            }
        }
    }

    @IBAction func showPreferences(_ sender: Any) {
        preferencesController.window?.makeKeyAndOrderFront(sender)
    }


}


// UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    @available(OSX 10.14, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.action {
        case .turnOff?:
            print("turn off")
        case .show?:
            print("show")
        case .none:
            print("no action")
        }
    }
}
