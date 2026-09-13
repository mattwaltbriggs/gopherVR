/*
 * AppDelegate.h
 *
 * GopherVR Cocoa application delegate.
 * Replaces the Motif/Xt widget tree from burrower.c.
 */

#import <Cocoa/Cocoa.h>

/* ------------------------------------------------------------------ */
/*  GVRCanvasView — custom NSView for the 3D viewport                  */
/*  Handles mouse drag for rotation/movement and keyboard events.      */
/* ------------------------------------------------------------------ */

@interface GVRCanvasView : NSView

@property (assign) id delegate;
@property (assign) BOOL isDragging;
@property (assign) NSPoint dragStart;
@property (strong) NSImage *image;

@end

/* ------------------------------------------------------------------ */
/*  AppDelegate                                                        */
/* ------------------------------------------------------------------ */

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) NSWindow    *mainWindow;
@property (strong) GVRCanvasView *canvas;
@property (strong) NSTextField *statusLabel;
@property (strong) NSTimer     *renderTimer;
@property (assign) BOOL         bootstrapping;

/* toolbar buttons */
@property (strong) NSButton *btnRotateLeft;
@property (strong) NSButton *btnForward;
@property (strong) NSButton *btnRotateRight;

@end
