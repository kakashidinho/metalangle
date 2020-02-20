//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import "MGLKView.h"
#include <GLES2/gl2.h>

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

- (UIImage *) snapshot
{
    int s = 1;
    UIScreen* screen = [UIScreen mainScreen];
    if ([screen respondsToSelector:@selector(scale)]) {
        s = (int) [screen scale];
    }

    GLint viewport[4];
    glGetIntegerv(GL_VIEWPORT, viewport);


    int width = viewport[2];
    int height = viewport[3];

    int myDataLength = width * height * 4;
    GLubyte *buffer = (GLubyte *) malloc(myDataLength);
    GLubyte *buffer2 = (GLubyte *) malloc(myDataLength);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    for(int y1 = 0; y1 < height; y1++) {
        for(int x1 = 0; x1 <width * 4; x1++) {
            buffer2[(height - 1 - y1) * width * 4 + x1] = buffer[y1 * 4 * width + x1];
        }
    }
    free(buffer);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, myDataLength, releaseData);
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * width;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);
    UIImage *image = [ UIImage imageWithCGImage:imageRef scale:s orientation:UIImageOrientationUp ];
    return image;
}

void releaseData(void *info, const void *data, size_t size)
{
    free((void*)data);
}

@end
