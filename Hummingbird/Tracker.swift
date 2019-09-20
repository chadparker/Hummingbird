//
//  Tracker.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 02/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Cocoa


class Tracker {

    // constants to throttle moving and resizing
    static let moveFilterInterval = 0.01
    static let resizeFilterInterval = 0.02

    static var shared: Tracker? = nil

    static func enable() {
        shared = try? .init()
    }

    static func disable() {
        shared = nil
    }

    static var isActive: Bool {
        return shared != nil
    }


    private let trackingInfo = TrackingInfo()

    #if !TEST  // cannot populate these ivars when testing
    private let eventTap: CFMachPort
    private let runLoopSource: CFRunLoopSource?
    #endif

    private var currentState: State = .idle
    private var moveModifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
    private var resizeModifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
    var metricsHistory = History<Metrics>(forKey: .history, defaults: Current.defaults())

    private init() throws {
        #if TEST
        // don't enable tap for TEST or we'll trigger the permissions alert
        #else

        let res = try enableTap()
        self.eventTap = res.eventTap
        self.runLoopSource = res.runLoopSource
        NotificationCenter.default.addObserver(self, selector: #selector(updateModifiers), name: UserDefaults.didChangeNotification, object: Current.defaults())
        #endif
    }


    deinit {
        #if !TEST
        disableTap(eventTap: eventTap, runLoopSource: runLoopSource)
        NotificationCenter.default.removeObserver(self)
        #endif
    }


    public func handleEvent(_ event: CGEvent, type: CGEventType) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // need to re-enable our eventTap (We got disabled. Usually happens on a slow resizing app)
            log(.debug, "Re-enabling")
            #if !TEST
            CGEvent.tapEnable(tap: eventTap, enable: true)
            #endif
            return false
        }

        if moveModifiers.isEmpty && resizeModifiers.isEmpty { return false }

        let eventModifiers = event.flags
        let move = moveModifiers.exclusivelySet(in: eventModifiers)
        let resize = resizeModifiers.exclusivelySet(in: eventModifiers)

        let nextState: State
        switch (move, resize) {
        case (true, false):
            nextState = .moving
        case (false, true):
            nextState = .resizing
        case (true, true):
            // unreachable unless both options are identical, in which case we default to .moving
            nextState = .moving
        case (false, false):
            // event is not for us
            nextState = .idle
        }

        var absortEvent = false

        switch (currentState, nextState) {
        // .idle -> X
        case (.idle, .idle):
            // event is not for us
            break
        case (.idle, .moving):
            startTracking(event: event)
            absortEvent = true
        case (.idle, .resizing):
            startTracking(event: event)
            determineResizeParams(event: event)
            absortEvent = true

        // .moving -> X
        case (.moving, .idle):
            stopTracking()
        case (.moving, .moving):
            keepMoving(event: event)
        case (.moving, .resizing):
            absortEvent = determineResizeParams(event: event)

        // .resizing -> X
        case (.resizing, .idle):
            stopTracking()
        case (.resizing, .moving):
            startTracking(event: event)
            absortEvent = true
        case (.resizing, .resizing):
            keepResizing(event: event)
        }

        currentState = nextState

        return absortEvent
    }


    private func startTracking(event: CGEvent) {
        guard let clickedWindow = AXUIElement.window(at: event.location) else { return }
        trackingInfo.time = CACurrentMediaTime()
        trackingInfo.origin = clickedWindow.origin ?? CGPoint.zero
        trackingInfo.window = clickedWindow
        trackingInfo.distanceMoved = 0
        trackingInfo.areaResized = 0
    }


    private func stopTracking() {
        trackingInfo.time = 0
        metricsHistory.currentValue.distanceMoved += trackingInfo.distanceMoved
        metricsHistory.currentValue.areaResized += trackingInfo.areaResized
        if #available(OSX 10.14, *) {
            metricsHistory.checkMilestone(metricsHistory.currentValue).map(Notifications.send(milestone:))
        }
        do {
            try metricsHistory.save(forKey: .history, defaults: Current.defaults())
        } catch {
            log(.debug, "Error while saving preferences: \(error)")
        }
    }


    private func keepMoving(event: CGEvent) {
        guard let window = trackingInfo.window else {
            log(.debug, "No window!")
            return
        }

        let delta = event.mouseDelta
        trackingInfo.distanceMoved += delta.magnitude
        trackingInfo.origin += delta

        guard (CACurrentMediaTime() - trackingInfo.time) > Tracker.moveFilterInterval else { return }

        window.origin = trackingInfo.origin
        trackingInfo.time = CACurrentMediaTime()
    }


    @discardableResult
    private func determineResizeParams(event: CGEvent) -> Bool {
        guard let window = trackingInfo.window, let size = window.size else { return false }
        trackingInfo.size = size
        return true
    }


    private func keepResizing(event: CGEvent) {
        guard let window = trackingInfo.window else {
            log(.debug, "No window!")
            return
        }

        let delta = event.mouseDelta
        trackingInfo.distanceMoved += delta.magnitude
        trackingInfo.areaResized += areaDelta(a: trackingInfo.size, d: delta)
        trackingInfo.origin += delta
        trackingInfo.size += delta

        guard (CACurrentMediaTime() - trackingInfo.time) > Tracker.resizeFilterInterval else { return }

        window.size = trackingInfo.size
        trackingInfo.time = CACurrentMediaTime()
    }

    @objc private func updateModifiers() {
        moveModifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
        resizeModifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
    }

}


extension Tracker {

    enum Error: Swift.Error {
        case tapCreateFailed
    }

}


private func enableTap() throws -> (eventTap: CFMachPort, runLoopSource: CFRunLoopSource?)  {
    // https://stackoverflow.com/a/31898592/1444152

    let eventMask = (1 << CGEventType.mouseMoved.rawValue)
    guard let eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: myCGEventCallback,
        userInfo: nil
        ) else {
            throw Tracker.Error.tapCreateFailed
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)

    return (eventTap: eventTap, runLoopSource: runLoopSource)
}


private func disableTap(eventTap: CFMachPort, runLoopSource: CFRunLoopSource?) {
    log(.debug, "Disabling event tap")
    CGEvent.tapEnable(tap: eventTap, enable: false)
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes);
}


private func myCGEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    guard let tracker = Tracker.shared else {
        log(.debug, "🔴 tracker must not be nil")
        return Unmanaged.passRetained(event)
    }

    let absortEvent = tracker.handleEvent(event, type: type)

    return absortEvent ? nil : Unmanaged.passRetained(event)
}
