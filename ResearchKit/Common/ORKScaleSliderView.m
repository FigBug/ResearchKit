/*
 Copyright (c) 2015, Apple Inc. All rights reserved.
 Copyright (c) 2015, Ricardo Sánchez-Sáez.
 Copyright (c) 2015, Bruce Duncan.

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


#import "ORKScaleSliderView.h"

#import "ORKScaleRangeDescriptionLabel.h"
#import "ORKScaleRangeImageView.h"
#import "ORKScaleRangeLabel.h"
#import "ORKScaleSlider.h"
#import "ORKScaleValueLabel.h"

#import "ORKAnswerFormat_Internal.h"

#import "ORKSkin.h"


// #define LAYOUT_DEBUG 1

@implementation ORKScaleSliderView {
    id<ORKScaleAnswerFormatProvider> _formatProvider;
    ORKScaleSlider *_slider;
    ORKScaleRangeDescriptionLabel *_leftRangeDescriptionLabel;
    ORKScaleRangeDescriptionLabel *_rightRangeDescriptionLabel;
    ORKScaleRangeDescriptionLabel *_middleRangeDescriptionLabel;
    NSMutableArray<UIView *> *_RangeLabels; //smallest to largest, left to right, bottom to top
    ORKScaleValueLabel *_valueLabel;
    NSMutableArray<ORKScaleRangeLabel *> *_textChoiceLabels;
    NSNumber *_currentNumberValue;
}

- (instancetype)initWithFormatProvider:(id<ORKScaleAnswerFormatProvider>)formatProvider
                              delegate:(id<ORKScaleSliderViewDelegate>)delegate {
    self = [self initWithFrame:CGRectZero];
    if (self) {
        _formatProvider = formatProvider;
        _delegate = delegate;
        
        _slider = [[ORKScaleSlider alloc] initWithFrame:CGRectZero];
        _slider.userInteractionEnabled = YES;
        _slider.contentMode = UIViewContentModeRedraw;
        [self addSubview:_slider];
        
        _slider.maximumValue = [formatProvider maximumNumber].floatValue;
        _slider.minimumValue = [formatProvider minimumNumber].floatValue;
        
        NSInteger numberOfSteps = [formatProvider numberOfSteps];
        if ([formatProvider respondsToSelector:@selector(continuous)] && formatProvider.continuous) {
            _slider.numberOfSteps = 0;
        } else {
            _slider.numberOfSteps = numberOfSteps;
        }
        
        [_slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];

        BOOL isVertical = [formatProvider isVertical];
        _slider.vertical = isVertical;

        NSArray<ORKTextChoice *> *textChoices = [[self textScaleFormatProvider] textChoices];
        _slider.textChoices = textChoices;
        
        _slider.gradientColors = [formatProvider gradientColors];
        _slider.gradientLocations = [formatProvider gradientLocations];
        
        if (isVertical && textChoices) {
            // Generate an array of labels for all the text choices
            _textChoiceLabels = [NSMutableArray new];
            for (int i = 0; i <= numberOfSteps; i++) {
                ORKTextChoice *textChoice = textChoices[i];
                ORKScaleRangeLabel *stepLabel = [[ORKScaleRangeLabel alloc] initWithFrame:CGRectZero];
                stepLabel.text = textChoice.text;
                stepLabel.textAlignment = NSTextAlignmentLeft;
                stepLabel.numberOfLines = 0;
                stepLabel.translatesAutoresizingMaskIntoConstraints = NO;
                [self addSubview:stepLabel];
                [_textChoiceLabels addObject:stepLabel];
            }
        } else {
            _valueLabel = [[ORKScaleValueLabel alloc] initWithFrame:CGRectZero];
            _valueLabel.textAlignment = NSTextAlignmentCenter;
            _valueLabel.text = @" ";
            [self addSubview:_valueLabel];
            
            _RangeLabels = [NSMutableArray new];
            for(float i = [formatProvider minimumNumber].floatValue; i <= [formatProvider maximumNumber].floatValue; i+=0.25*([formatProvider maximumNumber].floatValue-[formatProvider minimumNumber].floatValue)) {
                UIView *range;
                if(i == [formatProvider minimumNumber].floatValue && [formatProvider minimumImage]) {
                    range = [[ORKScaleRangeImageView alloc] initWithImage:[formatProvider minimumImage]];
                } else if (i == [formatProvider maximumNumber].floatValue && [formatProvider maximumImage]) {
                    range = [[ORKScaleRangeImageView alloc] initWithImage:[formatProvider maximumImage]];
                } else {
                    ORKScaleRangeLabel *rangeTemp = [[ORKScaleRangeLabel alloc] initWithFrame:CGRectZero];
                    rangeTemp.text = [NSString stringWithFormat:@"%1.0f", i];
                    rangeTemp.textAlignment = NSTextAlignmentCenter;
                    if (isVertical && i != [formatProvider minimumNumber].floatValue && i != [formatProvider maximumNumber].floatValue){ rangeTemp.textColor = [UIColor whiteColor];}//hide middle labels on horizontal scales. TODO:this hack makes everything workout in this specific instance. If we don't want any changes, then I can implement this properly.
                    range = rangeTemp;
                }
                range.translatesAutoresizingMaskIntoConstraints = NO;
                [self addSubview:range];
                [_RangeLabels addObject:range];
            }
            
            _leftRangeDescriptionLabel = [[ORKScaleRangeDescriptionLabel alloc] initWithFrame:CGRectZero];
            _leftRangeDescriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
            _leftRangeDescriptionLabel.numberOfLines = 0;
            [self addSubview:_leftRangeDescriptionLabel];
            
            _rightRangeDescriptionLabel = [[ORKScaleRangeDescriptionLabel alloc] initWithFrame:CGRectZero];
            _rightRangeDescriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
            _rightRangeDescriptionLabel.numberOfLines = 0;
            [self addSubview:_rightRangeDescriptionLabel];
            
            _middleRangeDescriptionLabel = [[ORKScaleRangeDescriptionLabel alloc] initWithFrame:CGRectZero];
            _middleRangeDescriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
            _middleRangeDescriptionLabel.numberOfLines = 0;
            [self addSubview:_middleRangeDescriptionLabel];
            
            if (textChoices) {
                _leftRangeDescriptionLabel.textColor = [UIColor blackColor];
                _rightRangeDescriptionLabel.textColor = [UIColor blackColor];
                _middleRangeDescriptionLabel.textColor = [UIColor blackColor];
            }

#if LAYOUT_DEBUG
            self.backgroundColor = [UIColor greenColor];
            _valueLabel.backgroundColor = [UIColor blueColor];
            _slider.backgroundColor = [UIColor redColor];
            _leftRangeDescriptionLabel.backgroundColor = [UIColor yellowColor];
            _rightRangeDescriptionLabel.backgroundColor = [UIColor yellowColor];
            _middleRangeDescriptionLabel.backgroundColor = [UIColor yellowColor];
#endif
        
            if (isVertical) {
                _leftRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
                _rightRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
                _middleRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
            } else {
                _leftRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
                _rightRangeDescriptionLabel.textAlignment = NSTextAlignmentRight;
                _middleRangeDescriptionLabel.textAlignment = NSTextAlignmentCenter;
            }
            
            _leftRangeDescriptionLabel.text = [formatProvider minimumValueDescription];
            _rightRangeDescriptionLabel.text = [formatProvider maximumValueDescription];
            _middleRangeDescriptionLabel.text = [formatProvider middleValueDescription];

            _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
            _leftRangeDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
            _rightRangeDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
            _middleRangeDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        }
        
        self.translatesAutoresizingMaskIntoConstraints = NO;
        _slider.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self setUpConstraints];
    }
    return self;
}

- (void)setUpConstraints {
    BOOL isVertical = [_formatProvider isVertical];
    NSArray<ORKTextChoice *> *textChoices = _slider.textChoices;
    NSDictionary *views = nil;
    if (isVertical && textChoices) {
        views = NSDictionaryOfVariableBindings(_slider);
    } else {
        id objects[] = { _slider, [_RangeLabels firstObject], [_RangeLabels lastObject], _valueLabel, _leftRangeDescriptionLabel, _middleRangeDescriptionLabel, _rightRangeDescriptionLabel };
        id keys[] = { @"_slider", @"_leftRangeView", @"_rightRangeView", @"_valueLabel", @"_leftRangeDescriptionLabel", @"_middleRangeDescriptionLabel", @"_rightRangeDescriptionLabel" };
        NSUInteger count = sizeof(objects) / sizeof(id);
        views = [NSDictionary dictionaryWithObjects:objects
                                            forKeys:keys
                                              count:count];
    }
    
    NSMutableArray *constraints = [NSMutableArray new];
    if (isVertical) {
        _leftRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
        _rightRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
        _middleRangeDescriptionLabel.textAlignment = NSTextAlignmentLeft;
        
        // Vertical slider constraints
        // Keep the thumb the same distance from the value label as in horizontal mode
        const CGFloat ValueLabelSliderMargin = 23.0;
        // Keep the shadow of the thumb inside the bounds
        const CGFloat SliderMargin = 20.0;
        const CGFloat SideLabelMargin = 24;//width of slider
        
        if (textChoices) {
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_slider
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1.0
                                                                 constant:0.0]];

            [constraints addObject:[NSLayoutConstraint constraintWithItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                                relatedBy:NSLayoutRelationLessThanOrEqual
                                                                   toItem:self
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:0.25
                                                                 constant:0.0]];

            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-kSliderMargin-[_slider]-kSliderMargin-|"
                                                     options:NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:@{@"kSliderMargin": @(SliderMargin)}
                                                       views:views]];
            
            
            for (int i = 0; i < _textChoiceLabels.count; i++) {
                // Put labels to the right side of the slider.
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i]
                                                                 attribute:NSLayoutAttributeLeading
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_slider
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1.0
                                                                  constant:SideLabelMargin]];
                
                if (i == 0) {
                    // First label
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i]
                                                                        attribute:NSLayoutAttributeCenterY
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:_slider
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0
                                                                         constant:0.0]];
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i]
                                                                        attribute:NSLayoutAttributeWidth
                                                                        relatedBy:NSLayoutRelationLessThanOrEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeWidth
                                                                       multiplier:0.75
                                                                         constant:0]];
                    
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i]
                                                                        attribute:NSLayoutAttributeTrailing
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeTrailing
                                                                       multiplier:1.0
                                                                         constant:-SideLabelMargin]];

                } else {
                    // Middle labels
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i - 1]
                                                                        attribute:NSLayoutAttributeTop
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:_textChoiceLabels[i]
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0
                                                                         constant:0.0]];
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i - 1]
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:_textChoiceLabels[i]
                                                                        attribute:NSLayoutAttributeHeight
                                                                       multiplier:1.0
                                                                         constant:0.0]];
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i - 1]
                                                                        attribute:NSLayoutAttributeWidth
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:_textChoiceLabels[i]
                                                                        attribute:NSLayoutAttributeWidth
                                                                       multiplier:1.0
                                                                         constant:0.0]];
                    
                    // Last label
                    if (i == (_textChoiceLabels.count - 1)) {
                        [constraints addObject:[NSLayoutConstraint constraintWithItem:_textChoiceLabels[i]
                                                                            attribute:NSLayoutAttributeCenterY
                                                                            relatedBy:NSLayoutRelationEqual
                                                                               toItem:_slider
                                                                            attribute:NSLayoutAttributeTop
                                                                           multiplier:1.0
                                                                             constant:0.0]];
                    }
                }
            }
        } else {
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self
                                                                attribute:NSLayoutAttributeRight
                                                               multiplier:0.15
                                                                 constant:0.0]];
            
            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_valueLabel]-(>=kValueLabelSliderMargin)-[_slider]-(>=kSliderMargin)-|"
                                                     options:NSLayoutFormatAlignAllCenterX | NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:@{@"kValueLabelSliderMargin": @(ValueLabelSliderMargin), @"kSliderMargin": @(SliderMargin)}
                                                       views:views]];
            
            [constraints addObjectsFromArray
             :[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_rightRangeView(==_leftRangeView)]"
                                                      options:(NSLayoutFormatOptions)0
                                                      metrics:nil
                                                        views:views]];
            
            // Set the margin between slider and the rangeViews
            [constraints addObject:[NSLayoutConstraint constraintWithItem:[_RangeLabels lastObject]
                                                                attribute:NSLayoutAttributeRight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1.0
                                                                 constant:-SideLabelMargin]];
            
            [constraints addObject:[NSLayoutConstraint constraintWithItem:[_RangeLabels firstObject]
                                                                attribute:NSLayoutAttributeRight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1.0
                                                                 constant:-SideLabelMargin]];
            
            // Align the rangeViews with the slider's bottom
            [constraints addObject:[NSLayoutConstraint constraintWithItem:[_RangeLabels lastObject]
                                                                attribute:NSLayoutAttributeTop
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeTop
                                                               multiplier:1.0
                                                                 constant:0.0]];
            
            [constraints addObject:[NSLayoutConstraint constraintWithItem:[_RangeLabels firstObject]
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1.0
                                                                 constant:0.0]];
            
            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"H:[_rightRangeDescriptionLabel]-(>=8)-|"
                                                     options:NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:nil
                                                       views:views]];
            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"H:[_leftRangeDescriptionLabel(==_rightRangeDescriptionLabel)]-(>=8)-|"
                                                     options:NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:nil
                                                       views:views]];
            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"H:[_middleRangeDescriptionLabel(==_rightRangeDescriptionLabel)]-(>=8)-|"
                                                     options:NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:nil
                                                       views:views]];
            
            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_rightRangeDescriptionLabel]-(>=8)-[_middleRangeDescriptionLabel]-(>=8)-[_leftRangeDescriptionLabel]-(>=8)-|"
                                                     options:NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:nil
                                                       views:views]];
            
            // Set the margin between the slider and the descriptionLabels
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_rightRangeDescriptionLabel
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1.0
                                                                 constant:SideLabelMargin]];
            
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_leftRangeDescriptionLabel
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1.0
                                                                 constant:SideLabelMargin]];
            
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_middleRangeDescriptionLabel
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1.0
                                                                 constant:SideLabelMargin]];
            
            // Set the height of the descriptionLabels
            [constraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_valueLabel]-(>=0)-[_rightRangeDescriptionLabel]-(>=0)-[_middleRangeDescriptionLabel]-(>=0)-[_leftRangeDescriptionLabel]"
                                                     options:NSLayoutFormatDirectionLeadingToTrailing
                                                     metrics:nil
                                                       views:views]];
            
            
            // Align the descriptionLabels with the rangeViews
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_rightRangeDescriptionLabel
                                                                attribute:NSLayoutAttributeTop
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeTop
                                                               multiplier:1.0
                                                                 constant:0.0]];
            
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_leftRangeDescriptionLabel
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1.0
                                                                 constant:0.0]];
            
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_middleRangeDescriptionLabel
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_slider
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1.0
                                                                 constant:0.0]];
        }
    } else {
        // Horizontal slider constraints
        [constraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_valueLabel]-[_slider]-(>=8)-|"
                                                 options:NSLayoutFormatAlignAllCenterX | NSLayoutFormatDirectionLeftToRight
                                                 metrics:nil
                                                   views:views]];
        [constraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_slider]-[_leftRangeDescriptionLabel]-(>=8)-|"
                                                 options:NSLayoutFormatDirectionLeftToRight
                                                 metrics:nil
                                                   views:views]];
        [constraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_slider]-[_rightRangeDescriptionLabel]-(>=8)-|"
                                                 options:NSLayoutFormatDirectionLeftToRight
                                                 metrics:nil
                                                   views:views]];
        
        const CGFloat kMargin = 17.0;
        [constraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-kMargin-[_leftRangeView]-kMargin-[_slider]-kMargin-[_rightRangeView(==_leftRangeView)]-kMargin-|"
                                                 options:NSLayoutFormatAlignAllCenterY | NSLayoutFormatDirectionLeftToRight
                                                 metrics:@{@"kMargin": @(kMargin)}
                                                   views:views]];
        [constraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-kMargin-[_leftRangeDescriptionLabel]-(>=16)-[_rightRangeDescriptionLabel(==_leftRangeDescriptionLabel)]-kMargin-|"
                                                 options:NSLayoutFormatAlignAllCenterY | NSLayoutFormatDirectionLeftToRight
                                                 metrics:@{@"kMargin": @(kMargin)}
                                                   views:views]];
        
        //put middle labels where they should be
        //for (int i = 0; i < _RangeLabels.count; i++)
        {
            //if(i != 0)
            {
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_RangeLabels[1]
                                                                    attribute:NSLayoutAttributeCenterX
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:_slider
                                                                    attribute:NSLayoutAttributeCenterX
                                                                   multiplier:0.5
                                                                     constant:0.0]];
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_RangeLabels[1]
                                                                    attribute:NSLayoutAttributeTop
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:_leftRangeDescriptionLabel
                                                                    attribute:NSLayoutAttributeTop
                                                                   multiplier:1.0
                                                                     constant:0.0]];
                
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_RangeLabels[2]
                                                                    attribute:NSLayoutAttributeCenterX
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:_slider
                                                                    attribute:NSLayoutAttributeCenterX
                                                                   multiplier:1
                                                                     constant:0.0]];
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_RangeLabels[2]
                                                                    attribute:NSLayoutAttributeTop
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:_leftRangeDescriptionLabel
                                                                    attribute:NSLayoutAttributeTop
                                                                   multiplier:1.0
                                                                     constant:0.0]];
                
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_RangeLabels[3]
                                                                    attribute:NSLayoutAttributeCenterX
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:_slider
                                                                    attribute:NSLayoutAttributeCenterX
                                                                   multiplier:1.5
                                                                     constant:0.0]];
                [constraints addObject:[NSLayoutConstraint constraintWithItem:_RangeLabels[3]
                                                                    attribute:NSLayoutAttributeTop
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:_leftRangeDescriptionLabel
                                                                    attribute:NSLayoutAttributeTop
                                                                   multiplier:1.0
                                                                     constant:0.0]];
            }
        }
    }
    [NSLayoutConstraint activateConstraints:constraints];
}

- (id<ORKTextScaleAnswerFormatProvider>)textScaleFormatProvider {
    if ([[_formatProvider class] conformsToProtocol:@protocol(ORKTextScaleAnswerFormatProvider)]) {
        return (id<ORKTextScaleAnswerFormatProvider>)_formatProvider;
    }
    return nil;
}

- (void)setCurrentNumberValue:(NSNumber *)value {
    
    _currentNumberValue = value ? [_formatProvider normalizedValueForNumber:value] : nil;
    _slider.showThumb = _currentNumberValue ? YES : NO;
    
    [self updateCurrentValueLabel];
    _slider.value = _currentNumberValue.floatValue;
}

- (NSUInteger)currentTextChoiceIndex {
    return _currentNumberValue.unsignedIntegerValue - 1;
}

- (void)updateCurrentValueLabel {
    
    if (_currentNumberValue) {
        if ([self textScaleFormatProvider]) {
            ORKTextChoice *textChoice = [[self textScaleFormatProvider] textChoiceAtIndex:[self currentTextChoiceIndex]];
            self.valueLabel.text = textChoice.text;
        } else {
            NSNumber *newValue = [_formatProvider normalizedValueForNumber:_currentNumberValue];
            _valueLabel.text = [NSString stringWithFormat:@"%1.1f", newValue.doubleValue];
        }
    } else {
        _valueLabel.text = @"";
    }
}

- (IBAction)sliderValueChanged:(id)sender {
    
    _currentNumberValue = [_formatProvider normalizedValueForNumber:@(_slider.value)];
    [self updateCurrentValueLabel];
    [self notifyDelegate];
}

- (void)notifyDelegate {
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(scaleSliderViewCurrentValueDidChange:)]) {
        [self.delegate scaleSliderViewCurrentValueDidChange:self];
    }
}

- (void)setCurrentTextChoiceValue:(id<NSCopying, NSCoding, NSObject>)currentTextChoiceValue {
    
    if (currentTextChoiceValue) {
        NSUInteger index = [[self textScaleFormatProvider] textChoiceIndexForValue:currentTextChoiceValue];
        if (index != NSNotFound) {
            [self setCurrentNumberValue:@(index + 1)];
        } else {
            [self setCurrentNumberValue:nil];
        }
    } else {
        [self setCurrentNumberValue:nil];
    }
}

- (id<NSCopying, NSCoding, NSObject>)currentTextChoiceValue {
    id<NSCopying, NSCoding, NSObject> value = [[self textScaleFormatProvider] textChoiceAtIndex:[self currentTextChoiceIndex]].value;
    return value;
}

- (id)currentAnswerValue {
    id<ORKTextScaleAnswerFormatProvider> fmt = [self textScaleFormatProvider];
    if (fmt) {
        if ([fmt respondsToSelector:@selector(continuous)] && fmt.continuous) {
            return _currentNumberValue ? @[_currentNumberValue] : @[];
        } else {
            id<NSCopying, NSCoding, NSObject> value = [self currentTextChoiceValue];
            return value ? @[value] : @[];
        }
    } else {
        return _currentNumberValue;
    }
}

- (void)setCurrentAnswerValue:(id)currentAnswerValue {
    if ([self textScaleFormatProvider]) {
        
        if (ORKIsAnswerEmpty(currentAnswerValue)) {
            [self setCurrentTextChoiceValue:nil];
        } else {
            [self setCurrentTextChoiceValue:[currentAnswerValue firstObject]];
        }
    } else {
        [self setCurrentNumberValue:currentAnswerValue];
    }
}

#pragma mark - Accessibility

// Since the slider is the only interesting thing within this cell, we make the
// cell a container with only one element, i.e. the slider.

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSInteger)accessibilityElementCount {
    return (_slider != nil ? 1 : 0);
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return _slider;
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return (element == _slider ? 0 : NSNotFound);
}

@end
