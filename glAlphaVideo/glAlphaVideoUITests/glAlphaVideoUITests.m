//
//  glAlphaVideoUITests.m
//  glAlphaVideoUITests
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface glAlphaVideoUITests : XCTestCase

@property (nonatomic, strong) XCUIApplication *app;

@end

@implementation glAlphaVideoUITests

- (void)setUp {
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
    [self.app launch];
}

- (void)tearDown {
    self.app = nil;
}

- (void)testGiftPlaybackKeepsAppInForeground {
    XCUIElement *firstCell = [self.app.tables.cells elementBoundByIndex:0];
    XCTAssertTrue([firstCell waitForExistenceWithTimeout:10.0], @"Gift list should appear after launch");
    [firstCell tap];

    // The gift video is decoded by AVFoundation and rendered by OpenGL ES on a CADisplayLink.
    // Give it a few frames, then make sure the app is still alive and on screen.
    [NSThread sleepForTimeInterval:3.0];
    XCTAssertEqual(self.app.state, XCUIApplicationStateRunningForeground);

    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:[XCUIScreen mainScreen].screenshot];
    attachment.name = @"gift-playback";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

@end
