@import Cocoa;
@import IOKit.pwr_mgt;
@import OpenGL.GL;

int main(int argc, char **argv)
{
  @autoreleasepool
  {
    [NSApplication sharedApplication];

    // Get the Application Name
    id bundleName = [[NSProcessInfo processInfo] processName];
    id displayName =
        [[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"];

    // Prevent Sleeping
    IOPMAssertionID assertionID;
    IOPMAssertionCreateWithName(
        kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn,
        CFSTR("Application is an interactive game."), &assertionID);

    // Create the App Menu
    id appMenu = [[NSMenu new] autorelease];
    id servicesMenu = [[NSMenu alloc] autorelease];
    [[[appMenu addItemWithTitle:@"Services" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:servicesMenu];
    [appMenu addItem:[[NSMenuItem separatorItem] autorelease]];
    [[appMenu addItemWithTitle:@"Hide"
                        action:@selector(hide:)
                 keyEquivalent:@"h"] autorelease];
    [[[appMenu addItemWithTitle:@"Hide Others"
                         action:@selector(hideOtherApplications:)
                  keyEquivalent:@"h"] autorelease]
        setKeyEquivalentModifierMask:NSEventModifierFlagOption |
                                     NSEventModifierFlagCommand];
    [[appMenu addItemWithTitle:@"Show All"
                        action:@selector(unhideAllApplications:)
                 keyEquivalent:@""] autorelease];
    [appMenu addItem:[[NSMenuItem separatorItem] autorelease]];
    [[appMenu addItemWithTitle:@"Quit"
                        action:@selector(terminate:)
                 keyEquivalent:@"q"] autorelease];
    [NSApp setServicesMenu:servicesMenu];

    // Create the Window Menu
    id windowMenu = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
    [[windowMenu addItemWithTitle:@"Minimize"
                           action:@selector(performMiniaturize:)
                    keyEquivalent:@"m"] autorelease];
    [[windowMenu addItemWithTitle:@"Zoom"
                           action:@selector(performZoom:)
                    keyEquivalent:@"n"] autorelease];
    [[[windowMenu addItemWithTitle:@"Full Screen"
                            action:@selector(toggleFullScreen:)
                     keyEquivalent:@"f"] autorelease]
        setKeyEquivalentModifierMask:NSEventModifierFlagControl |
                                     NSEventModifierFlagCommand];
    [[windowMenu addItemWithTitle:@"Close Window"
                           action:@selector(performClose:)
                    keyEquivalent:@"w"] autorelease];
    [windowMenu addItem:[[NSMenuItem separatorItem] autorelease]];
    [[windowMenu addItemWithTitle:@"Bring All to Front"
                           action:@selector(arrangeInFront:)
                    keyEquivalent:@""] autorelease];
    [NSApp setWindowsMenu:windowMenu];

    // Create the Help Menu
    id helpMenu = [[[NSMenu alloc] initWithTitle:@"Help"] autorelease];
    [[helpMenu addItemWithTitle:@"Documentation"
                         action:@selector(docs:)
                  keyEquivalent:@""] autorelease];
    [NSApp setHelpMenu:helpMenu];

    // Create the Menu Bar
    id menubar = [[NSMenu new] autorelease];
    [[[menubar addItemWithTitle:@"" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:appMenu];
    [[[menubar addItemWithTitle:@"Window" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:windowMenu];
    [[[menubar addItemWithTitle:@"Help" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:helpMenu];
    [NSApp setMainMenu:menubar];

    // Create the Window
    NSWindow *window =
        [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 480)
                                     styleMask:NSWindowStyleMaskTitled |
                                               NSWindowStyleMaskResizable |
                                               NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskMiniaturizable
                                       backing:NSBackingStoreBuffered
                                         defer:NO] autorelease];
    [window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [window setMinSize:NSMakeSize(300, 200)];
    [window makeKeyAndOrderFront:nil];
    [window setTitle:(displayName ? displayName : bundleName)];
    [window center];

    // Disable tabbing
    if ([window respondsToSelector:@selector(setTabbingMode:)])
      [window setTabbingMode:NSWindowTabbingModeDisallowed];

    // Create the View
    id view = [[NSView new] autorelease];
    [window setContentView:view];
    [window makeFirstResponder:view];
    [window setAcceptsMouseMovedEvents:YES];

    // Create the Context
    id context = [[[NSOpenGLContext alloc]
        initWithFormat:[[[NSOpenGLPixelFormat alloc]
                           initWithAttributes:(uint32_t[]){99, 0x4100, 0}]
                           autorelease]
          shareContext:nil] autorelease];
    [context setView:view];
    [context makeCurrentContext];

    // Setup observers
    __block int running = 1;
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSWindowWillCloseNotification
                    object:window
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                  running = 0;
                }];

    // Start the Timer
    double timerCurrent = CACurrentMediaTime();

    // Finish loading
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp finishLaunching];

    // Game Loop
    while (running)
    {
      NSEvent *event;
      while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                         untilDate:[NSDate distantPast]
                                            inMode:NSDefaultRunLoopMode
                                           dequeue:YES]) != nil)
      {
        if ([event type] == NSEventTypeKeyDown &&
            !([event modifierFlags] & NSEventModifierFlagCommand))
          continue;

        [NSApp sendEvent:event];
      }

      // Update Timer
      double timerNext = CACurrentMediaTime();
      double timerDelta = timerNext - timerCurrent;
      timerCurrent = timerNext;

      // Renderer
      glViewport(0, 0, (int)[view frame].size.width,
                 (int)[view frame].size.height);
      glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
      glClear(GL_COLOR_BUFFER_BIT);
      glFlush();

      [context flushBuffer];
    }

    // Terminate
    IOPMAssertionRelease(assertionID);

    [NSApp terminate:nil];
  }
}
