//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import "MGLKViewController.h"

@interface MGLKViewController () {
    __weak MGLKView *_glView;
    CADisplayLink *_displayLink;
    CFTimeInterval _lastUpdateTime;

    BOOL _appWasInBackground;
}

@end

@implementation MGLKViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [self constructor];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder])
    {
        [self constructor];
    }
    return self;
}

- (void)constructor
{
    _appWasInBackground       = YES;
    _preferredFramesPerSecond = 30;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillPause:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self resume];
}

- (void)setView:(UIView *)view
{
    [super setView:view];
    if ([view isKindOfClass:MGLKView.class])
    {
        _glView = (MGLKView *)view;
        if (!_glView.delegate)
        {
            _glView.delegate = self;
        }
    }
    else
    {
        _glView = nil;
    }
}

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    _preferredFramesPerSecond = preferredFramesPerSecond;
    if (_displayLink)
    {
        _displayLink.preferredFramesPerSecond = _preferredFramesPerSecond;
    }
    [self pause];
    [self resume];
}

- (void)mglkView:(MGLKView *)view drawInRect:(CGRect)rect
{
    // Default implementation do nothing.
}

- (void)appWillPause:(NSNotification *)note
{
    _appWasInBackground = YES;
    [self pause];
}

- (void)appDidBecomeActive:(NSNotification *)note
{
    [self resume];
}

- (void)pause
{
    if (_displayLink)
    {
        [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        _displayLink = nil;
    }
}

- (void)resume
{
    [self pause];

    if (!_displayLink)
    {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(frameStep)];
        _displayLink.preferredFramesPerSecond = _preferredFramesPerSecond;
    }

    if (_glView)
    {
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)handleAppWasInBackground
{
    if (!_appWasInBackground)
    {
        return;
    }
    // To avoid time jump when the app goes to background
    // for a long period of time.
    _lastUpdateTime = CACurrentMediaTime();

    _appWasInBackground = NO;
}

- (void)frameStep
{
    [self handleAppWasInBackground];

    CFTimeInterval now   = CACurrentMediaTime();
    _timeSinceLastUpdate = now - _lastUpdateTime;

    [self update];
    [_glView display];

    _framesDisplayed++;
    _lastUpdateTime = now;

#if 0
    if (_timeSinceLastUpdate > 2 * _displayLink.duration)
    {
        NSLog(@"frame was jump by %fs", _timeSinceLastUpdate);
    }
#endif
}

- (void)update
{
    if (_delegate)
    {
        [_delegate mglkViewControllerUpdate:self];
    }
}

@end
