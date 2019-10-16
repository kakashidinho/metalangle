//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import "MGLKView.h"

NS_ASSUME_NONNULL_BEGIN

@class MGLKViewController;

@protocol MGLKViewControllerDelegate<NSObject>

- (void)mglkViewControllerUpdate:(MGLKViewController *)controller;

@end

@interface MGLKViewController : UIViewController<MGLKViewDelegate>

@property(nonatomic, assign) IBOutlet id<MGLKViewControllerDelegate> delegate;

// The default value is 30
@property(nonatomic) NSInteger preferredFramesPerSecond;

@property(nonatomic, readonly) NSInteger framesDisplayed;
@property(nonatomic, readonly) NSTimeInterval timeSinceLastUpdate;

@property(weak, nonatomic, readonly) MGLKView *glView;

@end

NS_ASSUME_NONNULL_END
