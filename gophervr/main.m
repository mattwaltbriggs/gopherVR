/*
 * main.m
 *
 * Entry point for GopherVR Cocoa application.
 */

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#include <unistd.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        /* Set working directory to app's Resources so Hershey fonts are found */
        NSString *resPath = [[NSBundle mainBundle] resourcePath];
        if (resPath) {
            chdir([resPath UTF8String]);
        }

        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
