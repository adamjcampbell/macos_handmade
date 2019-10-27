#import <Cocoa/Cocoa.h>

int main (int argc, char const *argv[]) {
    @autoreleasepool {
        NSString *appName = @"Handmade Hero";

        // Boot application
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSNotificationName notificationName = NSApplicationDidFinishLaunchingNotification;
        void (^didFinishLaunchingBlock)(NSNotification *) = ^void(NSNotification *note) {
            // TODO: Change this to NO for production
            [NSApp activateIgnoringOtherApps:YES];
        };
        __unused id observer = [notificationCenter addObserverForName:notificationName
                                                               object:nil
                                                                queue:nil
                                                           usingBlock:didFinishLaunchingBlock];

        // Setup main menu
        NSMenu *menuBar = [[NSMenu alloc] init];
        NSMenuItem *menuBarAppItem = [[NSMenuItem alloc] init];
        NSMenu *appMenu = [[NSMenu alloc] init];
        NSString *quitItemTitle = [@"Quit " stringByAppendingString:appName];
        NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:quitItemTitle
                                                          action:@selector(terminate:)
                                                   keyEquivalent:@"q"];
        [menuBar addItem:menuBarAppItem];
        [menuBarAppItem setSubmenu:appMenu];
        [appMenu addItem:quitItem];
        [NSApp setMainMenu:menuBar];

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
        [window setTitle:appName];
        [window center];
        [window makeKeyAndOrderFront:nil];

        // Event loop
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
