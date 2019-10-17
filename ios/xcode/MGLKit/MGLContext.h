//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import "MGLLayer.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum MGLRenderingAPI : int
{
    kMGLRenderingAPIOpenGLES1 = 1,
    kMGLRenderingAPIOpenGLES2 = 2,
} MGLRenderingAPI;

@interface MGLContext : NSObject

- (id)initWithAPI:(MGLRenderingAPI)api;

// Present the content of layer on screen as soon as possible.
- (BOOL)present:(MGLLayer *)layer;

+ (MGLContext *)currentContext;
+ (MGLLayer *)currentLayer;

// Set current context without layer
+ (BOOL)setCurrentContext:(MGLContext *_Nullable)context;

// Set current context to render to the given layer.
+ (BOOL)setCurrentContext:(MGLContext *_Nullable)context forLayer:(MGLLayer *_Nullable)layer;

@end

NS_ASSUME_NONNULL_END
