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
        cx = 70;  // iPhone 6+/7+
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

- (NSArray<NSString*>*)testData {
    static NSArray<NSString*> *testData;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testData = @[
                     @"577.0,449.0,733.9,563.0,792.2,815.3,508.5,875.6,320.0,733.6,308.8,573.0,427.3,367.8,628.8,324.9,555.1,83.98,739.0,123.0,821.9,292.9,926.6,198.5,920.7,369.4,896.0,604.1,939.3,827.0,875.3,937.8,703.3,934.8,406.5,945.3,205.1,876.0,88.07,636.0,118.9,460.7,281.9,259.4,265.2,395.4,411.7,220.7,396.6,77.53",
                     @"280.0,200.0,518.6,259.5,602.9,371.3,540.7,620.6,437.6,687.6,249.9,551.3,193.7,412.2,428.5,553.3,417.5,341.6,138.4,240.0,215.7,57.79,93.98,85.91,56.26,354.2,83.44,612.8,297.4,805.5,127.3,867.4,302.8,934.8,463.4,813.8,562.5,940.7,733.6,829.6,647.8,692.2,810.4,602.1,851.0,346.3,909.6,484.3,858.4,724.9",
                     @"684.0,441.0,748.4,557.3,738.7,837.1,541.7,837.1,567.5,626.7,405.2,753.5,233.8,738.5,238.2,487.6,325.5,371.8,360.7,594.0,463.1,513.9,536.0,313.8,258.3,249.7,453.3,141.6,662.9,201.7,757.2,306.4,869.8,167.3,945.1,374.1,906.5,648.4,796.8,725.2,948.7,893.9,825.6,929.2,633.1,942.7,428.3,906.6,275.8,928.0",
                     @"594.0,679.0,560.5,836.4,322.2,693.3,308.3,534.9,411.3,376.3,612.3,348.1,807.2,494.9,815.4,730.8,743.1,627.6,698.6,793.7,772.8,917.2,916.0,850.4,876.2,599.5,892.9,361.1,817.8,253.8,851.7,106.6,683.3,192.5,727.6,63.91,550.4,174.6,413.9,250.2,333.9,158.2,149.6,324.1,239.5,427.5,168.9,572.2,99.92,702.0",
                     @"138.0,326.0,214.3,592.2,403.1,483.2,464.8,615.5,429.9,813.5,243.1,944.3,50.11,881.5,215.6,747.5,62.21,655.3,114.5,511.5,53.94,226.9,181.0,85.71,351.1,103.5,528.3,246.9,315.8,261.8,470.1,362.0,612.9,419.7,682.3,160.8,740.3,433.7,897.8,391.5,853.6,527.5,678.9,549.0,779.2,636.2,764.3,849.7,630.4,784.4",
                     @"243.0,450.0,355.6,703.0,65.15,764.8,115.7,504.6,73.69,375.3,210.5,302.5,201.7,50.71,383.9,135.6,476.6,390.3,326.2,338.5,471.1,561.6,655.0,568.0,604.0,830.1,488.0,884.2,280.6,858.7,163.8,905.9,363.3,948.3,634.3,948.3,759.5,776.0,867.0,573.8,711.7,423.8,711.7,274.8,914.0,344.4,805.1,155.6,533.2,92.80",
                     @"514.0,358.0,631.3,483.7,631.3,729.7,497.0,827.3,305.5,746.0,237.4,568.7,288.6,435.2,460.6,601.2,453.7,469.4,338.8,278.2,544.8,111.4,753.4,163.5,688.2,364.1,920.3,279.7,909.9,478.4,791.5,624.5,865.5,730.2,804.1,868.1,639.3,859.5,439.3,948.6,230.1,855.5,131.8,757.2,54.38,661.6,56.58,533.6,103.8,388.1",
                     @"131.0,190.0,357.7,380.2,401.4,585.6,237.4,585.6,337.1,700.3,118.7,806.9,293.2,819.1,386.9,906.4,632.6,746.8,899.2,760.8,874.2,582.5,940.6,389.6,795.4,463.6,728.3,297.7,603.8,405.9,403.3,190.9,553.7,204.1,667.0,151.2,860.7,237.5,798.7,120.9,587.3,56.41,314.8,85.14,282.2,216.1,483.7,385.1,538.1,543.0",
                     @"220.0,587.0,369.8,793.2,171.9,877.3,55.25,936.7,235.9,736.1,85.52,698.6,65.43,411.3,255.0,185.3,407.7,411.6,346.2,527.3,551.4,682.0,551.4,844.0,674.7,740.5,782.3,864.2,887.8,695.5,827.4,565.9,579.2,535.4,658.1,358.2,419.8,215.0,376.9,82.85,564.8,151.2,671.5,210.4,779.3,325.9,918.0,434.3,713.2,485.3",
                     @"92.00,260.0,118.9,452.1,240.5,249.8,471.2,204.9,753.5,275.3,943.6,486.4,875.8,722.9,706.8,880.4,514.7,907.4,362.8,738.7,322.3,614.1,404.2,509.3,637.9,521.6,640.3,659.5,471.9,674.3,612.3,796.3,766.3,667.1,777.9,445.4,646.9,346.7,521.1,353.3,295.6,435.4,76.56,619.3,138.3,809.5,201.4,685.6,310.9,854.2",
                     @"725.0,200.0,831.7,277.5,777.6,399.0,650.8,469.3,422.5,497.4,580.8,639.9,599.1,813.9,318.4,754.3,400.6,908.8,188.8,897.7,64.08,763.8,156.9,522.0,365.3,619.2,350.6,339.6,532.3,287.5,408.0,171.6,530.7,138.7,631.8,65.30,415.3,50.18,251.1,169.5,115.7,117.5,118.0,249.5,222.0,317.0,111.3,388.9,248.5,438.9",
                     @"654.0,368.0,778.5,461.8,841.9,656.8,659.1,821.4,514.3,829.0,309.8,674.9,272.0,480.6,345.2,323.8,562.9,203.1,748.5,225.8,715.3,55.09,846.1,73.46,877.2,295.2,923.7,481.5,908.5,771.1,812.7,860.5,608.3,947.2,372.5,939.0,209.2,757.7,94.91,567.4,102.1,429.6,193.7,177.7,356.4,72.13,537.2,81.59,442.4,158.3",
                     @"632.0,212.0,755.3,323.0,664.1,502.1,402.2,511.3,305.7,344.1,424.9,76.49,481.8,204.3,527.7,323.8,610.4,53.26,734.6,111.1,844.5,182.5,874.2,370.1,856.1,577.3,702.1,685.2,839.5,817.8,755.7,925.0,560.9,793.6,515.7,662.2,366.5,801.3,148.5,805.1,86.68,574.2,162.5,418.7,340.6,638.7,250.9,738.3,209.8,595.0",
                     @"640.0,164.0,770.5,277.4,561.9,407.8,345.9,288.1,427.5,167.0,518.8,279.7,515.0,65.78,762.2,96.13,921.9,104.5,893.3,337.7,704.4,533.4,516.4,530.1,659.9,707.3,591.5,868.4,415.1,936.1,330.4,819.6,387.3,607.1,480.6,730.9,434.6,440.5,145.0,496.8,216.6,616.0,190.9,737.3,91.91,619.3,54.19,381.3,177.2,191.7",
                     @"536.0,261.0,634.1,396.1,561.1,650.8,386.0,669.2,229.1,512.2,229.1,275.2,344.7,178.1,134.3,129.6,77.14,305.5,69.84,514.4,151.2,649.8,50.80,886.4,156.2,949.7,365.4,881.7,507.0,925.0,647.6,862.4,728.0,599.4,883.9,593.9,908.2,440.9,781.2,438.6,760.7,243.7,525.9,60.29,351.3,300.5,463.9,449.9,339.6,436.8",
                     @"175.0,466.0,116.8,335.3,135.0,127.1,262.5,116.0,253.9,362.8,497.3,451.4,645.8,708.6,382.7,825.7,331.4,620.0,229.6,702.5,52.93,668.1,175.4,849.7,292.8,920.2,558.3,948.2,757.3,891.1,646.7,839.5,794.6,706.4,726.0,495.3,797.5,348.8,857.7,590.4,936.4,493.2,931.2,196.3,750.5,74.39,639.5,274.6,501.8,294.0",
                     @"226.0,179.0,368.2,382.1,374.9,573.0,487.9,447.4,646.9,450.2,751.0,593.4,773.4,776.0,628.6,768.4,496.9,645.6,399.4,814.5,128.8,828.7,337.0,944.1,482.9,926.2,686.8,947.6,859.8,888.0,944.2,762.8,914.3,478.4,737.1,367.6,722.8,231.4,895.9,357.2,858.1,216.2,613.2,80.46,565.0,307.3,371.3,99.68,397.7,249.3",
                     @"775.0,581.0,779.2,825.9,590.3,845.8,438.8,689.0,468.3,570.6,613.4,503.0,428.2,435.6,350.8,233.9,418.3,82.33,583.7,155.9,655.0,265.8,754.1,79.51,878.1,81.67,894.3,314.1,932.6,586.4,864.3,709.7,948.8,800.4,875.8,926.8,683.9,933.5,436.5,880.9,256.7,674.2,265.2,552.5,147.4,607.4,109.9,457.0,140.1,335.7",
                     @"788.0,235.0,765.9,444.8,625.5,606.3,497.8,588.3,344.5,440.4,323.6,201.3,581.5,132.2,572.4,306.0,461.7,405.7,641.4,457.2,693.5,340.3,698.4,57.36,823.6,113.0,880.3,358.6,809.4,642.9,606.9,801.1,891.8,766.1,925.9,893.6,715.0,864.0,504.7,908.7,338.3,857.8,216.1,695.7,251.7,541.8,91.21,375.6,211.9,270.6",
                     @"483.0,660.0,631.1,863.8,412.9,817.5,213.2,771.3,63.47,586.4,78.75,294.8,224.0,154.5,289.5,294.9,191.3,550.7,303.3,488.7,337.8,707.0,429.0,426.4,614.2,315.2,769.8,342.6,870.3,480.9,849.3,651.7,737.0,584.2,663.6,486.7,561.4,563.8,644.6,742.3,753.3,797.7,902.1,805.5,796.4,936.1,537.7,949.6,413.1,940.9",
                     @"460.0,872.0,293.0,872.0,181.1,693.0,218.7,456.0,336.0,370.7,465.7,361.7,446.1,547.6,634.3,471.6,837.5,593.7,872.4,773.3,710.2,838.9,586.4,821.5,599.2,943.8,815.6,917.2,940.9,878.9,944.8,651.9,842.7,422.7,948.1,174.1,724.5,361.8,801.4,150.4,659.6,143.0,481.3,168.1,412.3,53.29,284.3,181.3,123.1,326.5",
                     @"883.0,816.0,889.6,942.8,616.7,884.8,621.4,615.8,711.2,526.0,818.8,604.2,823.6,465.3,928.5,356.6,827.4,283.2,616.1,347.8,603.3,105.1,537.9,252.2,395.2,298.6,274.2,234.2,122.0,436.3,259.1,594.0,289.7,767.4,139.9,775.2,196.6,931.2,316.0,887.8,456.0,887.8,536.0,749.2,440.9,488.0,326.7,437.1,403.3,704.3",
                     @"727.0,134.0,800.2,266.0,779.1,415.5,548.7,571.0,464.2,424.6,503.9,309.3,626.1,249.7,414.0,101.1,625.3,67.69,843.0,79.09,923.8,300.8,865.0,520.1,722.5,563.6,885.7,700.6,921.2,824.6,643.9,805.2,427.3,616.9,466.9,788.4,572.6,918.9,381.6,918.9,241.0,805.0,221.9,531.7,144.4,386.0,188.9,219.9,339.2,277.6",
                     @"491.0,191.0,568.5,350.0,535.7,583.7,703.9,740.6,673.0,915.9,444.5,730.9,285.7,782.5,114.2,742.9,241.2,522.9,271.3,653.5,438.9,485.9,239.8,272.3,74.45,332.5,161.5,145.8,293.8,100.3,357.4,230.6,463.5,54.06,677.5,246.7,621.4,471.8,771.3,611.6,918.2,606.5,808.0,346.9,800.3,126.1,940.3,368.6,946.6,190.7",
                     @"236.0,714.0,422.0,849.1,280.6,861.5,91.33,878.1,58.04,733.9,157.9,567.6,283.8,531.5,526.1,665.8,566.0,892.3,693.8,734.5,849.3,692.8,757.2,859.0,915.0,822.6,931.6,586.1,721.1,449.4,726.0,308.5,540.0,494.5,317.3,399.9,237.2,297.5,248.4,84.83,466.3,172.8,519.4,336.4,582.4,63.62,725.0,175.0,877.2,332.6",
                     @"771.0,47.00,893.9,174.3,703.6,263.0,592.5,201.5,539.2,81.82,436.2,260.2,301.9,281.5,398.1,100.4,135.2,54.13,79.11,279.2,200.3,355.0,290.3,589.3,99.58,658.7,290.9,769.2,468.1,625.7,468.1,912.7,603.5,831.4,569.9,714.1,686.9,605.0,596.3,523.3,437.8,489.7,511.1,381.1,738.5,492.0,805.2,741.2,871.2,631.5",
                     @"741.0,346.0,828.2,439.6,837.1,694.4,683.5,877.5,407.7,823.9,326.3,688.4,521.4,628.8,470.4,366.7,504.6,247.5,662.2,105.7,939.7,149.6,948.2,392.5,898.0,579.9,902.6,841.8,812.0,946.0,534.4,931.5,297.3,910.8,171.5,743.9,202.7,546.4,375.8,528.1,207.0,312.3,299.1,232.2,266.4,110.5,404.8,150.2,517.0,90.57",
                     @"680.0,323.0,823.3,447.6,836.3,570.9,753.2,673.5,622.7,703.6,502.7,599.3,490.6,368.7,633.4,164.7,885.2,73.07,870.2,287.5,937.6,494.8,842.2,771.9,783.1,878.6,501.6,787.1,602.5,916.3,413.4,949.7,228.6,771.2,184.3,543.4,276.8,429.2,87.09,469.5,125.0,352.5,195.9,219.2,427.5,130.3,318.0,72.16,573.6,58.75",
                     @"342.0,809.0,209.3,827.6,363.2,678.9,535.0,669.9,682.4,812.3,559.6,795.1,643.1,939.7,426.3,947.3,151.3,947.3,160.3,688.4,331.5,469.4,562.9,485.6,640.9,597.0,747.0,320.6,798.7,614.1,808.3,797.8,936.3,746.2,858.2,490.8,885.2,320.9,656.2,172.2,370.7,90.41,367.3,283.3,209.3,367.4,178.7,149.5,113.4,272.2",
                     @"346.0,207.0,532.0,413.5,473.3,618.3,342.2,658.3,177.1,570.6,133.3,417.7,199.2,245.9,251.4,472.0,410.2,491.5,329.2,371.3,214.3,100.6,52.43,106.3,55.98,309.3,52.38,518.2,124.3,753.5,217.8,843.8,355.1,899.2,476.6,845.0,583.8,928.7,676.5,791.1,806.1,591.5,937.8,553.7,673.8,413.4,596.9,223.3,636.4,101.6",
                     @"583.0,186.0,658.1,282.1,633.5,563.0,429.7,695.4,453.0,428.4,229.2,471.9,279.7,296.0,161.2,90.77,316.1,96.18,408.6,206.4,622.5,62.22,745.5,133.2,921.6,95.79,869.8,276.5,832.7,510.5,876.6,736.3,625.4,692.0,552.6,930.2,389.8,832.3,300.3,572.3,228.7,691.4,126.5,592.8,98.78,435.2,147.5,223.8,51.07,313.8",
                     @"571.0,364.0,682.4,442.0,719.7,707.3,533.1,539.4,458.6,692.2,264.6,755.2,311.3,514.7,181.2,581.0,107.4,388.7,220.8,207.2,336.6,132.1,421.5,262.9,257.9,365.2,454.5,432.9,542.9,214.1,804.3,232.3,664.0,87.08,938.9,53.32,943.2,301.2,877.5,436.1,839.5,676.1,689.6,882.4,508.9,911.0,375.5,810.5,597.5,702.2",
                     @"555.0,448.0,579.9,651.4,364.9,859.1,275.0,720.7,302.9,493.5,436.1,389.4,677.1,389.4,849.7,581.1,852.3,727.1,659.2,907.2,724.2,680.3,604.4,773.9,474.5,923.3,237.5,923.3,99.17,883.6,146.8,705.9,172.7,494.5,326.2,283.3,90.47,233.2,272.3,75.15,427.8,151.0,703.7,117.1,858.0,301.0,566.7,321.3,692.7,245.6",
                     @"899.0,582.0,910.8,751.5,769.8,887.7,480.5,907.9,361.2,864.5,212.7,607.3,391.4,668.8,290.0,404.6,427.7,340.4,625.6,416.3,603.9,570.8,443.8,530.9,510.3,762.6,635.3,740.5,776.3,560.1,883.8,294.0,696.1,181.2,723.4,53.07,467.4,57.53,280.2,220.2,151.9,206.7,56.20,320.8,70.84,460.1,157.3,743.1,237.5,923.1",
                     @"656.0,831.0,404.1,870.8,305.4,799.1,500.8,646.4,758.0,696.4,676.7,412.9,778.8,518.6,934.3,749.1,846.3,850.2,928.6,941.6,730.1,927.8,545.1,927.8,290.8,945.6,99.08,811.5,168.6,639.0,286.5,607.4,167.6,352.8,400.3,223.7,473.3,448.2,598.3,222.5,725.3,220.2,889.0,437.4,911.2,297.1,826.7,131.4,681.9,54.51",
                     @"767.0,739.0,861.9,830.6,655.2,882.2,395.8,766.7,269.7,564.8,314.7,384.4,471.1,317.9,559.1,412.3,532.5,601.4,393.3,579.4,541.1,755.5,687.9,511.3,945.5,437.4,879.2,220.3,748.3,227.2,622.2,200.3,564.9,92.67,338.6,64.88,421.6,167.4,191.8,175.5,80.33,376.6,150.7,659.0,100.1,798.1,201.7,869.2,485.3,929.5",
                     @"294.0,272.0,528.8,413.1,639.4,673.6,525.7,941.4,412.5,791.3,466.6,537.0,308.0,617.8,160.9,583.8,352.5,464.1,156.2,274.4,269.4,134.5,459.7,83.59,575.4,145.0,590.6,269.1,720.5,114.4,892.2,93.33,852.6,374.5,772.4,539.0,792.7,249.7,667.7,466.2,770.4,708.3,715.4,859.6,919.0,694.7,945.0,842.4,812.9,949.4",
                     @"561.0,864.0,322.7,893.2,219.5,790.0,234.0,513.3,446.2,370.2,489.5,511.7,568.8,362.5,655.7,629.7,522.4,643.8,712.5,776.8,763.6,925.3,949.2,948.1,853.5,821.1,945.3,690.0,806.6,439.9,871.9,286.1,702.3,274.3,760.4,143.7,546.2,162.4,438.9,100.4,240.7,260.9,378.9,246.3,251.4,383.1,111.5,431.3,65.40,631.0",
                     @"787.0,797.0,662.0,797.0,465.2,613.5,635.4,437.3,774.8,410.2,945.9,581.3,818.8,613.0,698.7,647.4,932.2,727.8,832.2,915.9,637.3,922.7,537.0,838.5,278.6,820.4,194.6,674.9,342.9,428.1,514.0,379.0,332.0,260.8,140.4,452.5,129.8,249.7,405.2,138.5,678.1,196.5,606.1,71.82,885.6,116.0,879.0,304.9,943.9,437.9",
                     @"184.0,906.0,147.1,732.8,221.3,504.6,482.4,472.5,739.2,581.5,790.5,787.2,560.8,742.6,432.8,623.2,388.7,814.2,311.3,631.9,265.8,801.9,307.5,916.6,456.5,916.6,609.5,881.3,889.7,920.7,932.9,759.4,869.3,483.6,652.5,308.0,630.1,181.0,489.0,112.1,434.6,223.6,279.9,358.1,70.31,521.8,118.0,315.3,217.6,208.5",
                     @"202.0,178.0,434.9,335.1,449.1,470.3,371.1,630.3,161.0,589.5,153.8,450.7,317.7,447.8,243.7,345.9,124.5,274.3,90.78,61.00,366.6,51.37,511.5,56.43,643.9,159.8,673.2,368.8,845.6,224.1,937.5,333.7,910.6,503.6,717.5,683.6,747.9,527.5,632.4,591.5,596.8,758.8,353.6,929.1,135.4,739.5,319.9,789.0,478.0,718.6",
                     @"526.0,433.0,612.7,536.4,600.2,679.8,466.5,747.9,357.5,592.3,392.4,452.6,236.6,471.7,88.60,313.0,215.5,117.6,376.1,68.50,555.0,223.9,433.2,252.1,294.1,214.8,337.1,339.6,635.9,350.0,851.6,249.4,768.1,413.3,934.0,445.5,875.4,615.7,748.3,772.7,938.4,806.2,701.1,943.3,471.4,898.7,298.3,845.8,166.6,769.8",
                     @"437.0,506.0,505.0,651.9,455.1,886.6,325.6,898.0,138.4,833.5,52.86,706.6,185.2,467.9,270.8,573.6,258.3,716.0,377.1,747.9,321.2,460.2,255.7,319.8,316.2,143.9,516.0,278.7,522.9,409.5,725.7,245.2,910.3,258.1,861.2,418.8,700.4,471.0,773.9,575.8,938.4,632.5,775.2,708.6,815.6,840.5,580.6,836.4,629.5,606.6",
                     @"400.0,329.0,541.2,404.1,624.1,573.9,583.8,802.4,439.7,936.8,407.8,710.0,526.5,652.1,356.1,561.5,306.6,417.8,234.3,707.9,80.63,828.0,61.87,559.6,207.2,344.1,82.28,389.6,66.79,168.1,227.7,170.9,351.3,181.7,537.4,138.8,671.2,212.9,754.9,470.7,875.0,354.7,938.1,496.3,841.6,670.3,712.5,869.1,705.4,733.3",
                     @"560.0,858.0,422.2,922.2,290.4,915.3,88.18,713.0,149.4,581.6,220.0,464.2,337.8,414.2,560.5,495.2,628.9,683.2,446.3,623.9,301.1,774.2,467.0,780.0,734.0,747.2,748.6,885.4,920.4,673.3,757.9,457.7,771.2,267.1,938.1,496.9,919.8,322.8,789.2,55.04,530.2,100.7,676.4,165.7,520.3,358.5,414.9,295.1,221.1,114.4",
                     @"751.0,589.0,899.6,713.7,726.3,899.4,594.0,757.5,577.2,620.6,417.1,580.6,213.5,377.0,441.3,255.9,595.2,341.2,649.6,519.1,836.6,397.6,707.4,206.1,809.4,132.0,547.3,71.58,324.3,75.47,227.4,151.2,126.2,236.0,85.65,399.0,73.10,542.5,142.3,769.1,265.3,764.8,213.1,519.3,396.2,702.4,387.9,941.3,532.5,882.9",
                     @"477.0,314.0,662.2,448.6,726.0,614.7,704.3,737.8,554.9,724.8,325.8,532.6,293.6,381.0,376.9,202.4,579.7,166.6,684.1,242.5,711.4,102.1,873.9,151.8,863.9,440.6,931.9,586.5,909.7,797.4,810.2,944.9,678.3,940.3,569.3,864.0,323.7,838.2,214.1,681.8,164.4,834.9,56.16,566.9,142.5,404.5,104.5,287.5,247.7,183.5",
                     @"778.0,791.0,576.2,780.4,444.4,577.4,497.1,405.3,640.3,428.0,756.5,529.0,800.4,401.4,942.7,577.0,937.2,732.9,871.9,912.4,634.2,924.8,450.0,898.9,263.2,698.6,362.4,440.0,113.9,589.3,186.7,425.8,111.5,310.1,321.3,127.7,592.2,75.05,732.9,188.9,877.5,105.4,880.3,265.4,593.7,250.4,408.7,269.8,236.0,303.4",
                     @"416.0,159.0,621.8,344.3,571.0,605.4,457.8,552.6,397.9,293.4,334.3,468.2,134.5,333.4,237.4,234.1,133.0,67.06,315.7,57.49,508.0,74.31,767.6,212.3,879.3,422.4,821.4,590.7,689.6,491.4,790.5,768.6,653.1,800.4,474.6,883.6,312.6,786.3,220.3,659.3,203.5,850.5,347.3,920.7,78.39,920.7,96.00,719.4,134.2,539.4",
                     @"461.0,261.0,637.9,409.4,642.4,669.4,558.1,773.5,401.3,765.3,365.6,510.8,525.5,508.0,462.5,398.9,298.1,325.7,109.0,409.9,184.8,145.5,65.34,265.0,85.62,72.15,338.6,50.02,575.3,215.7,711.3,105.6,858.5,281.0,826.2,544.1,714.4,292.8,700.7,554.5,789.4,763.4,646.8,863.2,418.6,937.4,257.1,875.4,268.9,649.7",
                     @"784.0,405.0,849.9,514.7,772.3,654.6,517.0,708.9,251.0,596.0,246.8,359.0,451.5,296.4,226.9,161.5,101.7,214.6,73.50,347.6,155.7,445.7,130.7,683.4,237.9,767.1,115.8,912.7,305.9,946.2,414.6,861.2,623.7,901.9,855.8,865.1,715.9,787.5,943.2,676.6,948.1,401.7,711.4,275.8,637.1,116.3,637.0,372.3,501.0,499.2",
                     @"644.0,603.0,845.4,797.5,590.4,797.5,346.8,916.3,218.5,902.8,132.5,759.6,189.7,583.7,328.9,489.7,398.8,704.7,507.8,543.0,783.7,509.1,934.7,603.5,879.8,398.7,667.9,368.9,606.1,215.9,824.0,223.5,606.3,65.45,464.2,207.5,330.8,69.46,233.6,170.1,92.80,195.0,319.0,286.4,426.5,393.8,249.5,390.8,91.82,485.5",
                     @"41.00,362.0,215.9,578.0,222.3,700.8,95.53,836.9,318.3,793.5,445.6,940.0,490.4,772.9,632.4,734.8,618.4,934.3,816.9,920.4,732.0,811.7,755.0,624.1,930.5,713.5,875.6,475.8,923.9,307.6,657.3,379.0,503.6,297.3,586.7,141.0,329.9,244.8,343.4,90.43,128.3,209.7,176.8,368.4,394.8,447.8,400.0,596.7,511.8,512.4",
                     @"371.0,711.0,484.1,861.1,528.7,705.4,673.3,644.0,894.8,823.4,825.2,939.1,692.3,831.5,626.4,941.2,375.4,936.8,232.0,807.7,249.4,642.6,450.5,455.0,529.9,564.3,723.1,418.6,852.6,490.4,798.3,618.3,923.5,591.7,949.3,407.5,852.3,291.9,610.1,321.6,396.5,166.4,506.0,71.32,658.8,136.1,848.5,95.86,742.6,236.4",
                     @"675.0,365.0,811.6,539.9,754.6,674.3,482.9,784.0,319.2,746.2,383.2,630.8,615.9,606.3,476.7,512.4,452.6,360.3,356.8,440.6,182.5,409.9,68.86,166.1,320.4,192.6,462.3,140.9,536.5,259.6,618.1,169.0,800.1,169.0,898.9,291.0,862.7,426.2,899.3,686.7,675.5,837.6,458.6,908.1,209.7,903.8,65.74,698.2,131.6,588.4",
                     @"210.0,351.0,347.5,462.3,350.2,614.3,167.4,790.8,439.3,781.3,555.5,553.2,735.3,494.8,927.2,572.3,947.2,698.7,742.0,738.6,883.7,810.8,670.3,860.1,597.7,739.2,469.6,915.6,332.9,934.8,200.9,934.8,63.66,913.0,109.8,675.5,91.52,414.1,98.83,274.3,242.8,153.5,393.6,161.3,569.4,279.9,629.9,403.9,712.7,234.0",
                     @"296.0,240.0,444.2,410.5,444.2,645.5,335.3,721.8,201.8,624.8,309.8,437.8,59.65,370.7,107.5,178.6,367.7,118.5,542.6,236.5,560.8,496.9,638.9,356.1,849.4,303.6,860.6,463.2,717.7,667.2,939.7,568.3,901.0,767.6,791.0,847.5,537.9,802.9,425.2,947.1,242.2,947.1,95.69,832.6,80.62,545.0,185.5,750.8,316.5,849.5",
                     @"327.0,46.00,497.5,148.4,385.6,210.5,93.02,195.2,217.5,394.5,493.5,394.5,699.6,549.7,532.0,780.3,391.1,681.6,357.6,491.6,179.8,607.0,249.1,778.6,117.6,848.5,324.3,949.3,383.5,822.5,555.7,902.8,755.7,680.6,726.7,829.8,884.1,711.2,844.6,582.1,911.6,407.5,701.7,231.4,713.3,363.9,601.4,301.8,650.8,117.4",
                     @"805.0,264.0,832.0,521.5,697.2,786.2,507.2,870.8,371.2,841.9,248.1,652.3,273.2,365.4,391.4,276.3,521.1,285.4,562.1,517.8,417.9,551.1,480.9,660.2,697.3,606.3,660.8,399.5,605.4,177.3,665.5,68.88,869.0,54.65,917.0,211.4,897.3,351.1,948.6,466.2,912.3,652.7,902.2,798.3,949.8,910.6,802.7,876.7,632.4,891.6",
                     @"597.0,685.0,734.8,838.0,487.1,752.7,465.2,628.7,594.5,363.5,867.1,406.7,777.0,576.2,635.3,540.9,835.3,734.0,911.8,898.0,911.8,636.0,944.4,514.3,909.1,292.1,881.2,116.3,691.0,133.0,770.5,303.4,596.1,233.0,511.8,128.9,384.8,131.2,395.1,424.0,227.8,597.4,237.5,409.7,81.72,482.4,250.7,257.9,98.52,329.0",
                     @"900.0,609.0,884.0,837.4,620.7,731.0,531.7,599.2,661.9,398.7,833.2,374.7,742.2,589.1,927.3,459.5,919.8,244.7,758.0,224.8,927.4,97.25,761.0,73.86,608.4,84.53,542.0,266.8,300.2,384.7,166.6,346.4,363.9,258.5,242.7,214.4,295.5,83.72,103.0,218.5,103.1,456.5,195.3,583.5,397.2,771.7,407.3,916.4,572.7,930.8",
                     @"285.0,189.0,472.3,376.3,437.5,660.2,344.0,581.8,344.0,393.8,180.6,331.1,53.57,81.63,182.6,109.0,419.7,129.8,699.5,184.2,813.3,298.0,778.1,497.9,670.1,413.6,607.9,553.3,880.5,596.5,775.2,694.7,610.4,674.5,590.4,837.3,444.8,847.5,246.4,681.0,236.6,493.2,124.2,566.2,218.2,798.9,248.7,921.2,76.87,948.4",
                     @"562.0,242.0,397.0,241.9,479.7,114.5,598.9,80.34,849.7,243.1,747.9,334.8,869.2,394.0,893.6,567.3,771.9,734.8,518.5,822.0,370.8,753.1,246.8,509.9,510.2,472.9,385.1,593.7,633.5,611.1,661.0,469.7,469.3,350.0,307.2,332.9,166.6,79.34,50.84,222.3,59.43,386.1,162.0,303.0,86.61,535.1,211.1,734.3,177.0,894.8",
                     @"790.0,123.0,549.1,240.4,365.0,162.3,323.2,299.0,185.1,369.4,115.7,110.5,237.4,183.7,248.4,58.20,539.7,78.57,676.2,66.63,905.0,58.62,890.0,274.1,641.5,326.9,737.9,533.5,655.5,748.2,381.3,842.7,343.2,710.0,465.1,460.1,465.1,684.1,594.8,636.9,609.7,465.6,449.0,340.0,308.6,519.7,138.4,483.5,194.9,668.1",
                     @"697.0,875.0,518.7,843.5,405.6,708.7,669.6,612.6,830.5,691.1,810.0,925.2,946.9,920.4,910.3,792.5,898.6,569.8,755.8,427.0,760.2,300.1,915.1,281.1,855.9,118.5,681.0,192.7,632.1,334.6,591.8,485.2,436.4,471.6,268.5,340.5,478.2,204.4,522.0,84.12,367.8,114.0,268.3,186.3,138.5,365.1,72.21,537.9,190.0,485.4",
                     @"798.0,210.0,728.0,413.2,482.9,538.1,323.5,442.3,287.0,212.2,416.8,162.3,629.9,306.1,659.5,95.17,904.1,147.1,874.3,359.0,844.5,512.2,727.2,607.2,915.2,759.5,830.3,868.2,598.4,926.0,409.6,885.9,506.1,795.9,274.7,779.7,99.15,562.9,65.02,285.0,171.7,120.6,171.7,403.6,241.2,594.4,378.1,599.1,605.1,660.0",
                     @"605.0,738.0,802.4,881.4,709.7,626.7,743.9,478.6,876.3,690.6,948.6,511.7,936.7,375.2,835.0,235.2,760.8,354.0,583.9,408.1,490.3,323.7,594.1,195.5,411.6,106.5,138.0,174.7,314.8,222.1,394.0,428.4,178.8,474.2,264.8,617.3,185.1,805.1,151.7,680.5,58.30,602.1,82.08,874.0,264.2,899.6,391.1,853.5,524.0,894.1",
                     @"360.0,358.0,546.2,588.0,519.5,739.6,242.6,705.6,412.7,833.8,285.9,904.1,97.93,907.4,87.60,611.6,209.3,579.0,370.9,628.4,206.6,425.6,208.8,301.6,68.72,396.1,114.0,109.6,237.3,78.97,359.0,55.31,514.5,234.1,496.2,60.13,621.4,113.2,748.9,374.8,724.7,651.7,813.6,519.9,918.1,700.9,729.1,828.4,547.5,877.1",
                     @"277.0,612.0,479.8,776.2,335.6,901.5,162.9,892.5,338.4,764.9,200.6,757.7,76.89,650.1,233.8,449.1,391.0,432.6,569.4,531.5,667.9,742.7,815.3,664.3,873.2,545.7,701.2,591.7,666.7,414.1,754.2,323.4,884.2,323.4,794.4,121.5,576.9,218.3,432.3,168.5,354.9,292.3,218.1,181.6,106.4,335.3,151.9,77.31,284.4,65.72",
                     @"432.0,650.0,565.6,783.6,421.5,917.9,242.6,911.7,138.2,841.2,154.6,654.0,263.8,574.6,96.46,523.4,94.10,388.5,263.1,343.2,423.3,411.2,304.5,167.6,563.1,181.1,626.9,347.3,496.2,291.8,582.7,574.9,813.2,504.4,856.7,666.7,808.8,798.3,699.1,851.7,680.6,675.7,599.7,940.6,860.6,945.1,928.0,823.6,927.9,564.6",
                     @"612.0,368.0,633.1,518.5,553.3,651.3,368.2,478.8,376.3,247.9,568.7,141.3,776.0,220.8,898.9,310.2,792.7,473.7,929.7,473.7,923.2,661.6,734.0,688.2,781.2,877.4,646.8,828.5,512.9,830.8,289.8,691.4,361.6,888.8,133.2,904.8,191.9,778.8,58.39,607.8,200.9,544.3,200.9,369.3,210.6,89.55,402.0,52.34,684.5,82.01",
                     @"606.0,227.0,728.0,367.3,681.6,630.3,458.0,516.3,419.7,398.4,211.0,599.8,80.41,590.7,137.7,320.7,275.8,237.8,87.33,55.85,347.5,111.1,513.8,146.5,718.7,175.3,919.7,300.9,875.3,529.6,870.3,670.5,785.1,768.6,639.3,761.0,546.7,650.6,467.5,857.0,250.3,949.2,175.1,841.9,298.5,767.7,65.87,743.2,327.3,637.5",
                     @"507.0,163.0,733.4,310.0,750.3,503.3,636.8,671.6,468.3,743.1,254.6,609.5,382.6,387.8,493.2,587.2,618.3,448.3,496.8,298.3,271.4,282.5,163.0,203.7,304.7,125.2,190.5,76.80,68.48,111.8,106.7,384.1,103.3,579.1,308.6,757.5,146.9,810.0,425.6,900.6,576.0,913.7,695.5,813.5,803.5,729.1,904.2,631.9,889.8,426.4",
                     @"449.0,887.0,294.4,919.8,351.3,673.3,450.1,590.4,569.8,641.2,673.9,875.0,841.8,743.9,680.5,537.4,720.9,375.4,942.0,267.6,734.5,204.1,579.3,301.1,361.4,270.5,233.2,100.4,146.3,352.8,98.58,82.03,52.07,209.8,85.33,480.8,330.4,410.5,198.7,579.1,101.3,741.1,186.8,843.0,219.6,700.7,332.6,533.3,511.4,482.0",
                     @"716.0,712.0,816.5,845.3,637.8,810.6,583.1,631.8,307.9,748.6,158.7,703.0,181.5,517.4,344.3,415.6,476.7,451.1,597.6,386.8,785.5,393.3,869.9,592.2,722.5,544.3,919.9,763.5,924.8,904.4,697.7,940.4,540.0,929.4,406.1,931.8,116.9,891.3,54.74,622.4,74.09,400.2,248.9,325.9,453.2,141.8,630.2,144.8,727.7,284.0",
                     @"586.0,343.0,731.6,420.4,803.2,526.5,784.0,663.2,678.3,737.2,394.3,650.3,449.0,471.5,282.7,571.4,71.26,586.2,115.3,471.4,244.0,411.4,133.9,305.1,92.63,160.9,266.4,188.4,414.6,217.3,359.1,362.0,610.2,217.0,770.2,214.2,912.8,367.0,900.6,599.7,796.6,870.4,641.5,900.6,438.8,838.6,226.4,887.6,146.7,773.8",
                     @"875.0,343.0,868.2,471.8,684.5,610.2,671.7,463.7,754.1,287.0,938.5,223.5,733.2,136.4,612.2,296.9,412.5,307.4,257.7,129.3,470.7,170.7,548.6,50.80,403.7,55.86,104.7,55.88,124.6,181.3,219.9,405.9,195.9,601.4,464.6,558.8,595.0,794.1,425.5,946.7,373.3,720.6,299.9,893.7,240.3,720.6,71.77,708.8,68.84,540.9",
                     @"295.0,774.0,405.8,854.5,273.5,937.1,140.3,853.9,135.7,587.0,313.5,402.8,563.5,402.8,590.6,542.2,468.5,687.8,701.2,655.1,810.8,743.8,686.3,864.0,866.6,879.8,943.2,741.6,927.6,592.4,729.1,413.7,726.1,237.8,600.8,276.1,395.1,166.7,445.9,314.2,276.4,204.2,79.49,358.1,136.9,200.2,313.1,52.40,490.1,55.49",
                     @"390.0,354.0,482.1,436.9,497.3,581.1,310.8,524.1,358.4,748.1,257.6,903.3,138.0,819.5,179.8,555.8,235.4,348.1,107.5,455.5,130.6,191.5,324.8,139.5,539.4,235.1,695.8,485.2,624.4,638.4,806.6,871.6,783.0,722.5,901.8,690.7,862.7,412.4,825.6,573.2,763.2,303.3,686.1,79.23,798.0,141.2,940.3,316.9,944.1,538.8",
                     @"392.0,198.0,537.8,289.1,618.5,553.0,516.6,744.6,316.0,809.8,146.6,682.3,90.56,418.2,177.8,302.4,322.3,462.9,465.2,480.4,413.6,346.0,251.1,177.7,119.1,180.0,182.2,56.16,463.8,70.91,707.6,235.3,727.7,362.7,857.8,118.1,878.1,283.8,831.5,427.5,834.5,599.4,686.6,836.0,511.8,910.3,664.3,692.4,739.2,507.0",
                     @"323.0,132.0,446.3,243.0,668.6,215.7,839.4,330.9,848.5,590.8,639.7,778.8,491.0,649.5,572.2,549.3,628.4,376.2,345.8,457.2,115.0,339.7,149.9,479.4,358.3,636.5,253.1,826.2,65.80,618.2,113.0,822.8,67.53,941.3,199.3,948.3,364.7,933.8,400.0,767.5,593.3,913.1,755.5,847.6,876.1,935.2,916.0,812.5,823.9,732.4",
                     @"204.0,548.0,329.3,692.1,148.6,780.2,90.75,656.0,96.68,486.2,355.3,348.6,502.5,382.6,523.4,581.5,372.0,814.6,125.3,924.4,305.3,924.4,463.3,927.2,632.7,897.3,655.8,708.7,829.8,711.8,801.7,579.7,874.5,326.0,655.3,345.1,509.5,254.0,627.2,206.4,392.5,106.8,238.4,272.1,221.7,136.1,107.8,215.8,130.9,51.46",
                     @"663.0,534.0,761.8,622.9,768.7,819.8,528.8,681.3,498.1,487.7,637.8,315.2,731.3,393.6,863.8,133.5,932.0,356.3,856.3,518.5,910.2,771.8,850.0,928.7,594.5,892.8,428.7,901.5,282.6,943.3,153.8,729.0,149.9,501.1,263.6,365.5,332.5,489.7,295.7,698.5,402.8,605.3,426.7,332.4,320.7,148.8,445.9,180.0,546.7,109.4"
                     ];
    });
  return testData;
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

@end
