//
//  AppDelegate.m
//  MGLKitSampleApp
//
//  Created by Le Quyen on 15/10/19.
//  Copyright © 2019 HQGame. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

#if TARGET_OS_OSX
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

#else  // TARGET_OS_OSX
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    return YES;
}

#endif  // TARGET_OS_OSX

@end
