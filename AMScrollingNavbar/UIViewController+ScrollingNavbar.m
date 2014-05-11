//
//  UIViewController+ScrollingNavbar.m
//  ScrollingNavbarDemo
//
//  Created by Andrea on 24/03/14.
//  Copyright (c) 2014 Andrea Mazzini. All rights reserved.
//

#import "UIViewController+ScrollingNavbar.h"
#import <objc/runtime.h>

#define IOS7_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)

@implementation UIViewController (ScrollingNavbar)

- (void)setPanGesture:(UIPanGestureRecognizer*)panGesture { objc_setAssociatedObject(self, @selector(panGesture), panGesture, OBJC_ASSOCIATION_RETAIN); }
- (UIPanGestureRecognizer*)panGesture { return objc_getAssociatedObject(self, @selector(panGesture)); }

- (void)setScrollableView:(UIView*)scrollableView { objc_setAssociatedObject(self, @selector(scrollableView), scrollableView, OBJC_ASSOCIATION_RETAIN); }
- (UIView*)scrollableView { return objc_getAssociatedObject(self, @selector(scrollableView)); }

- (void)setOverlay:(UIView*)overlay { objc_setAssociatedObject(self, @selector(overlay), overlay, OBJC_ASSOCIATION_RETAIN); }
- (UIView*)overlay { return objc_getAssociatedObject(self, @selector(overlay)); }

- (void)setCollapsed:(BOOL)collapsed { objc_setAssociatedObject(self, @selector(collapsed), [NSNumber numberWithBool:collapsed], OBJC_ASSOCIATION_RETAIN); }
- (BOOL)collapsed { return [objc_getAssociatedObject(self, @selector(collapsed)) boolValue]; }

- (void)setExpanded:(BOOL)expanded { objc_setAssociatedObject(self, @selector(expanded), [NSNumber numberWithBool:expanded], OBJC_ASSOCIATION_RETAIN); }
- (BOOL)expanded { return [objc_getAssociatedObject(self, @selector(expanded)) boolValue]; }

- (void)setLastContentOffset:(float)lastContentOffset { objc_setAssociatedObject(self, @selector(lastContentOffset), [NSNumber numberWithFloat:lastContentOffset], OBJC_ASSOCIATION_RETAIN); }
- (float)lastContentOffset { return [objc_getAssociatedObject(self, @selector(lastContentOffset)) floatValue]; }

- (void)setMaxDelay:(float)maxDelay { objc_setAssociatedObject(self, @selector(maxDelay), [NSNumber numberWithFloat:maxDelay], OBJC_ASSOCIATION_RETAIN); }
- (float)maxDelay { return [objc_getAssociatedObject(self, @selector(maxDelay)) floatValue]; }

- (void)setDelayDistance:(float)delayDistance { objc_setAssociatedObject(self, @selector(delayDistance), [NSNumber numberWithFloat:delayDistance], OBJC_ASSOCIATION_RETAIN); }
- (float)delayDistance { return [objc_getAssociatedObject(self, @selector(delayDistance)) floatValue]; }

- (void)setAnimationTimer:(CADisplayLink*)animationTimer { objc_setAssociatedObject(self, @selector(animationTimer), animationTimer, OBJC_ASSOCIATION_RETAIN); }
- (CADisplayLink*)animationTimer { return objc_getAssociatedObject(self, @selector(animationTimer)); }

- (void)setAnimationTimestamp:(float)animationTimestamp { objc_setAssociatedObject(self, @selector(animationTimestamp), [NSNumber numberWithFloat:animationTimestamp], OBJC_ASSOCIATION_RETAIN); }
- (float)animationTimestamp { return [objc_getAssociatedObject(self, @selector(animationTimestamp)) floatValue]; }

- (void)setAnimationDelta:(float)animationDelta { objc_setAssociatedObject(self, @selector(animationDelta), [NSNumber numberWithFloat:animationDelta], OBJC_ASSOCIATION_RETAIN); }
- (float)animationDelta { return [objc_getAssociatedObject(self, @selector(animationDelta)) floatValue]; }

- (void)setAnimateAlpha:(BOOL)animateAlpha { objc_setAssociatedObject(self, @selector(animateAlpha), [NSNumber numberWithBool:animateAlpha], OBJC_ASSOCIATION_RETAIN); }
- (BOOL)animateAlpha { return [objc_getAssociatedObject(self, @selector(animateAlpha)) boolValue]; }

- (void)setTitleFrame:(CGRect)titleFrame { objc_setAssociatedObject(self, @selector(titleFrame), [NSValue valueWithCGRect:titleFrame], OBJC_ASSOCIATION_RETAIN); }
- (CGRect)titleFrame { return [objc_getAssociatedObject(self, @selector(titleFrame)) CGRectValue]; }

static float kPanGestureSensitivity = 1.0;
static float kAnimationSpeedCoeff = 20.0;
static float kAnimationOffsetThreshold = 1.0;


- (void)followScrollView:(UIView*)scrollableView
{
    [self followScrollView:scrollableView withDelay:0 withScaleTitle:YES];
}

- (void)followScrollView:(UIView*)scrollableView withDelay:(float)delay withScaleTitle:(BOOL)scaleTitle
{
    self.scrollableView = scrollableView;
    
    if (scaleTitle) {
        self.titleFrame = self.navigationItem.titleView.frame;
    } else {
        self.titleFrame = CGRectZero;
    }
    
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.panGesture setMaximumNumberOfTouches:1];
    [self.panGesture setDelegate:self];
    [self.scrollableView addGestureRecognizer:self.panGesture];
    
    /* The navbar fadeout is achieved using an overlay view with the same barTintColor.
     this might be improved by adjusting the alpha component of every navbar child */
    CGRect frame = self.navigationController.navigationBar.frame;
    frame.origin = CGPointZero;
    self.overlay = [[UIView alloc] initWithFrame:frame];
    
    // Use tintColor instead of barTintColor on iOS < 7
    if (IOS7_OR_LATER) {
        if (!self.navigationController.navigationBar.barTintColor) {
            NSLog(@"[%s]: %@", __PRETTY_FUNCTION__, @"[AMScrollingNavbarViewController] Warning: no bar tint color set");
        }
        [self.overlay setBackgroundColor:self.navigationController.navigationBar.barTintColor];
    } else {
        [self.overlay setBackgroundColor:self.navigationController.navigationBar.tintColor];
    }
    
    if ([self.navigationController.navigationBar isTranslucent]) {
        NSLog(@"[%s]: %@", __PRETTY_FUNCTION__, @"[AMScrollingNavbarViewController] Warning: the navigation bar should not be translucent");
    }
    
    [self.overlay setUserInteractionEnabled:NO];
    [self.overlay setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self.navigationController.navigationBar addSubview:self.overlay];
    [self.overlay setAlpha:0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    self.maxDelay = delay;
    self.delayDistance = 0;
}

- (void)stopFollowingScrollView
{
    [self showNavBarAnimated:NO];
    [self.scrollableView removeGestureRecognizer:self.panGesture];
    [self.overlay removeFromSuperview];
    self.overlay = nil;
    self.scrollableView = nil;
    self.panGesture = nil;
}

- (void)didBecomeActive:(id)sender
{
    [self stopAnimateWithTimer];
    [self showNavbar];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    CGRect frame = self.overlay.frame;
    frame.size.height = self.navigationController.navigationBar.frame.size.height;
    self.overlay.frame = frame;
    
    [self updateSizingWithDelta:0];
}

- (float)deltaLimit
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return ([[UIApplication sharedApplication] isStatusBarHidden]) ? 44 : 24;
    } else {
        if ([[UIApplication sharedApplication] isStatusBarHidden]) {
            return (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? 44 : 32);
        } else {
            if (IOS7_OR_LATER) {
                return (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? 24 : 12);
            } else {
                return (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? 44 : 12);
            }
        }
    }
}

- (float)statusBar
{
    if (IOS7_OR_LATER) {
        return ([[UIApplication sharedApplication] isStatusBarHidden]) ? 0 : 20;
    } else {
        return ([[UIApplication sharedApplication] isStatusBarHidden]) ? 0 : 0;
    }
}

- (float)navbarHeight
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return ([[UIApplication sharedApplication] isStatusBarHidden]) ? 44 : 64;
    } else {
        if ([[UIApplication sharedApplication] isStatusBarHidden]) {
            return (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? 44 : 32);
        } else {
            return (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? 64 : 52);
        }
    }
}

- (void)showNavBarAnimated:(BOOL)animated
{
    if (self.scrollableView) {
        [self stopAnimateWithTimer];
        if (animated) {
            [self startAnimateWithTimerExpand:YES animateAlpha:NO];
        } else {
            self.lastContentOffset = 0;
            CGRect frame = self.navigationController.navigationBar.frame;
            [self scrollWithDelta:frame.origin.y - self.statusBar];
        }
    }
}

- (void)hideNavbar
{
    [self hideNavBarAnimated:YES];
}

- (void)hideNavBarAnimated:(BOOL)animated
{
    if (self.scrollableView) {
        [self stopAnimateWithTimer];
        if (animated) {
            [self startAnimateWithTimerExpand:NO animateAlpha:NO];
        } else {
            self.lastContentOffset = 0;
            CGRect frame = self.navigationController.navigationBar.frame;
            [self scrollWithDelta:frame.origin.y + self.deltaLimit];
        }
    }
}

- (void)showNavbar
{
    [self showNavBarAnimated:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)setScrollingEnabled:(BOOL)enabled
{
    self.panGesture.enabled = enabled;
}

- (void)handlePan:(UIPanGestureRecognizer*)gesture
{
    CGPoint translation = [gesture translationInView:[self.scrollableView superview]];
    
    float delta = self.lastContentOffset - translation.y;
    self.lastContentOffset = translation.y;
    
    if ([gesture state] == UIGestureRecognizerStateBegan) {
        [self stopAnimateWithTimer];
        self.animateAlpha = YES;
        if (self.collapsed) {
            self.delayDistance = self.maxDelay;
        }
    }
    
    if (self.delayDistance > 0) {
        if (self.contentOffset.y < 0) {
            self.delayDistance = 0;
        } else {
            self.delayDistance += delta;
        }
    }
    
    if (delta && self.delayDistance <= 0) {
        [self scrollWithDelta:kPanGestureSensitivity * delta];
    }
    
    if ([gesture state] == UIGestureRecognizerStateEnded) {
        // Continue expand/collapse if the scroll is partial
        [self checkForPartialCollapse:(translation.y < 0)];
        self.lastContentOffset = 0;
    }
}

- (void)scrollWithDelta:(CGFloat)delta
{
    CGRect frame = self.navigationController.navigationBar.frame;
    
    if (delta > 0) {
        if (self.collapsed) {
            [[self scrollView] setShowsVerticalScrollIndicator:YES];
            return;
        }
        
        // Prevents the navbar from moving during the 'rubberband' scroll
        if ([self contentOffset].y < 0) {
            return;
        }
        if (self.expanded) {
            self.expanded = NO;
        }

        if (frame.origin.y - delta < -self.deltaLimit) {
            delta = frame.origin.y + self.deltaLimit;
        }
        
        frame.origin.y = MAX(-self.deltaLimit, frame.origin.y - delta);
        
        if (ABS(frame.origin.y + self.deltaLimit) < kAnimationOffsetThreshold) {
            frame.origin.y = -self.deltaLimit;
            self.collapsed = YES;
            self.expanded = NO;
            self.delayDistance = self.maxDelay;
        }

        self.navigationController.navigationBar.frame = frame;
        [[self scrollView] setShowsVerticalScrollIndicator:NO];
        
        [self updateSizingWithDelta:delta];
        [self restoreContentOffset:delta];
    }
    else if (delta < 0) {
        if (self.expanded) {
            [[self scrollView] setShowsVerticalScrollIndicator:YES];
            return;
        }
        // Prevents the navbar from moving during the 'rubberband' scroll
        if ([self contentOffset].y + self.scrollableView.frame.size.height > [self contentSize].height) {
            return;
        }
        if (self.collapsed) {
            self.collapsed = NO;
        }
        
        if (frame.origin.y - delta > self.statusBar) {
            delta = frame.origin.y - self.statusBar;
        }
        frame.origin.y = MIN(self.statusBar/* 20? */, frame.origin.y - delta);
        
        if (ABS(frame.origin.y - self.statusBar) < kAnimationOffsetThreshold) {
            frame.origin.y = self.statusBar;
            self.expanded = YES;
            self.collapsed = NO;
        }
        
        self.navigationController.navigationBar.frame = frame;
        [[self scrollView] setShowsVerticalScrollIndicator:NO];
        
        [self updateSizingWithDelta:delta];
        [self restoreContentOffset:delta];
    }
}

- (UIScrollView*)scrollView
{
    UIScrollView* scroll;
    if ([self.scrollableView isKindOfClass:[UIWebView class]]) {
        scroll = [(UIWebView*)self.scrollableView scrollView];
    } else if ([self.scrollableView isKindOfClass:[UIScrollView class]]) {
        scroll = (UIScrollView*)self.scrollableView;
    }
    return scroll;
}

- (void)restoreContentOffset:(float)delta
{
    // Hold the scroll steady until the navbar appears/disappears
    if (!self.animationTimer) {
        CGPoint offset = [[self scrollView] contentOffset];
        [[self scrollView] setContentOffset:(CGPoint){offset.x, offset.y - delta}];
    }
}

- (CGPoint)contentOffset
{
    return [[self scrollView] contentOffset];
}

- (CGSize)contentSize
{
    return [[self scrollView] contentSize];
}

- (void)checkForPartialCollapse:(BOOL)collapse
{
    if (!self.collapsed && !self.expanded) {
        // Collapse
        if (collapse) {
            [self startAnimateWithTimerExpand:NO animateAlpha:YES];
        } else {
            // Expand
            [self startAnimateWithTimerExpand:YES animateAlpha:YES];
        }
    }
}

- (void)startAnimateWithTimerExpand:(BOOL)expand animateAlpha:(BOOL)animateAlpha
{
    [self stopAnimateWithTimer];
    
    self.delayDistance = 0;
    self.animateAlpha = animateAlpha;
    
    CGRect frame = self.navigationController.navigationBar.frame;
    if (expand) {
        self.animationDelta = frame.origin.y - self.statusBar;
    } else {
        self.animationDelta = frame.origin.y + self.deltaLimit;
    }
    
    // Using CADisplayLink to schedule animation timer
    self.animationTimer = [CADisplayLink displayLinkWithTarget:self
                                                      selector:@selector(updateAnimation:)];
    [self.animationTimer addToRunLoop:[NSRunLoop currentRunLoop]
                              forMode:NSRunLoopCommonModes];
    self.animationTimestamp = -1.0;
}

- (void)stopAnimateWithTimer
{
    if (self.animationTimer) {
        [self.animationTimer invalidate];
        self.animationTimer = nil;
    }
}

- (void)updateAnimation:(id)sender
{
    float oldTimestamp = self.animationTimestamp;
    self.animationTimestamp = self.animationTimer.timestamp;
    
    if (oldTimestamp < 0) {
        return;
    }
    
    float dt = self.animationTimestamp - oldTimestamp;
//    NSLog(@"[AMScrollingNavbarViewController] dt = %f", dt);
    
    float delta;
    if (ABS(self.animationDelta) < kAnimationOffsetThreshold) {
        delta = self.animationDelta;
        [self stopAnimateWithTimer];
    } else {
        delta = self.animationDelta * MIN(1.0, kAnimationSpeedCoeff * dt);
    }
//    NSLog(@"[AMScrollingNavbarViewController] delta: %f", delta);
    
    self.animationDelta -= delta;
    [self scrollWithDelta:delta];
}

- (void)updateSizingWithDelta:(CGFloat)delta
{
    [self updateNavbarAlpha:delta];

    // At this point the navigation bar is already been placed in the right position, it'll be the reference point for the other views'sizing
    CGRect frameNav = self.navigationController.navigationBar.frame;
    
    // Move and expand (or shrink) the superview of the given scrollview
    CGRect frame = self.scrollableView.superview.frame;
    if (IOS7_OR_LATER) {
        frame.origin.y = frameNav.origin.y + frameNav.size.height;
    } else {
        frame.origin.y = frameNav.origin.y;
    }
    frame.size.height = [UIScreen mainScreen].bounds.size.height - frame.origin.y;
    self.scrollableView.superview.frame = frame;
}

- (void)updateNavbarAlpha:(CGFloat)delta
{
    CGRect frame = self.navigationController.navigationBar.frame;
    
    if (self.scrollableView != nil) {
        [self.navigationController.navigationBar bringSubviewToFront:self.overlay];
    }
    
    // Change the alpha channel of every item on the navbr. The overlay will appear, while the other objects will disappear, and vice versa
    float x = 1.0 - (frame.origin.y + self.deltaLimit) / frame.size.height;
    float alpha = MIN(MAX(0, 1.0 - 2.0 * x), 1.0);

//    [self.overlay setAlpha:1 - alpha];
    self.overlay.userInteractionEnabled = (alpha < 1.0);
    
//    NSLog(@"[AMScrollingNavbarViewController] alpha: %f", alpha);

    // We have to keep alpha untouched on screen transitions, as well is alpha is updated
    // automatically on push- or pop- view controllers animations.
    if (self.animateAlpha) {
        [self.navigationItem.leftBarButtonItems enumerateObjectsUsingBlock:^(UIBarButtonItem* obj, NSUInteger idx, BOOL *stop) {
            obj.customView.alpha = alpha;
        }];
        self.navigationItem.leftBarButtonItem.customView.alpha = alpha;
        [self.navigationItem.rightBarButtonItems enumerateObjectsUsingBlock:^(UIBarButtonItem* obj, NSUInteger idx, BOOL *stop) {
            obj.customView.alpha = alpha;
        }];
        self.navigationItem.rightBarButtonItem.customView.alpha = alpha;
        self.navigationItem.titleView.alpha = alpha;
//        self.navigationController.navigationBar.tintColor = [self.navigationController.navigationBar.tintColor colorWithAlphaComponent:alpha];
    }
    
    if (!CGRectIsNull(self.titleFrame)) {
        self.navigationItem.titleView.frame = CGRectApplyAffineTransform(self.titleFrame, CGAffineTransformMakeScale(alpha, alpha));
    }
    
}

@end
