@import Cocoa;
@import IOKit.pwr_mgt;
@import OpenGL.GL3;

int main(int argc, char **argv)
{
  @autoreleasepool
  {
    id app = [NSApplication sharedApplication];

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
    [app setServicesMenu:servicesMenu];

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
    [app setWindowsMenu:windowMenu];

    // Create the Help Menu
    id helpMenu = [[[NSMenu alloc] initWithTitle:@"Help"] autorelease];
    [[helpMenu addItemWithTitle:@"Documentation"
                         action:@selector(docs:)
                  keyEquivalent:@""] autorelease];
    [app setHelpMenu:helpMenu];

    // Create the Menu Bar
    id menubar = [[NSMenu new] autorelease];
    [[[menubar addItemWithTitle:@"" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:appMenu];
    [[[menubar addItemWithTitle:@"Window" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:windowMenu];
    [[[menubar addItemWithTitle:@"Help" action:NULL
                  keyEquivalent:@""] autorelease] setSubmenu:helpMenu];
    [app setMainMenu:menubar];

    // Create the Window
    NSWindow *window =
        [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 480)
                                     styleMask:NSWindowStyleMaskTitled |
                                               NSWindowStyleMaskResizable |
                                               NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskMiniaturizable
                                       backing:NSBackingStoreBuffered
                                         defer:NO] autorelease];
    [window setTitle:(displayName ? displayName : bundleName)];
    [window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [window setMinSize:NSMakeSize(300, 200)];
    [window setAcceptsMouseMovedEvents:YES];
    [window makeKeyAndOrderFront:nil];
    [window center];

    // Disable tabbing
    if ([window respondsToSelector:@selector(setTabbingMode:)])
      [window setTabbingMode:NSWindowTabbingModeDisallowed];

    // Create the View
    id view = [[NSView new] autorelease];
    [window makeFirstResponder:view];
    [window setContentView:view];

    // Create the Context
    id context = [[[NSOpenGLContext alloc]
        initWithFormat:[[[NSOpenGLPixelFormat alloc]
                           initWithAttributes:(uint[]){99, 0x4100, 0}]
                           autorelease]
          shareContext:nil] autorelease];
    [context setView:view];
    [context makeCurrentContext];

    // Setup OpenGL
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_CULL_FACE);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

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
    double timerStart = timerCurrent;
    double lag = 0.0;

    // Finish loading
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app activateIgnoringOtherApps:YES];
    [app finishLaunching];

    // Game Loop
    while (running)
    {
      NSEvent *event;
      while ((event = [app nextEventMatchingMask:NSEventMaskAny
                                       untilDate:[NSDate distantPast]
                                          inMode:NSDefaultRunLoopMode
                                         dequeue:YES]) != nil)
      {
        if ([event type] != NSEventTypeKeyDown ||
            [event modifierFlags] & NSEventModifierFlagCommand)
          [app sendEvent:event];
      }

      // Update Timer
      double timerNext = CACurrentMediaTime();
      double timerDelta = timerNext - timerCurrent;
      timerCurrent = timerNext;

      // Fixed updates
      for (lag += timerDelta; lag >= 1.0 / 60.0; lag -= 1.0 / 60.0)
      {
      }

      int w = (int)[view frame].size.width;
      int h = (int)[view frame].size.height;

      // Renderer
      glViewport(0, 0, w, h);
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

      // Finish Rendering
      glFlush();
      [context flushBuffer];
    }

    // Terminate
    IOPMAssertionRelease(assertionID);

    [app terminate:nil];
  }
}
