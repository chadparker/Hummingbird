//
//  EMRPreferencesController.h
//  easy-move-resize
//
//  Created by Sven A. Schmidt on 13/06/2018.
//  Copyright © 2018 Daniel Marcotte. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "HBPreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface EMRPreferencesController : NSWindowController {
    HBPreferences *_prefs;
}

@property HBPreferences *prefs;

@property (weak) IBOutlet NSButton *altHoverMoveButton;
@property (weak) IBOutlet NSButton *commandHoverMoveButton;
@property (weak) IBOutlet NSButton *controlHoverMoveButton;
@property (weak) IBOutlet NSButton *fnHoverMoveButton;
@property (weak) IBOutlet NSButton *shiftHoverMoveButton;

@property (weak) IBOutlet NSButton *altHoverResizeButton;
@property (weak) IBOutlet NSButton *commandHoverResizeButton;
@property (weak) IBOutlet NSButton *controlHoverResizeButton;
@property (weak) IBOutlet NSButton *fnHoverResizeButton;
@property (weak) IBOutlet NSButton *shiftHoverResizeButton;


- (IBAction)modifierClicked:(NSButton *)sender;

@end

NS_ASSUME_NONNULL_END
