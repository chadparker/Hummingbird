//
//  EMRPreferencesController.m
//  easy-move-resize
//
//  Created by Sven A. Schmidt on 13/06/2018.
//  Copyright © 2018 Daniel Marcotte. All rights reserved.
//

#import "EMRPreferencesController.h"

@interface EMRPreferencesController ()

@end

@implementation EMRPreferencesController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if (_prefs) {
        // FIXME: handle click vs hover mode radio button
        {
            EMRMode mode = _prefs.mode;
            _clickModeButton.state = (mode == clickMode) ? NSOnState: NSOffState;
            _hoverModeButton.state = (mode == hoverMode) ? NSOnState: NSOffState;
        }

        {
            NSSet* flags = [_prefs getFlagStringSetForFlagSet:clickFlags];
            NSDictionary *keyButtonMap = @{
                                           ALT_KEY: _altClickButton,
                                           CMD_KEY: _commandClickButton,
                                           CTRL_KEY: _controlClickButton,
                                           FN_KEY: _fnClickButton,
                                           SHIFT_KEY: _shiftClickButton
                                  };
            for (NSString *key in keyButtonMap) {
                NSButton *button = keyButtonMap[key];
                button.state = [flags containsObject:key] ? NSOnState : NSOffState;
            }
        }

        {
            NSSet* flags = [_prefs getFlagStringSetForFlagSet:hoverMoveFlags];
            NSDictionary *keyButtonMap = @{
                                           ALT_KEY: _altHoverMoveButton,
                                           CMD_KEY: _commandHoverMoveButton,
                                           CTRL_KEY: _controlHoverMoveButton,
                                           FN_KEY: _fnHoverMoveButton,
                                           SHIFT_KEY: _shiftHoverMoveButton
                                           };
            for (NSString *key in keyButtonMap) {
                NSButton *button = keyButtonMap[key];
                button.state = [flags containsObject:key] ? NSOnState : NSOffState;
            }
        }

        {
            NSSet* flags = [_prefs getFlagStringSetForFlagSet:hoverResizeFlags];
            NSDictionary *keyButtonMap = @{
                                           ALT_KEY: _altHoverMoveButton,
                                           CMD_KEY: _commandHoverResizeButton,
                                           CTRL_KEY: _controlHoverResizeButton,
                                           FN_KEY: _fnHoverResizeButton,
                                           SHIFT_KEY: _shiftHoverResizeButton
                                           };
            for (NSString *key in keyButtonMap) {
                NSButton *button = keyButtonMap[key];
                button.state = [flags containsObject:key] ? NSOnState : NSOffState;
            }
        }

    }
}

- (IBAction)clickModeClicked:(id)sender {
    if (_clickModeButton.state == NSOnState) {
        _hoverModeButton.state = NSOffState;
        [_prefs setMode:clickMode];
    }
}

- (IBAction)hoverModeClicked:(id)sender {
    if (_hoverModeButton.state == NSOnState) {
        _clickModeButton.state = NSOffState;
        [_prefs setMode:hoverMode];
    }
}

@end
