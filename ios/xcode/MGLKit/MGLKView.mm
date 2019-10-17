//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import "MGLKView.h"

namespace
{
void Throw(NSString *msg)
{
    [NSException raise:@"MGLSurfaceException" format:@"%@", msg];
}
}

@interface MGLKView ()

@property(atomic) BOOL drawing;
@property(nonatomic, weak) MGLLayer *glLayer;

@end

@implementation MGLKView

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder])
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)dealloc
{
    _context = nil;
}

+ (Class)layerClass
{
    return MGLLayer.class;
}

- (MGLLayer *)glLayer
{
    _glLayer = static_cast<MGLLayer *>(self.layer);
    return _glLayer;
}

- (void)setContext:(MGLContext *)context
{
    if (_drawing)
    {
        Throw(@"Changing GL context when drawing is not allowed");
    }

    _context = context;
}

- (void)setRetainedBacking:(BOOL)retainedBacking
{
    self.glLayer.retainedBacking = _retainedBacking = retainedBacking;
}

- (void)setDrawableColorFormat:(MGLDrawableColorFormat)drawableColorFormat
{
    self.glLayer.drawableColorFormat = _drawableColorFormat = drawableColorFormat;
}

- (void)setDrawableDepthFormat:(MGLDrawableDepthFormat)drawableDepthFormat
{
    self.glLayer.drawableDepthFormat = _drawableDepthFormat = drawableDepthFormat;
}

- (void)setDrawableStencilFormat:(MGLDrawableStencilFormat)drawableStencilFormat
{
    self.glLayer.drawableStencilFormat = _drawableStencilFormat = drawableStencilFormat;
}

- (void)display
{
    [self drawRect:self.bounds];
}

- (CGSize)drawableSize
{
    if (!self.layer)
    {
        CGSize zero = {0};
        return zero;
    }
    return self.glLayer.drawableSize;
}

- (void)drawRect:(CGRect)rect
{
    _drawing = YES;
    if (_context)
    {
        if (![MGLContext setCurrentContext:_context forLayer:self.glLayer])
        {
            Throw(@"Failed to setCurrentContext");
        }
    }

    if (_delegate)
    {
        [_delegate mglkView:self drawInRect:rect];
    }

    if (![_context present:self.glLayer])
    {
        Throw(@"Failed to present framebuffer");
    }
    _drawing = NO;
}

@end
