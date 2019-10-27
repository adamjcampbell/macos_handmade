#import <Cocoa/Cocoa.h>

int main (int argc, char const *argv[]) {
    @autoreleasepool {
        // Boot application
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];
        // TODO: Change this to NO for production
        [NSApp activateIgnoringOtherApps:YES];

        // Setup window
        NSRect frame = NSMakeRect(0, 0, 300, 300);
        NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
                                      NSWindowStyleMaskClosable |
                                      NSWindowStyleMaskResizable |
                                      NSWindowStyleMaskMiniaturizable;
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:styleMask
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setTitle:@"Handmade"];
        [window center];
        [window makeKeyAndOrderFront:nil];

        while (true) {
            NSEvent *event;

            do {
                event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                           untilDate:nil
                                              inMode:NSDefaultRunLoopMode
                                             dequeue:YES];
                [NSApp sendEvent:event];
            } while (event != nil);
        }
    }
}
