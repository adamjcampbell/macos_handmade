#import <Cocoa/Cocoa.h>

#define internal static
#define local_persist static
#define global_variable static

struct macos_offscreen_buffer {
    CGContextRef context;
    void *memory;
    int width;
    int height;
    int pitch; // This is bytes per row
    int bytesPerPixel;
};

// Global for now
global_variable macos_offscreen_buffer globalBackBuffer;
global_variable CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

internal void MacOsResizeBitmapContext(macos_offscreen_buffer *buffer, int width, int height) {
    if (buffer->memory) {
        free(buffer->memory);
        CGContextRelease(buffer->context);
    }

    buffer->width = width;
    buffer->height = height;
    buffer->bytesPerPixel = 4;
    buffer->pitch = width * buffer->bytesPerPixel;
    buffer->memory = calloc(height, buffer->pitch);
    buffer->context = CGBitmapContextCreate(buffer->memory, width, height, 8,
                                            buffer->pitch, colorSpace, kCGImageAlphaNoneSkipLast);
}

internal void RenderWeirdGradient(macos_offscreen_buffer buffer, int xOffset, int yOffset) {
    uint8_t *row = (uint8_t *)buffer.memory;
    for (int y = 0; y < buffer.height; ++y) {
        uint32_t *pixel = (uint32_t *)row;
        for(int x = 0; x < buffer.width; ++x) {
            uint8_t blue = x + xOffset;
            uint8_t green = y + yOffset;

            *pixel++ = ((blue << 16) | (green << 8));
        }
        row += buffer.pitch;
    }
}

internal void MacOsDisplayBufferInWindow(macos_offscreen_buffer buffer, NSWindow *window) {
    CGImageRef image = CGBitmapContextCreateImage(buffer.context);
    window.contentView.layer.contents = (__bridge id)image;
    CFRelease(image);
}

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

        // Setup window and view
        NSRect frame = NSMakeRect(0, 0, 1280, 720);
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

        MacOsResizeBitmapContext(&globalBackBuffer, 1280, 720);

        // Event loop
        int xOffset = 0;

        while (true) {
            NSEvent *event;

            do {
                event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                           untilDate:nil
                                              inMode:NSDefaultRunLoopMode
                                             dequeue:YES];
                [NSApp sendEvent:event];
            } while (event != nil);

            RenderWeirdGradient(globalBackBuffer, xOffset, 0);
            MacOsDisplayBufferInWindow(globalBackBuffer, window);

            xOffset++;
        }
    }
}
