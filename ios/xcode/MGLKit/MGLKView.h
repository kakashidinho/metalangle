//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef MGLKView_h
#define MGLKView_h

#import "MGLContext.h"

@class MGLKView;

@protocol MGLKViewDelegate <NSObject>

// Implement this method to draw to the view using current OpenGL
// context associated with the view.
- (void)mglkView:(MGLKView *)view drawInRect:(CGRect)rect;

@end

// NOTE: do not subclass this class, use delegate if needed to override
// the drawing method.
@interface MGLKView : MGLKNativeView

@property(nonatomic) MGLContext *context;
@property(nonatomic, assign) IBOutlet id<MGLKViewDelegate> delegate;

// Default value is NO. Setting to YES will keep the framebuffer data after presenting.
// Doing so will reduce performance and increase memory usage.
@property(nonatomic) BOOL retainedBacking;
@property(nonatomic) MGLDrawableColorFormat drawableColorFormat;      // Default is RGBA8888
@property(nonatomic) MGLDrawableDepthFormat drawableDepthFormat;      // Default is DepthNone
@property(nonatomic) MGLDrawableStencilFormat drawableStencilFormat;  // Default is StencilNone
@property(nonatomic)
    MGLDrawableMultisample drawableMultisample;  // Default is MGLDrawableMultisampleNone

// Return the size of the OpenGL default framebuffer.
@property(readonly) CGSize drawableSize;

#if TARGET_OS_IOS || TARGET_OS_TV
@property(readonly, strong) UIImage *snapshot;
#endif

// Redraw the view's contents immediately.
- (void)display;

@end

#endif /* MLKView_h */
