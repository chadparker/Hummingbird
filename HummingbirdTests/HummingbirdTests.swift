//
//  HummingbirdTests.swift
//  HummingbirdTests
//
//  Created by Sven A. Schmidt on 02/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import XCTest


class HummingbirdTests: XCTestCase {

    func testModifiers() {
        XCTAssertEqual(Modifiers<Move>.shift.rawValue, CGEventFlags.maskShift.rawValue)
        XCTAssertEqual(Modifiers<Move>.control.rawValue, CGEventFlags.maskControl.rawValue)
        XCTAssertEqual(Modifiers<Move>.alt.rawValue, CGEventFlags.maskAlternate.rawValue)
        XCTAssertEqual(Modifiers<Move>.command.rawValue, CGEventFlags.maskCommand.rawValue)
        XCTAssertEqual(Modifiers<Move>.fn.rawValue, CGEventFlags.maskSecondaryFn.rawValue)

        let modifiers: Modifiers<Move> = [.fn, .control]
        XCTAssert(modifiers.exclusivelySet(in: [.maskSecondaryFn, .maskControl]))
        // ignore non-modifier raw values
        XCTAssert(modifiers.exclusivelySet(in: [.maskSecondaryFn, .maskControl, .init(rawValue: 0x1)]))
        XCTAssert(modifiers.exclusivelySet(in: [.maskSecondaryFn, .maskControl, .maskAlphaShift]))
        XCTAssert(!modifiers.exclusivelySet(in: [.maskSecondaryFn]))

        do {
            let mods: Modifiers<Move> = [.shift]
            XCTAssert(mods.exclusivelySet(in: [.maskShift, .init(rawValue: 0x22)]))
        }
    }

    func testPrefs() throws {
        let prefs = testUserDefaults()
        let orig: Modifiers<Move> = [.fn, .control]

        // test read
        prefs.set(orig.rawValue, forKey: DefaultsKeys.moveModifiers.rawValue)
        XCTAssertEqual(Modifiers<Move>(forKey: .moveModifiers, defaults: prefs), orig)

        // test save
        try orig.save(forKey: .moveModifiers, defaults: prefs)
        guard let fetched = prefs.object(forKey: DefaultsKeys.moveModifiers.rawValue) as? UInt64 else {
            XCTFail()
            return
        }
        XCTAssertEqual(Modifiers(rawValue: fetched), orig)
    }

    func testIsEmpty() {
        do {
            let m: Modifiers<Move> = []
            XCTAssert(m.isEmpty)
        }
        do {
            let m: Modifiers<Move> = [.fn, .control]
            XCTAssert(!m.isEmpty)
        }
    }

    func testToggleModifier() {
        let modifiers: Modifiers<Move> = [.fn, .control, .alt]
        XCTAssertEqual(modifiers.toggle(.control), [.fn, .alt])
        XCTAssertEqual(modifiers.toggle(.command), [.fn, .control, .alt, .command])
    }

    func testModifierCustomStringConvertible() {
        XCTAssertEqual("\(Modifiers<Move>([.fn, .control]))", "fn control")
    }

    func testAreaDelta() {
        do {
            let a = CGSize(width: 2, height: 2)
            let delta = CGPoint(x: 2, y: 1)
            XCTAssertEqual(areaDelta(a: a, d: delta), 8.0)
        }
        do {
            let a = CGSize(width: 2, height: 2)
            let delta = CGPoint(x: 2, y: -1)
            XCTAssertEqual(areaDelta(a: a, d: delta), 4.0)
        }
    }

    func testFloatInterpolation() {
        XCTAssertEqual("\(scaled: 0)", "0.0")
        XCTAssertEqual("\(scaled: 1.2345)", "1.2")
        XCTAssertEqual("\(scaled: 1.25)", "1.3")
        XCTAssertEqual("\(scaled: 1234.5)", "1.2k")
        XCTAssertEqual("\(scaled: 1254.5)", "1.3k")
        XCTAssertEqual("\(scaled: 1234567.8)", "1.2M")
        XCTAssertEqual("\(scaled: 1954567.8)", "2.0M")
    }

    func testMetricsInterpolation() {
        do {
            let m = Metrics(distanceMoved: 42, areaResized: 99)
            XCTAssertEqual("\(m)", "Distance: 42.0, Area: 99.0")
        }
        do {
            let m = Metrics(distanceMoved: 35307.18776075068, areaResized: 14870743)
            XCTAssertEqual("\(m)", "Distance: 35.3k, Area: 14.9M")
        }
    }

}
