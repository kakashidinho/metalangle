//
//  main.m
//  MGLKitSampleApp
//
//  Created by Le Quyen on 15/10/19.
//  Copyright © 2019 HQGame. All rights reserved.
//

#import "AppDelegate.h"

#if TARGET_OS_OSX
int main(int argc, const char *argv[])
{
    return NSApplicationMain(argc, argv);
}
#else
int main(int argc, char *argv[])
{
    NSString *appDelegateClassName;
    @autoreleasepool
    {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
#endif
