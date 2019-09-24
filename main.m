@import Cocoa;
@import IOKit.pwr_mgt;
@import OpenGL.GL3;

#define GLSL(str) (const char*)"#version 330\n" #str

// Sky Shaders

const char* skyVertShader = GLSL(
  out vec3 pos;
  out vec3 fsun;
  uniform mat4 P;
  uniform mat4 V;
  uniform float time = 0.0;

  const vec2 data[4] = vec2[](
    vec2(-1.0,  1.0), vec2(-1.0, -1.0),
    vec2( 1.0,  1.0), vec2( 1.0, -1.0));

  void main()
  {
    gl_Position = vec4(data[gl_VertexID], 0.0, 1.0);
    pos = transpose(mat3(V)) * (inverse(P) * gl_Position).xyz;
    fsun = vec3(0.0, sin(time * 0.01), cos(time * 0.01));
  }
);

const char* skyFragShader = GLSL(
  in vec3 pos;
  in vec3 fsun;
  out vec4 color;
  uniform float time = 0.0;
  uniform float cirrus = 0.4;
  uniform float cumulus = 0.8;

  const float Br = 0.0025;
  const float Bm = 0.0003;
  const float g =  0.9800;
  const vec3 nitrogen = vec3(0.650, 0.570, 0.475);
  const vec3 Kr = Br / pow(nitrogen, vec3(4.0));
  const vec3 Km = Bm / pow(nitrogen, vec3(0.84));

  float hash(float n)
  {
    return fract(sin(n) * 43758.5453123);
  }

  float noise(vec3 x)
  {
    vec3 f = fract(x);
    float n = dot(floor(x), vec3(1.0, 157.0, 113.0));
    return mix(mix(mix(hash(n +   0.0), hash(n +   1.0), f.x),
                   mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
               mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                   mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
  }

  const mat3 m = mat3(0.0, 1.60,  1.20, -1.6, 0.72, -0.96, -1.2, -0.96, 1.28);
  float fbm(vec3 p)
  {
    float f = 0.0;
    f += noise(p) / 2; p = m * p * 1.1;
    f += noise(p) / 4; p = m * p * 1.2;
    f += noise(p) / 6; p = m * p * 1.3;
    f += noise(p) / 12; p = m * p * 1.4;
    f += noise(p) / 24;
    return f;
  }

  void main()
  {
    // Atmosphere Scattering
    float mu = dot(normalize(pos), normalize(fsun));
    vec3 extinction = mix(exp(-exp(-((pos.y + fsun.y * 4.0) * (exp(-pos.y * 16.0) + 0.1) / 80.0) / Br) * (exp(-pos.y * 16.0) + 0.1) * Kr / Br) * exp(-pos.y * exp(-pos.y * 8.0 ) * 4.0) * exp(-pos.y * 2.0) * 4.0, vec3(1.0 - exp(fsun.y)) * 0.2, -fsun.y * 0.2 + 0.5);
    color.rgb = 3.0 / (8.0 * 3.14) * (1.0 + mu * mu) * (Kr + Km * (1.0 - g * g) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5)) / (Br + Bm) * extinction;

    // Cirrus Clouds
    float density = smoothstep(1.0 - cirrus, 1.0, fbm(pos.xyz / pos.y * 2.0 + time * 0.05)) * 0.3;
    color.rgb = mix(color.rgb, extinction * 4.0, density * max(pos.y, 0.0));

    // Cumulus Clouds
    for (int i = 0; i < 3; i++)
    {
      float density = smoothstep(1.0 - cumulus, 1.0, fbm((0.7 + float(i) * 0.01) * pos.xyz / pos.y + time * 0.3));
      color.rgb = mix(color.rgb, extinction * density * 5.0, min(density, 1.0) * max(pos.y, 0.0));
    }

    // Dithering Noise
    color.rgb += noise(pos * 1000) * 0.01;
  }
);

// Structures

typedef struct { float x, y, z; } vector;
typedef struct { float m[16]; } matrix;
typedef struct { unsigned int id; int P, V, M, time, tex; } program;

// Math Functions

matrix getProjectionMatrix(int w, int h, float fov, float near, float far)
{
  return (matrix) { .m = {
    [0] = 1.0f / (tanf(fov * 3.14f / 180.0f / 2.0f) * w / h),
    [5] = 1.0f / tanf(fov * 3.14f / 180.0f / 2.0f),
    [10] = -(far + near) / (far - near),
    [11] = -1.0f,
    [14] = -(2.0f * far * near) / (far - near)
  }};
}

matrix getViewMatrix(float x, float y, float z, float a, float p)
{
  float cosy = cosf(a), siny = sinf(a), cosp = cosf(p), sinp = sinf(p);
  return (matrix) { .m = {
    cosy, siny * sinp, siny * cosp, 0.0f, 0.0f, cosp, -sinp, 0.0f,
    -siny, cosy * sinp, cosp * cosy, 0.0f, -(cosy * x - siny * z),
    -(siny * sinp * x + cosp * y + cosy * sinp * z),
    -(siny * cosp * x - sinp * y + cosp * cosy * z), 1.0f,
  }};
}

// OpenGL Helpers

program makeProgram(const char *vertexShaderSource,
                    const char *fragmentShaderSource)
{
  unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
  glCompileShader(vertexShader);

  unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
  glCompileShader(fragmentShader);

  unsigned int programId = glCreateProgram();
  glAttachShader(programId, vertexShader);
  glAttachShader(programId, fragmentShader);

  glLinkProgram(programId);
  int P = glGetUniformLocation(programId, "P");
  int V = glGetUniformLocation(programId, "V");
  int M = glGetUniformLocation(programId, "M");
  int time = glGetUniformLocation(programId, "time");
  int tex = glGetUniformLocation(programId, "tex");

  program p = { .id = programId, .P = P, .V = V, .M = M, .time = time, .tex = tex };

  glDetachShader(programId, vertexShader);
  glDetachShader(programId, fragmentShader);
  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  return p;
}

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

    unsigned int vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    program prog = makeProgram(skyVertShader, skyFragShader);

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
      matrix P = getProjectionMatrix(w, h, 65.0f, 1.0f, 1000.0f);
      matrix V = getViewMatrix(0.0f, 2.0f, -3.0f, 3.14f, 0.0f);

      // Renderer
      glViewport(0, 0, w, h);
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

      // Draw Scene
      glUseProgram(prog.id);
      glUniformMatrix4fv(prog.P, 1, GL_FALSE, P.m);
      glUniformMatrix4fv(prog.V, 1, GL_FALSE, V.m);
      glUniform1f(prog.time, timerCurrent - timerStart);

      glBindVertexArray(vao);
      glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

      // Finish Rendering
      glFlush();
      [context flushBuffer];
    }

    // Terminate
    IOPMAssertionRelease(assertionID);

    [app terminate:nil];
  }
}
