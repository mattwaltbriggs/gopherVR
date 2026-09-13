#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

/*
 * AppDelegate.m — Cocoa replacement for the Motif/Xt code in burrower.c
 *
 * Sets up NSWindow, menu bar, toolbar, 3D canvas, and status bar.
 * Drives the vogl/gopher render loop via an NSTimer.
 */

/* ------------------------------------------------------------------ */
/*  C function declarations from the existing GopherVR codebase        */
/* ------------------------------------------------------------------ */

/* lcube.c */
extern void InitialScene(void);
extern void PreloadObjects(void);
extern void Go_InitialView(void);

/* gopherto3d.c */
extern void WorldStart(char *host, int port, char *path);
extern void V_OpenSessionURL(char *title, char *url);

/* vogltools.c */
extern void drawscene(void);
extern void EyeInitialPoint(void);
extern void EyeAirJordan(void (*displayfunc)(void), float lookDownAmount,
                         float Moveahead, float Moveup, float seconds);
extern void EyeLocationUp(int GoUp);
extern void JumpOutofView(void (*displayfunc)(void));
extern void MotionSickness(void (*displayfunc)(void));
extern void RotateAboutAxis(float val);

/* eyemotion.h — from libvogl */
extern void EyeInit(void);
extern void EyeRotateX(float angle);
extern void EyeRotateY(float angle);
extern void EyeRotateZ(float angle);
extern void EyeTranslate(float x, float y, float z);

/* vogl core — from libvogl */
#include "vogl.h"

/* Cocoa vogl backend — libvogl/drivers/cocoa.m */
extern int  _Cocoa_devcpy(void);
extern void Cocoa_ResizeBuffers(int w, int h);
extern void Cocoa_SetMousePosition(int x, int y);
extern unsigned char *Cocoa_GetFrontBuffer(void);
extern int  Cocoa_GetBufferWidth(void);
extern int  Cocoa_GetBufferHeight(void);

/* vogl BSP / scene picking */
extern void sceneclick(int sceneid, int ScreenX, int ScreenY);

/* gopherto3d.c */
extern int  SelectGopherDir(void);
extern int  ClickToChoice(short x, short y);
extern char *ChoiceToString(int choice, int which);
extern void doSearch(char *text);
extern void V_OpenSessionURL(char *aCh_title, char *aCh_urltxt);

/* gophwin.c */
extern void V_GenMenuListWin(void);
extern void V_RememberListWinSize(void);

/* motiftools.c — stubs */
extern void StatusUpdate(char *msg);

/* text.c — stubs */
extern void GTXTcleanUpTextProc(void);
extern void displayTempFile(void *topLevel, char *title, char *fileName);
extern void displayTextString(void *topLevel, char *title, char *string);

/* burrower.c */
extern void jumpto(int x, int y);

/* globals.h */
extern float EYEzval;
extern float EYEyval;
extern float EYExval;
extern float EYEangle;
extern float EYEazimuth;
extern float SCENEaspect;
extern int   Bootstrapped;
extern char *INITIALhost;
extern int   INITIALport;
extern int   oursceneid;

/* ================================================================== */
/*  GVRCanvasView — custom NSView for the 3D viewport                  */
/* ================================================================== */

@implementation GVRCanvasView

- (BOOL)acceptsFirstResponder { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    if (_image) {
        [_image drawInRect:[self bounds]
                  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0
            respectFlipped:YES
                     hints:nil];
    } else {
        [[NSColor blackColor] setFill];
        NSRectFill(dirtyRect);
    }
}

/* --- Mouse events ------------------------------------------------- */

- (void)mouseDown:(NSEvent *)event {
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    self.isDragging = YES;
    self.dragStart = loc;

    if ([event clickCount] >= 2) {
        /* Double-click → jump to gopher object */
        /* Map view coords to viewport coords */
        NSRect bounds = [self bounds];
        float sx = (bounds.size.width > 1) ? (float)vdevice.sizeSx / bounds.size.width : 1.0f;
        float sy = (bounds.size.height > 1) ? (float)vdevice.sizeSy / bounds.size.height : 1.0f;
        int vx = (int)(loc.x * sx);
        int vy = (int)(loc.y * sy);
        jumpto(vx, vy);
        return;
    }

    /* Right-click → show info about clicked object */
    if ([event buttonNumber] == 2) {
        NSRect bounds = [self bounds];
        float sx = (bounds.size.width > 1) ? (float)vdevice.sizeSx / bounds.size.width : 1.0f;
        float sy = (bounds.size.height > 1) ? (float)vdevice.sizeSy / bounds.size.height : 1.0f;
        int choice = ClickToChoice((short)(loc.x * sx), (short)(loc.y * sy));
        if (choice >= 0) {
            char *desc = ChoiceToString(choice, 1);
            if (desc && self.delegate) {
                AppDelegate *app = (AppDelegate *)self.delegate;
                [app.statusLabel setStringValue:
                    [NSString stringWithUTF8String:desc]];
            }
        }
    }
}

- (void)mouseUp:(NSEvent *)event {
    (void)event;
    self.isDragging = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    if (!self.isDragging) return;
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];

    float canvasW = NSWidth([self bounds]);
    float canvasH = NSHeight([self bounds]);
    if (canvasW <= 0 || canvasH <= 0) return;

    float dx = (float)(self.dragStart.x - loc.x) / canvasW;
    float dy = (float)(loc.y - self.dragStart.y) / canvasH;

    EYEangle += 20.0 * dx;
    EYEzval   = dy * 200.0;

    drawscene();
}

- (void)rightMouseDown:(NSEvent *)event {
    [self mouseDown:event];
}

- (void)rightMouseUp:(NSEvent *)event {
    [self mouseUp:event];
}

- (void)rightMouseDragged:(NSEvent *)event {
    [self mouseDragged:event];
}

/* --- Keyboard events ---------------------------------------------- */

- (void)keyDown:(NSEvent *)event {
    NSString *chars = [event characters];
    if ([chars length] == 0) return;
    unichar ch = [chars characterAtIndex:0];

    switch (ch) {
        case '[':
            EyeLocationUp(1);
            break;
        case ']':
            EyeLocationUp(0);
            break;
        case ' ':
            EyeAirJordan(drawscene, 7.0, 0.0, 1400.0, 24.0);
            break;
        default:
            [super keyDown:event];
            return;
    }
    drawscene();
}

@end

/* ================================================================== */
/*  AppDelegate                                                        */
/* ================================================================== */

@implementation AppDelegate

/* ================================================================== */
/*  Application lifecycle                                              */
/* ================================================================== */

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    /* ---- main window ---- */
    NSRect frame = NSMakeRect(200, 200, 800, 600);
    self.mainWindow = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable |
                             NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [self.mainWindow setTitle:@"Gopher VR"];
    [self.mainWindow setDelegate:(id)self];
    [self.mainWindow setAcceptsMouseMovedEvents:YES];

    NSView *contentView = [self.mainWindow contentView];

    /* ---- menu bar ---- */
    [self buildMenuBar];

    /* ---- layout constants ---- */
    float toolbarH = 32.0;
    float statusH  = 22.0;
    float canvasW  = NSWidth(frame);
    float canvasH  = NSHeight(frame) - toolbarH - statusH;

    /* ---- toolbar ---- */
    NSView *toolbarView = [[NSView alloc]
        initWithFrame:NSMakeRect(0, 0, canvasW, toolbarH)];
    [toolbarView setAutoresizingMask:NSViewWidthSizable];

    self.btnRotateLeft  = [self toolbarButton:@"\u25C0" action:@selector(rotateLeft:)];
    [self.btnRotateLeft setFrame:NSMakeRect(4, 4, 28, 24)];

    self.btnForward     = [self toolbarButton:@"\u25B2" action:@selector(forward:)];
    [self.btnForward setFrame:NSMakeRect(36, 4, 28, 24)];

    self.btnRotateRight = [self toolbarButton:@"\u25B6" action:@selector(rotateRight:)];
    [self.btnRotateRight setFrame:NSMakeRect(68, 4, 28, 24)];

    [toolbarView addSubview:self.btnRotateLeft];
    [toolbarView addSubview:self.btnForward];
    [toolbarView addSubview:self.btnRotateRight];

    /* ---- status label ---- */
    self.statusLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(0, toolbarH, canvasW, statusH)];
    [self.statusLabel setEditable:NO];
    [self.statusLabel setBordered:NO];
    [self.statusLabel setDrawsBackground:NO];
    [self.statusLabel setFont:[NSFont systemFontOfSize:11]];
    [self.statusLabel setStringValue:@"GopherVR \u2014 ready"];
    [self.statusLabel setAutoresizingMask:NSViewWidthSizable];

    /* ---- 3D canvas (custom NSView) ---- */
    self.canvas = [[GVRCanvasView alloc]
        initWithFrame:NSMakeRect(0, toolbarH + statusH, canvasW, canvasH)];
    [self.canvas setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self.canvas setDelegate:self];

    [contentView addSubview:self.canvas];
    [contentView addSubview:self.statusLabel];
    [contentView addSubview:toolbarView];

    /* ---- initialise vogl Cocoa backend ---- */
    _Cocoa_devcpy();
    vdevice.devname = "Cocoa";

    /* ---- load saved window position ---- */
    [self loadWindowPosition];

    /* ---- gopher library init ---- */
    INITIALhost = "gopher.floodgap.com";
    INITIALport = 70;

    PreloadObjects();
    InitialScene();
    V_GenMenuListWin();
    Bootstrapped = 2;

    [self.mainWindow makeKeyAndOrderFront:nil];

    /* ---- resize buffers to match actual window size ---- */
    {
        NSRect content = [[self.mainWindow contentView] bounds];
        int w = (int)content.size.width;
        int h = (int)content.size.height - 54;
        if (h < 1) h = 1;
        SCENEaspect = (float)w / (float)h;
        Cocoa_ResizeBuffers(w, h);
        reshapeviewport();
        drawscene();
    }

    /* ---- start render timer at ~30 fps ---- */
    self.renderTimer =
        [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                         target:self
                                       selector:@selector(renderFrame)
                                       userInfo:nil
                                        repeats:YES];

    /* ---- bootstrap Gopher connection on background thread ---- */
    self.bootstrapping = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PreloadObjects();
        WorldStart(INITIALhost, INITIALport, "");
        dispatch_async(dispatch_get_main_queue(), ^{
            self.bootstrapping = NO;
            [self.statusLabel setStringValue:
                [NSString stringWithFormat:@"Connected to %s:%d",
                        INITIALhost, INITIALport]];
            drawscene();
            extern void MenuShowGopherMenu(void);
            MenuShowGopherMenu();
        });
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    (void)app;
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.renderTimer invalidate];
    [self saveWindowPosition];
    GTXTcleanUpTextProc();
}

/* ================================================================== */
/*  Menu bar                                                           */
/* ================================================================== */

- (void)buildMenuBar {
    NSMenu *menubar = [[NSMenu alloc] init];

    /* File */
    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Show Gopher Menu\u2026"
                        action:@selector(showGopherMenu:)
                 keyEquivalent:@"m"];
    [fileMenu addItemWithTitle:@"Reload Gopher Menu"
                        action:@selector(reloadGopherMenu:)
                 keyEquivalent:@"r"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Open Location\u2026"
                        action:@selector(openLocation:)
                 keyEquivalent:@"o"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Quit"
                        action:@selector(terminate:)
                 keyEquivalent:@"q"];
    [fileItem setSubmenu:fileMenu];
    [menubar addItem:fileItem];

    /* Edit */
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copySelection:)
                 keyEquivalent:@"c"];
    [editItem setSubmenu:editMenu];
    [menubar addItem:editItem];

    /* Navigate */
    NSMenuItem *navItem = [[NSMenuItem alloc] init];
    NSMenu *navMenu = [[NSMenu alloc] initWithTitle:@"Navigate"];
    [navMenu addItemWithTitle:@"Initial Viewpoint"
                       action:@selector(initialViewpoint:)
                keyEquivalent:@"i"];
    [navMenu addItemWithTitle:@"Overview"
                       action:@selector(showOverview:)
                keyEquivalent:@" "];
    [navMenu addItem:[NSMenuItem separatorItem]];
    [navMenu addItemWithTitle:@"Jump Forward"
                       action:@selector(jumpForward:)
                keyEquivalent:@""];
    [navMenu addItemWithTitle:@"Jump Up"
                       action:@selector(jumpUp:)
                keyEquivalent:@""];
    [navMenu addItem:[NSMenuItem separatorItem]];
    [navMenu addItemWithTitle:@"Up"
                       action:@selector(moveUp:)
                keyEquivalent:@"["];
    [navMenu addItemWithTitle:@"Down"
                       action:@selector(moveDown:)
                keyEquivalent:@"]"];
    [navItem setSubmenu:navMenu];
    [menubar addItem:navItem];

    /* Help */
    NSMenuItem *helpItem = [[NSMenuItem alloc] init];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu addItemWithTitle:@"About GopherVR"
                        action:@selector(showAbout:)
                 keyEquivalent:@""];
    [helpMenu addItemWithTitle:@"Help Topics"
                        action:@selector(showHelp:)
                 keyEquivalent:@"?"];
    [helpItem setSubmenu:helpMenu];
    [menubar addItem:helpItem];

    [NSApp setMainMenu:menubar];
}

/* ================================================================== */
/*  Toolbar                                                            */
/* ================================================================== */

- (NSButton *)toolbarButton:(NSString *)title action:(SEL)action {
    NSButton *btn = [[NSButton alloc] init];
    [btn setTitle:title];
    [btn setBezelStyle:NSBezelStyleRounded];
    [btn setTarget:self];
    [btn setAction:action];
    [btn setContinuous:YES];
    return btn;
}

/* ================================================================== */
/*  Render loop                                                        */
/* ================================================================== */

- (void)renderFrame {
    if (self.bootstrapping) return;

    drawscene();

    unsigned char *pixels = Cocoa_GetFrontBuffer();
    if (!pixels) return;

    int w = (int)Cocoa_GetBufferWidth();
    int h = (int)Cocoa_GetBufferHeight();
    if (w <= 0 || h <= 0) return;

    int canvasW = (int)NSWidth([self.canvas bounds]);
    int canvasH = (int)NSHeight([self.canvas bounds]);
    if (canvasW <= 0 || canvasH <= 0) return;

    /* Copy pixels — vogl cocoa driver already renders top-to-bottom */
    int rowBytes = w * 4;
    NSBitmapImageRep *rep =
        [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL
                          pixelsWide:w
                          pixelsHigh:h
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSCalibratedRGBColorSpace
                         bytesPerRow:rowBytes
                        bitsPerPixel:32];
    unsigned char *dst = [rep bitmapData];
    memcpy(dst, pixels, rowBytes * h);

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
    [image addRepresentation:rep];

    /* Draw the rendered image into the canvas view */
    [self.canvas setImage:image];
    [self.canvas setNeedsDisplay:YES];
}

/* ================================================================== */
/*  Window save / load                                                 */
/* ================================================================== */

- (void)loadWindowPosition {
    const char *home = getenv("HOME");
    if (!home) return;
    char path[256];
    snprintf(path, sizeof(path), "%s/.gophervrwindows", home);
    FILE *fp = fopen(path, "r");
    if (!fp) return;
    int x, y, w, h, mx, my, mw, mh;
    if (fscanf(fp, "%d %d %d %d %d %d %d %d",
               &x, &y, &w, &h, &mx, &my, &mw, &mh) == 8) {
        [self.mainWindow setFrameOrigin:NSMakePoint(x, y)];
        [self.mainWindow setContentSize:NSMakeSize(w, h)];
    }
    fclose(fp);
}

- (void)saveWindowPosition {
    const char *home = getenv("HOME");
    if (!home) return;
    V_RememberListWinSize();
    char path[256];
    snprintf(path, sizeof(path), "%s/.gophervrwindows", home);
    NSRect frame = [self.mainWindow frame];
    NSRect content = [[self.mainWindow contentView] bounds];
    FILE *fp = fopen(path, "w");
    if (!fp) return;
    fprintf(fp, "%d %d %d %d\n",
            (int)frame.origin.x, (int)frame.origin.y,
            (int)content.size.width, (int)content.size.height);
    fclose(fp);
}

/* ================================================================== */
/*  Menu actions                                                       */
/* ================================================================== */

- (IBAction)showGopherMenu:(id)sender {
    (void)sender;
    extern void MenuShowGopherMenu(void);
    MenuShowGopherMenu();
}

- (IBAction)reloadGopherMenu:(id)sender {
    (void)sender;
    extern void ReloadCurrentDir(void);
    ReloadCurrentDir();
}

- (IBAction)openLocation:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Open Location"];
    [alert setInformativeText:@"Enter a Gopher URL:"];
    NSTextField *input = [[NSTextField alloc]
        initWithFrame:NSMakeRect(0, 0, 300, 24)];
    [input setStringValue:@"gopher://gopher.floodgap.com/"];
    [alert setAccessoryView:input];
    [alert addButtonWithTitle:@"Open"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        char *url = strdup([[input stringValue] UTF8String]);
        self.bootstrapping = YES;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            V_OpenSessionURL(url, url);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.bootstrapping = NO;
                drawscene();
                free(url);
            });
        });
    }
}

- (IBAction)copySelection:(id)sender {
    (void)sender;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:[self.statusLabel stringValue] forType:NSPasteboardTypeString];
}

- (IBAction)initialViewpoint:(id)sender { (void)sender; Go_InitialView(); }

- (IBAction)showOverview:(id)sender {
    (void)sender;
    EyeAirJordan(drawscene, 7.0, 0.0, 1400.0, 24.0);
}

- (IBAction)jumpForward:(id)sender {
    (void)sender;
    EyeAirJordan(drawscene, 0.5, 150.0, 200.0, 3.0);
}

- (IBAction)jumpUp:(id)sender {
    (void)sender;
    EyeAirJordan(drawscene, 0.0, 0.0, 1400.0, 24.0);
}

- (IBAction)moveUp:(id)sender   { (void)sender; EyeLocationUp(1); }
- (IBAction)moveDown:(id)sender { (void)sender; EyeLocationUp(0); }

- (IBAction)showAbout:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"GopherVR v0.5.1"];
    [alert setInformativeText:
        @"\u00A9 Copyright 1995\u20132015 The Regents of the\n"
         "University of Minnesota and others\n\n"
         "Rendering Engine:\n"
         "  Neophytos Iacovou, Mark McCahill, Paul Lindner\n\n"
         "Application:\n"
         "  Paul Lindner, Neophytos Iacovou, Cameron Kaiser\n\n"
         "Visit Floodgap: gopher.floodgap.com"];
    [alert runModal];
}

- (IBAction)showHelp:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Help"];
    [alert setInformativeText:@"Help system not yet ported to Cocoa."];
    [alert runModal];
}

- (IBAction)bookmarksPanel:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Bookmarks"];
    [alert setInformativeText:@"Bookmarks not yet implemented."];
    [alert runModal];
}

- (IBAction)addBookmark:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Bookmarks"];
    [alert setInformativeText:@"Bookmark added (stub)."];
    [alert runModal];
}

/* ================================================================== */
/*  Toolbar actions (continuous)                                       */
/* ================================================================== */

- (IBAction)rotateLeft:(id)sender {
    (void)sender;
    EYEangle += 15.0;
    drawscene();
}

- (IBAction)rotateRight:(id)sender {
    (void)sender;
    EYEangle -= 15.0;
    drawscene();
}

- (IBAction)forward:(id)sender {
    (void)sender;
    EYEzval = 50.0;
    drawscene();
}

/* ================================================================== */
/*  Window delegate — resize                                           */
/* ================================================================== */

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    if (!Bootstrapped) return;
    NSRect content = [[self.mainWindow contentView] bounds];
    int w = (int)content.size.width;
    int h = (int)content.size.height - 54;
    if (h < 1) h = 1;
    SCENEaspect = (float)w / (float)h;
    Cocoa_ResizeBuffers(w, h);
    reshapeviewport();
    drawscene();
}

@end
