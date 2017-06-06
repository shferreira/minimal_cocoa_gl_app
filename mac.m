#import <AudioToolbox/AudioToolbox.h>
#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <mach/mach_time.h>
#import <OpenGL/gl.h>

static OSStatus audioCallback(void *inRefCon,
                              AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber, UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
  Float32 *buffer = (Float32 *)ioData->mBuffers[0].mData;
  for (UInt32 frame = 0; frame < inNumberFrames; frame++)
  {
    buffer[frame] = 0;
  }

  return 0;
}

int main(int argc, char **argv)
{
  @autoreleasepool
  {
    [NSApplication sharedApplication];

    // Get the Application Name
    id appName = [[NSProcessInfo processInfo] processName];

    // Initialize Timer
    mach_timebase_info_data_t tinfo;
    mach_timebase_info(&tinfo);
    double tfreq = (1e9 * tinfo.denom) / tinfo.numer;
    double timer = (double)(mach_absolute_time()) / tfreq;
    double lag = 0.0;
    double fps = 30.0;

    // Prevent Sleeping
    IOPMAssertionID assertionID;
    IOPMAssertionCreateWithName(
        kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn,
        CFSTR("Application is an interactive game."), &assertionID);

    // Initialize Audio
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    AudioStreamBasicDescription audioFormat = {0};
    audioFormat.mSampleRate = 44100.00,
    audioFormat.mFormatID = kAudioFormatLinearPCM,
    audioFormat.mFormatFlags =
        kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 32;
    audioFormat.mBytesPerPacket = 4;
    audioFormat.mBytesPerFrame = 4;
    AURenderCallbackStruct callback = {0};
    callback.inputProc = audioCallback;
    AudioUnit audioUnit;
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    AudioComponentInstanceNew(component, &audioUnit);
    AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input, 0, &audioFormat,
                         sizeof(audioFormat));
    AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input, 0, &callback, sizeof(callback));
    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);

    // Create the Menus
    id menubar = [[NSMenu new] autorelease];
    id appMenu = [[NSMenu new] autorelease];
    id appMenuItem =
        [menubar addItemWithTitle:@"" action:NULL keyEquivalent:@""];
    [appMenuItem setSubmenu:appMenu];
    id servicesMenu = [[NSMenu alloc] autorelease];
    id windowMenuItem =
        [menubar addItemWithTitle:@"Window" action:NULL keyEquivalent:@""];
    id windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenuItem setSubmenu:windowMenu];
    id helpMenuItem =
        [menubar addItemWithTitle:@"Help" action:NULL keyEquivalent:@""];
    id helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenuItem setSubmenu:helpMenu];
    [[appMenu addItemWithTitle:@"Services" action:NULL keyEquivalent:@""]
        setSubmenu:servicesMenu];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide" action:nil keyEquivalent:@"h"];
    [[appMenu addItemWithTitle:@"Hide Others"
                        action:@selector(hideOtherApplications:)
                 keyEquivalent:@"h"]
        setKeyEquivalentModifierMask:NSAlternateKeyMask | NSCommandKeyMask];
    [appMenu addItemWithTitle:@"Show All"
                       action:@selector(unhideAllApplications:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@"n"];
    [[windowMenu addItemWithTitle:@"Full Screen"
                           action:@selector(toggleFullScreen:)
                    keyEquivalent:@"f"]
        setKeyEquivalentModifierMask:NSControlKeyMask | NSCommandKeyMask];
    [windowMenu addItemWithTitle:@"Close Window"
                          action:@selector(performClose:)
                   keyEquivalent:@"w"];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front"
                          action:@selector(arrangeInFront:)
                   keyEquivalent:@""];

    // Create the Window
    NSWindow *window = [[[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 640, 480)
                  styleMask:NSTitledWindowMask | NSResizableWindowMask |
                            NSClosableWindowMask | NSMiniaturizableWindowMask
                    // | NSFullSizeContentViewWindowMask
                    backing:NSBackingStoreBuffered
                      defer:NO] autorelease];
    [window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [window setMinSize:NSMakeSize(300, 200)];
    [window setAcceptsMouseMovedEvents:YES];
    [window makeKeyAndOrderFront:nil];
    [window setTitle:appName];
    [window setCanHide:NO];
    [window center];

    // Create the View
    id view = [[NSView new] autorelease];
    [window setContentView:view];
    [window makeFirstResponder:view];

    // Create the Context
    GLint swapInterval = 1;
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFADoubleBuffer,  NSOpenGLPFADepthSize,          24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core, 0};
    id format =
        [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
    id context = [[[NSOpenGLContext alloc] initWithFormat:format
                                             shareContext:nil] autorelease];
    [context setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
    [context setView:view];
    [context makeCurrentContext];

    // Setup observers
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSViewGlobalFrameDidChangeNotification
                    object:view
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                  [context update];
                }];

    // Finish loading
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp setMainMenu:menubar];
    [NSApp setWindowsMenu:windowMenu];
    [NSApp setHelpMenu:helpMenu];
    [NSApp setServicesMenu:servicesMenu];
    [NSApp finishLaunching];

    // Game Loop
    while ([window isVisible] || [window isMiniaturized])
    {
      NSEvent *event;
      while ((event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                         untilDate:[NSDate distantPast]
                                            inMode:NSDefaultRunLoopMode
                                           dequeue:YES]) != nil)
      {
        [NSApp sendEvent:event];
      }

      double next = (double)(mach_absolute_time()) / tfreq;
      double elapsed = next - timer;
      timer = next;

      for (lag += elapsed; lag >= 1.0 / fps; lag -= 1.0 / fps)
      {
      }

      glViewport(0, 0, (int)[view frame].size.width,
                 (int)[view frame].size.height);
      glClearColor(0.2f, 0.2f, 0.2f, 0.0f);
      glClear(GL_COLOR_BUFFER_BIT);
      glFlush();

      [context flushBuffer];
    }

    // Terminate
    AudioOutputUnitStop(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    IOPMAssertionRelease(assertionID);
    [NSApp terminate:nil];
  }
}
