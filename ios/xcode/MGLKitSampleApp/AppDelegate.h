//
//  AppDelegate.h
//  MGLKitSampleApp
//
//  Created by Le Quyen on 15/10/19.
//  Copyright © 2019 HQGame. All rights reserved.
//

#include <TargetConditionals.h>

#if TARGET_OS_OSX
#    import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
#else
#    import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, retain) IBOutlet UIWindow *window;
#endif

@end
