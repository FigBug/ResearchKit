/*
 Copyright (c) 2016, Motus Design Group Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ORKTrailmakingStepViewController.h"

#import "ORKActiveStepTimer.h"
#import "ORKActiveStepView.h"
#import "ORKTrailmakingContentView.h"
#import "ORKCustomStepView_Internal.h"
#import "ORKRoundTappingButton.h"

#import "ORKActiveStepViewController_Internal.h"

#import "ORKTrailmakingStep.h"
#import "ORKStep_Private.h"
#import "ORKResult.h"

#import "ORKHelpers_Internal.h"
#import "ORKStepViewController_Internal.h"


#define BOUND(lo, hi, v) (((v) < (lo)) ? (lo) : (((v) > (hi)) ? (hi) : (v)))

@interface ORKTrailmakingStepViewController ()

@end


@implementation ORKTrailmakingStepViewController {
    ORKTrailmakingContentView *_trailmakingContentView;
    NSArray *testPoints;
    ORKTrailMakingTypeIdentifier trailType;
    int nextIndex;
    int errors;
    NSMutableArray *taps;
    NSTimer *updateTimer;
    UILabel *timerLabel;
}

- (instancetype)initWithStep:(ORKStep *)step {
    self = [super initWithStep:step];
    if (self) {
        testPoints = [self fetchRandomTest];
        taps = [NSMutableArray array];
        
        if ([step isKindOfClass:[ORKTrailmakingStep class]]) {
            trailType = [((ORKTrailmakingStep*)step) trailType];
        } else {
            trailType = ORKTrailMakingTypeIdentifierA;
        }
    }
    return self;
}

- (void)initializeInternalButtonItems {
    [super initializeInternalButtonItems];
    
    // Don't show next button
    self.internalContinueButtonItem = nil;
    self.internalDoneButtonItem = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _trailmakingContentView = [[ORKTrailmakingContentView alloc] initWithType:trailType];
    
    self.activeStepView.activeCustomView = _trailmakingContentView;
    
    for (ORKRoundTappingButton* b in _trailmakingContentView.tapButtons) {
        [b addTarget:self action:@selector(buttonPressed:forEvent:) forControlEvents:UIControlEventTouchDown];
    }
    
    timerLabel = [[UILabel alloc] init];
    timerLabel.textAlignment = NSTextAlignmentCenter;
    
    [self.view addSubview:timerLabel];
}

- (void)timerUpdated:(NSTimer*)timer {
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate: self.presentedDate];
    NSString *text = [NSString localizedStringWithFormat:ORKLocalizedString(@"TRAILMAKING_TIMER", nil), elapsed];
    
    if (errors == 1) {
        text = [NSString localizedStringWithFormat:ORKLocalizedString(@"TRAILMAKING_ERROR", nil), text, errors];
    } else if (errors > 1) {
        text = [NSString localizedStringWithFormat:ORKLocalizedString(@"TRAILMAKING_ERROR_PLURAL", nil), text, errors];
    }
    
    timerLabel.text = text;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    int screenSize = MAX(screenRect.size.width, screenRect.size.height);
    
    int cx;
    
    if (screenSize >= 736) {
        cx = 74;  // iPhone 6+/7+
    } else if (screenSize >= 667) {
        cx = 45; // iPhone 6/7
    } else {
        cx = 40;  // iPhone 5/SE
    }
    
    CGRect testFrame = _trailmakingContentView.frame;
    CGRect labelRect = CGRectMake(testFrame.origin.x, 0, testFrame.size.width, 20);
    [timerLabel setFrame:labelRect];
    
    CGRect r = _trailmakingContentView.testArea;
        
    int idx = 0;
    
    for (ORKRoundTappingButton* b in _trailmakingContentView.tapButtons) {
        CGPoint pp = [[testPoints objectAtIndex:idx] CGPointValue];
        
        if (r.size.width > r.size.height)
        {
            float temp = pp.x;
            pp.x = pp.y;
            pp.y = temp;
        }
        
        const int x = BOUND(5, r.size.width - cx - 5, pp.x * r.size.width);
        const int y = BOUND(5, r.size.height - cx - 5, pp.y * r.size.height);
        
        b.frame = CGRectMake(x, y, cx, cx);
        b.diameter = cx;
        
        idx++;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self start];
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerUpdated:) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (updateTimer != nil) {
        [updateTimer invalidate];
        updateTimer = nil;
    }
}

- (IBAction)buttonPressed:(id)button forEvent:(UIEvent *)event {
    NSUInteger buttonIndex = [_trailmakingContentView.tapButtons indexOfObject:button];
    if (buttonIndex != NSNotFound) {
        
        ORKTrailmakingTap* tap = [[ORKTrailmakingTap alloc] init];
        tap.timestamp = [[NSDate date] timeIntervalSinceDate: self.presentedDate];
        tap.index = buttonIndex;
        
        if (buttonIndex == nextIndex) {

            if ((int)buttonIndex - 1 >= 0)
                _trailmakingContentView.tapButtons[buttonIndex - 1].selected = NO;
            _trailmakingContentView.tapButtons[buttonIndex].selected = YES;
            
            nextIndex++;
            
            _trailmakingContentView.linesToDraw = nextIndex - 1;
            if (nextIndex == _trailmakingContentView.tapButtons.count) {
                [self performSelector:@selector(finish) withObject:nil afterDelay:1.5];
                [updateTimer invalidate];
                updateTimer = nil;
            }
            tap.incorrect = NO;
            
            [_trailmakingContentView clearErrors];
        } else {
            errors++;
            tap.incorrect = YES;
            
            [_trailmakingContentView clearErrors];
            [_trailmakingContentView setError:(int)buttonIndex];
        }
        [taps addObject:tap];
    }
}

- (NSArray*)fetchRandomTest {
    const int testNum = arc4random_uniform((uint32_t)[[self testData] count]);
    const bool invertX = arc4random_uniform(2) == 1;
    const bool invertY = arc4random_uniform(2) == 1;
    const bool reverse = arc4random_uniform(2) == 1;
    
    NSMutableArray* points = [NSMutableArray array];
    NSString* testPointsStr = [self.testData objectAtIndex:testNum];
    NSArray* chunks = [testPointsStr componentsSeparatedByString:@","];
    
    for (int i = 0; i < chunks.count; i += 2) {
        CGPoint pp;
        pp.x = [[chunks objectAtIndex:i + 0] floatValue]/1000;
        pp.y = [[chunks objectAtIndex:i + 1] floatValue]/1000;
        
        if (invertX) pp.x = 1.0f - pp.x;
        if (invertY) pp.y = 1.0f - pp.y;
        
        [points addObject:[NSValue valueWithCGPoint:pp]];
    }
    
    return reverse ? [[points reverseObjectEnumerator] allObjects] : [points copy];
}

- (ORKStepResult *)result {
    ORKStepResult *stepResult = [super result];
    
    // "Now" is the end time of the result, which is either actually now,
    // or the last time we were in the responder chain.
    NSDate *now = stepResult.endDate;
    
    NSMutableArray *results = [NSMutableArray arrayWithArray:stepResult.results];
    
    ORKTrailmakingResult *trailmakingResult = [[ORKTrailmakingResult alloc] initWithIdentifier:self.step.identifier];
    trailmakingResult.startDate = stepResult.startDate;
    trailmakingResult.endDate = now;
    trailmakingResult.taps = [taps copy];
    trailmakingResult.numberOfErrors = errors;
    
    [results addObject:trailmakingResult];
    stepResult.results = [results copy];
    
    return stepResult;
}

#include "ORKTrailmakingStepViewControllerTests.m"

@end
