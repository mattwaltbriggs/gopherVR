/*
 * cocoa_dialogs.m
 *
 * Native Cocoa replacements for Motif/Xt dialog functions that need
 * real GUI implementations. Functions that are just no-ops remain in
 * the C stub files.
 */

#import <Cocoa/Cocoa.h>

/* Define Motif types so dialogs.h compiles */
typedef void *Widget;
typedef void *XtPointer;

#include "guidefs.h"
#include "dialogs.h"

/* Forward declarations of C functions we call */
extern void doSearch(char *text);
extern void drawscene(void);
extern void V_OpenSessionURL(char *aCh_title, char *aCh_urltxt);
extern int stale_fps;

/* ================================================================== */
/*  Text display window                                                */
/* ================================================================== */

static NSMutableArray *g_textWindows = nil;

@interface GVRTextWindow : NSObject
@property (strong) NSWindow *window;
@property (strong) NSTextView *textView;
@property (assign) BOOL deleteFile;
@property (copy)   NSString *displayedFile;
@end

@implementation GVRTextWindow
@end

static GVRTextWindow *createTextWindow(NSString *title)
{
    if (!g_textWindows) g_textWindows = [NSMutableArray array];

    GVRTextWindow *tw = [[GVRTextWindow alloc] init];

    NSScrollView *scrollView = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, 0, 600, 400)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    tw.textView = [[NSTextView alloc]
        initWithFrame:[[scrollView contentView] bounds]];
    [tw.textView setMinSize:NSMakeSize(0.0, 0.0)];
    [tw.textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [tw.textView setVerticallyResizable:YES];
    [tw.textView setHorizontallyResizable:YES];
    [[tw.textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[tw.textView textContainer] setWidthTracksTextView:NO];
    [tw.textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [tw.textView setEditable:NO];

    [scrollView setDocumentView:tw.textView];

    NSRect contentRect = NSMakeRect(0, 0, 600, 400);
    NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    tw.window = [[NSWindow alloc] initWithContentRect:contentRect
                                            styleMask:styleMask
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
    [tw.window setTitle:title ?: @"GopherVR"];
    [[tw.window contentView] addSubview:scrollView];
    [tw.window setReleasedWhenClosed:NO];

    [g_textWindows addObject:tw];
    return tw;
}

/* ================================================================== */
/*  popuptextfile — display a temp file in a text window               */
/* ================================================================== */

void popuptextfile(char *title, char *tempfile)
{
    if (!tempfile) return;
    NSString *nsTitle = title ? [NSString stringWithUTF8String:title] : @"GopherVR";
    NSString *nsFile  = [NSString stringWithUTF8String:tempfile];

    NSString *content = [NSString stringWithContentsOfFile:nsFile
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    if (!content) {
        content = [NSString stringWithContentsOfFile:nsFile
                                            encoding:NSISOLatin1StringEncoding
                                               error:nil];
    }
    if (!content) {
        fprintf(stderr, "popuptextfile: cannot read %s\n", tempfile);
        return;
    }

    GVRTextWindow *tw = createTextWindow(nsTitle);
    tw.deleteFile = YES;
    tw.displayedFile = nsFile;
    [tw.textView setString:content];
    [tw.window makeKeyAndOrderFront:nil];
}

/* ================================================================== */
/*  displayTempFile — show a temp file in a text window                */
/* ================================================================== */

void displayTempFile(void *topLevel, char *title, char *fileName)
{
    (void)topLevel;
    popuptextfile(title, fileName);
}

/* ================================================================== */
/*  displayIndexTempFile — show indexed temp file                      */
/* ================================================================== */

void displayIndexTempFile(void *topLevel, char *title,
                          char *fileName, char *indexString)
{
    (void)topLevel;
    (void)indexString;
    popuptextfile(title, fileName);
}

/* ================================================================== */
/*  displayTextString — show an in-memory string in a text window      */
/* ================================================================== */

void displayTextString(void *topLevel, char *title, char *string)
{
    (void)topLevel;
    if (!string) return;
    NSString *nsTitle = title ? [NSString stringWithUTF8String:title] : @"GopherVR";
    NSString *nsString = [NSString stringWithUTF8String:string];

    GVRTextWindow *tw = createTextWindow(nsTitle);
    tw.deleteFile = NO;
    [tw.textView setString:nsString];
    [tw.window makeKeyAndOrderFront:nil];
}

/* ================================================================== */
/*  popupsearchdeally — show a search input dialog                     */
/* ================================================================== */

void popupsearchdeally(char *title)
{
    if (!title) return;
    NSString *nsTitle = [NSString stringWithUTF8String:title];
    NSString *prompt = [NSString stringWithFormat:@"Search \u2018%@\u2019 for:", nsTitle];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Gopher Search"];
    [alert setInformativeText:prompt];

    NSTextField *input = [[NSTextField alloc]
        initWithFrame:NSMakeRect(0, 0, 300, 24)];
    [input setStringValue:@""];
    [alert setAccessoryView:input];
    [alert addButtonWithTitle:@"Search"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        const char *text = [[input stringValue] UTF8String];
        if (text && strlen(text) > 0) {
            char *searchText = strdup(text);
            dispatch_async(
                dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    doSearch(searchText);
                    free(searchText);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        drawscene();
                    });
                });
        }
    }
}

/* ================================================================== */
/*  Errormsg — show error dialog                                       */
/* ================================================================== */

void Errormsg(char *message)
{
    if (!message) return;
    NSString *nsMsg = [NSString stringWithUTF8String:message];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSAlertStyleCritical];
        [alert setMessageText:@"GopherVR Error"];
        [alert setInformativeText:nsMsg];
        [alert runModal];
    });
}

/* ================================================================== */
/*  StatusUpdate — update the status bar                               */
/* ================================================================== */

void StatusUpdate(char *msg)
{
    if (!msg) return;
    stale_fps = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *nsMsg = [NSString stringWithUTF8String:msg];
        NSWindow *keyWin = [NSApp keyWindow];
        if (keyWin) {
            /* Try to find a status label in the window */
            for (NSView *v in [[keyWin contentView] subviews]) {
                if ([v isKindOfClass:[NSTextField class]]) {
                    NSTextField *tf = (NSTextField *)v;
                    if ([[tf identifier] isEqualToString:@"statusLabel"]) {
                        [tf setStringValue:nsMsg];
                        return;
                    }
                }
            }
        }
    });
}

void StatusNew(void *parent, char *msg)
{
    (void)parent;
    StatusUpdate(msg);
}

/* ================================================================== */
/*  V_OpenGeneralDiag — URL or Search input dialog                     */
/* ================================================================== */

void V_OpenGeneralDiag(void *widget, void *client_data, void *call_data)
{
    (void)widget; (void)call_data;
    int index = (int)(intptr_t)client_data;

    const char *label = NULL;
    const char *placeholder = NULL;

    if (index == d_URL) {
        label = "Enter a URL:";
        placeholder = "gopher://gopher.floodgap.com/";
    } else if (index == d_SEARCH) {
        label = "Search items for:";
        placeholder = "";
    } else {
        return;
    }

    NSString *nsLabel = [NSString stringWithUTF8String:label];
    NSString *nsPH = [NSString stringWithUTF8String:placeholder];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"GopherVR"];
    [alert setInformativeText:nsLabel];

    NSTextField *input = [[NSTextField alloc]
        initWithFrame:NSMakeRect(0, 0, 300, 24)];
    [input setStringValue:nsPH];
    [alert setAccessoryView:input];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        char *text = strdup([[input stringValue] UTF8String]);
        if (index == d_URL) {
            V_OpenSessionURL(text, text);
            free(text);
        } else if (index == d_SEARCH) {
            doSearch(text);
            free(text);
            drawscene();
        }
    }
}

/* ================================================================== */
/*  V_OpenTwoEntryDiag — FTP host + selector dialog                    */
/* ================================================================== */

void V_OpenTwoEntryDiag(void *widget, void *client_data, void *call_data)
{
    (void)widget; (void)call_data;
    int index = (int)(intptr_t)client_data;

    if (index != d_FTP) return;

    Errormsg("FTP not yet implemented in Cocoa port.");
}

/* ================================================================== */
/*  f_V_URL_ok / f_V_SEARCH_ok / f_V_FTP_ok                           */
/* ================================================================== */

void f_V_URL_ok(void *w, void *client_data, void *call_data)
{
    (void)w; (void)call_data;
    char *text = (char *)client_data;
    if (text) {
        V_OpenSessionURL(text, text);
        free(text);
    }
}

void f_V_SEARCH_ok(void *w, void *client_data, void *call_data)
{
    (void)w; (void)call_data;
    char *text = (char *)client_data;
    if (text) {
        doSearch(text);
        free(text);
        drawscene();
    }
}

void f_V_FTP_ok(void *w, void *client_data, void *call_data)
{
    (void)w; (void)call_data;
    Errormsg("FTP not yet implemented in Cocoa port.");
    if (client_data) free(client_data);
}
