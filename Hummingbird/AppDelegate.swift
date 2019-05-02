//
//  AppDelegate.swift
//  Test
//
//  Created by Sven A. Schmidt on 02/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    var statusItem: NSStatusItem!
    @IBOutlet weak var disabledMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: DefaultPreferences)

        if HBSTracking.checkAXIsProcessTrusted() {
            enable()
        } else {
            disabledMenuItem.state = .on
        }
    }

    override func awakeFromNib() {
        statusItem = HBSTracking.configure(menu: statusMenu)
    }

    func enable() {
        disabledMenuItem.state = .off
        HBSTracking.enable(moveResize: HBMoveResize.instance() as! HBMoveResize)
    }

    func disable() {
        disabledMenuItem.state = .on
        HBSTracking.disable(moveResize: HBMoveResize.instance() as! HBMoveResize)
    }

    // IBActions

    @IBAction func toggleDisabled(_ sender: Any) {
        if disabledMenuItem.state == .off {
            disable()
        } else {
            enable()
        }
    }

    @IBAction func showPreferences(_ sender: Any) {
        HBSTracking.showPreferences(sender: sender)
    }

}

