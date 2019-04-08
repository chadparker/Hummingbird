#import "AppDelegate.h"
#import "HBMoveResize.h"
#import "HBPreferences.h"
#import "HBHelper.h"
#import "HBPreferencesController.h"

typedef enum : NSUInteger {
    idle = 0,
    moving,
    resizing
} State;


@implementation AppDelegate {
    HBPreferences *preferences;
    HBPreferencesController *_prefs;
}

- (id) init  {
    self = [super init];
    if (self) {
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
        preferences = [[HBPreferences alloc] initWithUserDefaults:userDefaults];
    }
    return self;
}


void startTracking(CGEventRef event, HBMoveResize *moveResize) {
    CGPoint mouseLocation = CGEventGetLocation(event);
    [moveResize setTracking:CACurrentMediaTime()];

    AXUIElementRef _systemWideElement;
    AXUIElementRef _clickedWindow = NULL;
    _systemWideElement = AXUIElementCreateSystemWide();

    AXUIElementRef _element;
    if ((AXUIElementCopyElementAtPosition(_systemWideElement, (float) mouseLocation.x, (float) mouseLocation.y, &_element) == kAXErrorSuccess) && _element) {
        CFTypeRef _role;
        if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityRoleAttribute, &_role) == kAXErrorSuccess) {
            if ([(__bridge NSString *)_role isEqualToString:NSAccessibilityWindowRole]) {
                _clickedWindow = _element;
            }
            if (_role != NULL) CFRelease(_role);
        }
        CFTypeRef _window;
        if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityWindowAttribute, &_window) == kAXErrorSuccess) {
            if (_element != NULL) CFRelease(_element);
            _clickedWindow = (AXUIElementRef)_window;
        }
    }
    CFRelease(_systemWideElement);

    CFTypeRef _cPosition = nil;
    NSPoint cTopLeft;
    if (AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, &_cPosition) == kAXErrorSuccess) {
        if (!AXValueGetValue(_cPosition, kAXValueCGPointType, (void *)&cTopLeft)) {
            NSLog(@"ERROR: Could not decode position");
            cTopLeft = NSMakePoint(0, 0);
        }
        CFRelease(_cPosition);
    }

    cTopLeft.x = (int) cTopLeft.x;
    cTopLeft.y = (int) cTopLeft.y;

    [moveResize setWndPosition:cTopLeft];
    [moveResize setWindow:_clickedWindow];
    if (_clickedWindow != nil) CFRelease(_clickedWindow);
}


void stopTracking(HBMoveResize* moveResize) {
    [moveResize setTracking:0];
}


void keepMoving(CGEventRef event, HBMoveResize* moveResize) {
    AXUIElementRef _clickedWindow = [moveResize window];
    double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
    double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

    NSPoint cTopLeft = [moveResize wndPosition];
    NSPoint thePoint;
    thePoint.x = cTopLeft.x + deltaX;
    thePoint.y = cTopLeft.y + deltaY;
    [moveResize setWndPosition:thePoint];
    CFTypeRef _position;

    // actually applying the change is expensive, so only do it every kMoveFilterInterval seconds
    if (CACurrentMediaTime() - [moveResize tracking] > kMoveFilterInterval) {
        _position = (CFTypeRef) (AXValueCreate(kAXValueCGPointType, (const void *) &thePoint));
        //            NSLog(@"applying change (delta %.1f, %.1f)", deltaX, deltaY);
        AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef) NSAccessibilityPositionAttribute, (CFTypeRef *) _position);
        if (_position != NULL) CFRelease(_position);
        [moveResize setTracking:CACurrentMediaTime()];
    }
}


bool determineResizeParams(CGEventRef event, HBMoveResize* moveResize) {
    AXUIElementRef _clickedWindow = [moveResize window];

    CGPoint clickPoint = CGEventGetLocation(event);

    NSPoint cTopLeft = [moveResize wndPosition];

    clickPoint.x -= cTopLeft.x;
    clickPoint.y -= cTopLeft.y;

    CFTypeRef _cSize;
    NSSize cSize;
    if (!(AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess)
        || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
        NSLog(@"ERROR: Could not decode size");
        return false;
    }
    CFRelease(_cSize);

    NSSize wndSize = cSize;

    // record which direction we should resize in on the drag
    struct ResizeSection resizeSection;
    resizeSection.yResizeDirection = bottom;
    resizeSection.xResizeDirection = right;

    [moveResize setWndSize:wndSize];
    [moveResize setResizeSection:resizeSection];

    return true;
}


void keepResizing(CGEventRef event, HBMoveResize* moveResize) {
    AXUIElementRef _clickedWindow = [moveResize window];
    struct ResizeSection resizeSection = [moveResize resizeSection];
    int deltaX = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
    int deltaY = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

    NSPoint cTopLeft = [moveResize wndPosition];
    NSSize wndSize = [moveResize wndSize];

    wndSize.width += deltaX;
    wndSize.height += deltaY;

    [moveResize setWndPosition:cTopLeft];
    [moveResize setWndSize:wndSize];

    // actually applying the change is expensive, so only do it every kResizeFilterInterval events
    if (CACurrentMediaTime() - [moveResize tracking] > kResizeFilterInterval) {
        // only make a call to update the position if we need to
        if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
            CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
            AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
            CFRelease(_position);
        }

        CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
        AXUIElementSetAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
        CFRelease(_size);
        [moveResize setTracking:CACurrentMediaTime()];
    }
}


CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void *refcon) {
    static State state = idle;

    AppDelegate *ourDelegate = (__bridge AppDelegate*)refcon;

    int moveKeyModifierFlags = [ourDelegate moveModifierFlags];
    int resizeKeyModifierFlags = [ourDelegate resizeModifierFlags];

    if (moveKeyModifierFlags == 0 && resizeKeyModifierFlags == 0) {
        // No modifier keys set. Disable behaviour.
        return event;
    }
    
    HBMoveResize* moveResize = [HBMoveResize instance];

    if ((type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)) {
        // need to re-enable our eventTap (We got disabled.  Usually happens on a slow resizing app)
        CGEventTapEnable([moveResize eventTap], true);
        NSLog(@"Re-enabling...");
        return event;
    }
    
    CGEventFlags flags = CGEventGetFlags(event);

    bool moveModifiersDown = (flags & (moveKeyModifierFlags)) == (moveKeyModifierFlags);
    bool resizeModifiersDown = (flags & (resizeKeyModifierFlags)) == (resizeKeyModifierFlags);

    int ignoredKeysMask = (kCGEventFlagMaskShift | kCGEventFlagMaskCommand | kCGEventFlagMaskAlphaShift | kCGEventFlagMaskAlternate | kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn) ^ (moveKeyModifierFlags | resizeKeyModifierFlags);
    
    if (flags & ignoredKeysMask) {
        // also ignore this event if we've got extra modifiers (i.e. holding down Cmd+Ctrl+Alt should not invoke our action)
        return event;
    }

    State nextState = idle;
    if (moveModifiersDown && resizeModifiersDown) {
        // if one mask is the super set of the other we want to disable the narrower mask
        // otherwise it may steal the event from the other mode
        if (compareMasks(moveKeyModifierFlags, resizeKeyModifierFlags) == wider) {
            nextState = moving;
        } else if (compareMasks(moveKeyModifierFlags, resizeKeyModifierFlags) == smaller) {
            nextState = resizing;
        }
    } else if (moveModifiersDown) {
        nextState = moving;
    } else if (resizeModifiersDown) {
        nextState = resizing;
    }

    bool absorbEvent = false;

    switch (state) {
        case idle:
            switch (nextState) {
                case idle:
                    // event is not for us - just stay idle
                    break;

                case moving:
                    // NSLog(@"idle -> moving");
                    startTracking(event, moveResize);
                    absorbEvent = true;
                    break;

                case resizing:
                    // NSLog(@"idle -> moving/resizing");
                    startTracking(event, moveResize);
                    determineResizeParams(event, moveResize);
                    absorbEvent = true;
                    break;

                default:
                    // invalid transition
                    assert(false);
                    break;
            }
            break;

        case moving:
            switch (nextState) {
                case moving:
                    // NSLog(@"moving");
                    keepMoving(event, moveResize);
                    break;

                case idle:
                    // NSLog(@"moving -> idle");
                    stopTracking(moveResize);
                    break;

                case resizing:
                    // NSLog(@"moving -> resizing");
                    absorbEvent = determineResizeParams(event, moveResize);
                    break;

                default:
                    // invalid transition
                    assert(false);
                    break;
            }
            break;

        case resizing:
            switch (nextState) {
                case resizing:
                    // NSLog(@"resizing");
                    keepResizing(event, moveResize);
                    break;

                case idle:
                    // NSLog(@"resizing -> idle");
                    stopTracking(moveResize);
                    break;

                case moving:
                    // NSLog(@"resizing -> moving");
                    startTracking(event, moveResize);
                    absorbEvent = true;
                    break;

                default:
                    break;
            }
            break;

        default:
            // invalid transition
            assert(false);
            break;
    }
    state = nextState;


    // absorb event if necessary
    if (absorbEvent) {
        return NULL;
    } else {
        return event;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    const void * keys[] = { kAXTrustedCheckOptionPrompt };
    const void * values[] = { kCFBooleanTrue };

    CFDictionaryRef options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys,
            values,
            sizeof(keys) / sizeof(*keys),
            &kCFCopyStringDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

    if (!AXIsProcessTrustedWithOptions(options)) {
        // don't have permission to do our thing right now... AXIsProcessTrustedWithOptions prompted the user to fix
        [_disabledMenu setState:YES];
    } else {
        [self enable];
    }
}

-(void)awakeFromNib{
    NSImage *icon = [NSImage imageNamed:@"MenuIcon"];
    NSImage *altIcon = [NSImage imageNamed:@"MenuIconHighlight"];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:icon];
    [statusItem setAlternateImage:altIcon];
    [statusItem setHighlightMode:YES];
    [statusMenu setAutoenablesItems:NO];
    [[statusMenu itemAtIndex:0] setEnabled:NO];
}

- (void)enableRunLoopSource:(HBMoveResize*)moveResize {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
    CGEventTapEnable([moveResize eventTap], true);
}

- (void)disableRunLoopSource:(HBMoveResize*)moveResize {
    CGEventTapEnable([moveResize eventTap], false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
}

- (void)enable {
    [_disabledMenu setState:NO];

    CGEventMask eventMask = CGEventMaskBit( kCGEventMouseMoved );

    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
                                              (__bridge void * _Nullable)self);

    if (!eventTap) {
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);


    HBMoveResize *moveResize = [HBMoveResize instance];
    [moveResize setEventTap:eventTap];
    [moveResize setRunLoopSource:runLoopSource];
    [self enableRunLoopSource:moveResize];

    CFRelease(runLoopSource);
}

- (void)disable {
    [_disabledMenu setState:YES];
    HBMoveResize* moveResize = [HBMoveResize instance];
    [self disableRunLoopSource:moveResize];
}

- (IBAction)toggleDisabled:(id)sender {
    if ([_disabledMenu state] == 0) {
        // We are enabled. Disable...
        [self disable];
    }
    else {
        // We are disabled. Enable.
        [self enable];
    }
}

- (IBAction)showPreferences:(id)sender {
    if (_prefs == nil) {
        _prefs = [[HBPreferencesController alloc] initWithWindowNibName:@"HBPreferencesController"];
        _prefs.prefs = preferences;
    }
    [_prefs.window makeKeyAndOrderFront:sender];
}

- (int)moveModifierFlags {
    return [preferences modifierFlagsForFlagSet:hoverMoveFlags];
}

- (int)resizeModifierFlags {
    return [preferences modifierFlagsForFlagSet:hoverResizeFlags];
}

@end
