#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#include <IOKit/hid/IOHIDManager.h>

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
global_variable bool globalRunning;
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
    buffer->context = CGBitmapContextCreate(buffer->memory, width, height, 8, buffer->pitch,
                                            colorSpace, kCGImageAlphaNoneSkipFirst |
                                            kCGBitmapByteOrder32Little);
}

internal void RenderWeirdGradient(macos_offscreen_buffer buffer, int xOffset, int yOffset) {
    uint8_t *row = (uint8_t *)buffer.memory;
    for (int y = 0; y < buffer.height; ++y) {
        uint32_t *pixel = (uint32_t *)row;
        for(int x = 0; x < buffer.width; ++x) {
            uint8_t blue = x + xOffset;
            uint8_t green = y + yOffset;

            *pixel++ = ((green << 8) | blue);
        }
        row += buffer.pitch;
    }
}

internal void MacOsDisplayBufferInWindow(macos_offscreen_buffer buffer, NSWindow *window) {
    CGImageRef image = CGBitmapContextCreateImage(buffer.context);
    window.contentView.layer.contents = (__bridge id)image;
    CFRelease(image);
}

// Provided by: https://stackoverflow.com/questions/14466371/ios-generate-and-play-indefinite-simple-audio-sine-wave
// TODO: Convert from floating point to integer sound
// TODO: Pass a more complex audio description to inRefCon
OSStatus SineWaveRenderCallback(void * inRefCon, AudioUnitRenderActionFlags * ioActionFlags,
                                const AudioTimeStamp * inTimeStamp, UInt32 inBusNumber,
                                UInt32 inNumberFrames, AudioBufferList * ioData) {
    // inRefCon is the context pointer we passed in earlier when setting the render callback
    double currentPhase = *((double *)inRefCon);
    // ioData is where we're supposed to put the audio samples we've created
    Float32 * outputBuffer = (Float32 *)ioData->mBuffers[0].mData;
    const double frequency = 440.;
    const double phaseStep = (frequency / 44100.) * (M_PI * 2.);

    for(int i = 0; i < inNumberFrames; i++) {
        outputBuffer[i] = sin(currentPhase);
        currentPhase += phaseStep;
    }

    // If we were doing stereo (or more), this would copy our sine wave samples
    // to all of the remaining channels
    for(int i = 1; i < ioData->mNumberBuffers; i++) {
        memcpy(ioData->mBuffers[i].mData, outputBuffer, ioData->mBuffers[i].mDataByteSize);
    }

    // writing the current phase back to inRefCon so we can use it on the next call
    *((double *)inRefCon) = currentPhase;
    return noErr;
}

global_variable AudioUnit outputUnit;
global_variable double renderPhase;

internal void MacOsStartCoreAudio() {

    AudioComponentDescription outputUnitDescription = {
        .componentType         = kAudioUnitType_Output,
        .componentSubType      = kAudioUnitSubType_DefaultOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple
    };
    AudioComponent outputComponent = AudioComponentFindNext(NULL, &outputUnitDescription);

    AudioComponentInstanceNew(outputComponent, &outputUnit);
    AudioUnitInitialize(outputUnit);

    AudioStreamBasicDescription audioStreamBasicDescription = {
        .mSampleRate       = 44100,
        .mFormatID         = kAudioFormatLinearPCM,
        .mFormatFlags      = kAudioFormatFlagsNativeFloatPacked,
        .mChannelsPerFrame = 1,
        .mFramesPerPacket  = 1,
        .mBitsPerChannel   = sizeof(Float32) * 8,
        .mBytesPerPacket   = sizeof(Float32),
        .mBytesPerFrame    = sizeof(Float32)
    };
    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                         &audioStreamBasicDescription, sizeof(audioStreamBasicDescription));
    AURenderCallbackStruct callbackInfo = {
        .inputProc       = SineWaveRenderCallback,
        .inputProcRefCon = &renderPhase
    };
    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global, 0, &callbackInfo, sizeof(callbackInfo));

    AudioOutputUnitStart(outputUnit);
}

internal void MacOsStopCoreAudio() {
    AudioOutputUnitStop(outputUnit);
    AudioUnitUninitialize(outputUnit);
    AudioComponentInstanceDispose(outputUnit);
}

internal void MacOsProcessInput(void * _Nullable context, IOReturn result, void * _Nullable sender,
                                IOHIDValueRef value) {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    IOHIDElementType type = IOHIDElementGetType(element);
    uint32_t page = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex integerValue = IOHIDValueGetIntegerValue(value);

    CFIndex min = IOHIDElementGetLogicalMin(element);
    CFIndex max = IOHIDElementGetLogicalMax(element);

    NSLog(@"type=%d, page=%d, usage=%d, value=%ld\n", type, page, usage, (long)integerValue);

    if (page == kHIDPage_GenericDesktop && type == kIOHIDElementTypeInput_Misc) {
        float normalised = (float)(integerValue - min) / (float)(max - min);

        switch (usage) {
            case 0x30:
            {
                NSLog(@"[x] scaled = %f\n", normalised);
                break;
            };
            case 0x31:
            {
                NSLog(@"[y] scaled = %f\n", normalised);
                break;
            };
            default:
                break;
        }
    }
}

internal void MacOsDeviceAttached(void* ctx, IOReturn result, void* sender, IOHIDDeviceRef device) {
    NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    if (!name) return;

#ifdef DEBUG
    NSLog(@"attached device: %@\n", name);
#endif

    IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    IOHIDDeviceRegisterInputValueCallback(device, MacOsProcessInput, NULL);
}

static void MacOsDeviceDetached(void* ctx, IOReturn result, void* sender, IOHIDDeviceRef device) {
    NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    if (!name) return;

#ifdef DEBUG
    NSLog(@"detatched device: %@\n", name);
#endif

    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
}

internal IOHIDManagerRef MacOSSetupInput() {
    NSArray *matcher = @[
        @{
            @kIOHIDDeviceUsagePageKey: @(kHIDPage_GenericDesktop),
            @kIOHIDDeviceUsageKey: @(kHIDUsage_GD_Keyboard)
        },
        @{
            @kIOHIDDeviceUsagePageKey: @(kHIDPage_GenericDesktop),
            @kIOHIDDeviceUsageKey: @(kHIDUsage_GD_GamePad)
        }
    ];

    IOHIDManagerRef hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    IOHIDManagerSetDeviceMatchingMultiple(hidManager, (__bridge CFArrayRef)matcher);
    IOHIDManagerRegisterDeviceMatchingCallback(hidManager, MacOsDeviceAttached, NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(hidManager, MacOsDeviceDetached, NULL);
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);

    return hidManager;
}

int main (int argc, char const *argv[]) {
    @autoreleasepool {
        NSString *appName = @"Handmade Hero";

        // Boot application
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];

        // Setup notifications
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSNotificationName didFinishLaunching = NSApplicationDidFinishLaunchingNotification;
        void (^didFinishLaunchingBlock)(NSNotification *) = ^void(NSNotification *note) {
            // TODO: Change this to NO for production
            [NSApp activateIgnoringOtherApps:YES];
        };
        NSNotificationName windowWillClose = NSWindowWillCloseNotification;
        void (^windowWillCloseBlock)(NSNotification *) = ^void(NSNotification *note) {
            globalRunning = false;
        };
        __unused NSArray *observers = @[
            [notificationCenter addObserverForName:didFinishLaunching object:nil queue:nil
                                        usingBlock:didFinishLaunchingBlock],
            [notificationCenter addObserverForName:windowWillClose object:nil queue:nil
                                        usingBlock:windowWillCloseBlock]
        ];

        // Setup main menu
        NSMenu *menuBar = [[NSMenu alloc] init];
        NSMenuItem *menuBarAppItem = [[NSMenuItem alloc] init];
        NSMenu *appMenu = [[NSMenu alloc] init];
        NSString *quitItemTitle = [@"Quit " stringByAppendingString:appName];
        // TODO: Make this make selector set globalRunning to false
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
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:styleMask
                                                         backing:NSBackingStoreBuffered defer:NO];
        [window setReleasedWhenClosed:false];
        [window setTitle:appName];
        [window center];
        [window makeKeyAndOrderFront:nil];

        // Setup input
        __unused IOHIDManagerRef hidManager = MacOSSetupInput();

        MacOsResizeBitmapContext(&globalBackBuffer, 1280, 720);
        MacOsStartCoreAudio();

        // Event loop
        globalRunning = true;
        int xOffset = 0;

        while (globalRunning) {
            NSEvent *event;

            do {
                event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:nil
                                              inMode:NSDefaultRunLoopMode dequeue:YES];
                [NSApp sendEvent:event];
            } while (event != nil);

            RenderWeirdGradient(globalBackBuffer, xOffset, 0);
            MacOsDisplayBufferInWindow(globalBackBuffer, window);

            xOffset++;
        }

        MacOsStopCoreAudio();
    }
}
