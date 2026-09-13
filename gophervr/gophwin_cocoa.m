/*
 * gophwin_cocoa.m
 *
 * Cocoa implementation of the Gopher Menu window (replaces gophwin.c).
 * This is a separate NSWindow that shows:
 *   - History list (recent Gopher sites)
 *   - Title button (click to go up a level)
 *   - Menu list (current directory's items)
 *   - Abstract text area
 */

#import <Cocoa/Cocoa.h>

/* ------------------------------------------------------------------ */
/*  C function declarations                                            */
/* ------------------------------------------------------------------ */

extern void V_SelMenuItem(int N_item);
extern int  B_GetAbstract(int N_item, char **aCh_abs);
extern void V_PopDirectory(void);
extern void V_AfterHistory(void);

/* Global widget stubs (referenced by other files via extern) */
void *top = NULL;
void *Wig_top2 = NULL;

/* Window geometry globals */
int menuwin_w = 400;
int menuwin_h = 500;
int menuwin_x = 100;
int menuwin_y = 100;

/* ------------------------------------------------------------------ */
/*  GopherMenuWindowController                                         */
/* ------------------------------------------------------------------ */

@interface GopherMenuWindowController : NSWindowController
    <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (strong) NSTableView *historyTable;
@property (strong) NSTableView *menuTable;
@property (strong) NSButton    *titleButton;
@property (strong) NSScrollView *abstractScroll;
@property (strong) NSTextView  *abstractText;
@property (strong) NSMutableArray *historyItems;
@property (strong) NSMutableArray *menuItems;
@property (assign) int caCh_entries;
@end

@implementation GopherMenuWindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(menuwin_x, menuwin_y, menuwin_w, menuwin_h);
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable |
                             NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [win setTitle:@"Gopher Menu"];
    [win setDelegate:(id)self];
    [win setReleasedWhenClosed:NO];

    self = [super initWithWindow:win];
    if (self) {
        _historyItems = [NSMutableArray array];
        _menuItems = [NSMutableArray array];
        _caCh_entries = 0;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSView *content = [[self window] contentView];
    float totalH = NSHeight([content bounds]);

    /* ---- Abstract text (bottom, 3 rows) ---- */
    float absH = 60;
    _abstractScroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, 0, menuwin_w, absH)];
    [_abstractScroll setHasVerticalScroller:YES];
    [_abstractScroll setBorderType:NSBezelBorder];
    _abstractText = [[NSTextView alloc]
        initWithFrame:[_abstractScroll bounds]];
    [_abstractText setEditable:NO];
    [_abstractText setFont:[NSFont userFixedPitchFontOfSize:11]];
    [_abstractScroll setDocumentView:_abstractText];
    [_abstractScroll setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [content addSubview:_abstractScroll];

    /* ---- Menu list (middle) ---- */
    float menuH = totalH - 28 - 30 - absH;
    NSScrollView *menuScroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, absH, menuwin_w, menuH)];
    [menuScroll setHasVerticalScroller:YES];
    [menuScroll setBorderType:NSBezelBorder];
    [menuScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    _menuTable = [[NSTableView alloc] initWithFrame:[[menuScroll contentView] bounds]];
    NSTableColumn *menuCol = [[NSTableColumn alloc] initWithIdentifier:@"menu"];
    [[menuCol headerCell] setStringValue:@"Menu Items"];
    [menuCol setWidth:menuwin_w - 20];
    [_menuTable addTableColumn:menuCol];
    [_menuTable setDataSource:self];
    [_menuTable setDelegate:self];
    [_menuTable setDoubleAction:@selector(menuItemDoubleClicked:)];
    [_menuTable setTarget:self];
    [menuScroll setDocumentView:_menuTable];
    [content addSubview:menuScroll];

    /* ---- Title button (go up) ---- */
    float titleY = absH + menuH;
    _titleButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(0, titleY, menuwin_w, 28)];
    [_titleButton setTitle:@"Gopher VR"];
    [_titleButton setBezelStyle:NSBezelStyleRounded];
    [_titleButton setTarget:self];
    [_titleButton setAction:@selector(titleButtonClicked:)];
    [_titleButton setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [content addSubview:_titleButton];

    /* ---- History list (top) ---- */
    float histH = 80;
    float histY = titleY + 28;
    NSScrollView *histScroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, histY, menuwin_w, histH)];
    [histScroll setHasVerticalScroller:YES];
    [histScroll setBorderType:NSBezelBorder];
    [histScroll setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    _historyTable = [[NSTableView alloc] initWithFrame:[[histScroll contentView] bounds]];
    NSTableColumn *histCol = [[NSTableColumn alloc] initWithIdentifier:@"hist"];
    [[histCol headerCell] setStringValue:@"History"];
    [histCol setWidth:menuwin_w - 20];
    [_historyTable addTableColumn:histCol];
    [_historyTable setDataSource:self];
    [_historyTable setDelegate:self];
    [_historyTable setDoubleAction:@selector(historyDoubleClicked:)];
    [_historyTable setTarget:self];
    [histScroll setDocumentView:_historyTable];
    [content addSubview:histScroll];
}

/* ------------------------------------------------------------------ */
/*  Table View Data Source                                             */
/* ------------------------------------------------------------------ */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == _historyTable)
        return (NSInteger)[_historyItems count];
    if (tableView == _menuTable)
        return (NSInteger)[_menuItems count];
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    if (tableView == _historyTable && row < (NSInteger)[_historyItems count])
        return _historyItems[(NSUInteger)row];
    if (tableView == _menuTable && row < (NSInteger)[_menuItems count])
        return _menuItems[(NSUInteger)row];
    return nil;
}

/* ------------------------------------------------------------------ */
/*  Selection handlers                                                 */
/* ------------------------------------------------------------------ */

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tv = [notification object];
    NSInteger row = [tv selectedRow];
    if (row < 0) return;

    if (tv == _menuTable) {
        /* Update abstract text */
        char *abs = NULL;
        if (B_GetAbstract((int)row + 1, &abs) && abs) {
            [_abstractText setString:[NSString stringWithUTF8String:abs]];
            free(abs);
        } else {
            [_abstractText setString:@""];
        }
    }
}

- (void)menuItemDoubleClicked:(id)sender {
    NSInteger row = [_menuTable clickedRow];
    if (row >= 0) {
        V_SelMenuItem((int)row + 1);
    }
}

- (void)historyDoubleClicked:(id)sender {
    NSInteger row = [_historyTable clickedRow];
    if (row < 0) return;
    if (row == (NSInteger)self.caCh_entries - 1) return;
    if (self.caCh_entries == 1 && row == 0) return;

    /* Pop back to the selected history entry */
    int entriesToPop = (int)self.caCh_entries - (int)row - 1;
    for (int i = 0; i < entriesToPop; i++) {
        V_PopDirectory();
        /* V_DestroyHistoryData will be called from the C side */
    }
    V_AfterHistory();
}

- (void)titleButtonClicked:(id)sender {
    (void)sender;
    if (self.caCh_entries <= 1) return;
    V_SelMenuItem(0);
}

/* ------------------------------------------------------------------ */
/*  Window delegate                                                    */
/* ------------------------------------------------------------------ */

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    /* Remember geometry */
    NSRect frame = [[self window] frame];
    menuwin_x = (int)frame.origin.x;
    menuwin_y = (int)frame.origin.y;
    menuwin_w = (int)frame.size.width;
    menuwin_h = (int)frame.size.height;
    Wig_top2 = NULL;
}

@end

/* ------------------------------------------------------------------ */
/*  Global controller (C-accessible)                                   */
/* ------------------------------------------------------------------ */

static GopherMenuWindowController *g_menuController = nil;

/* ------------------------------------------------------------------ */
/*  C functions called by the GopherVR C codebase                      */
/* ------------------------------------------------------------------ */

extern void V_GenMenuListing(char *aCh_text, int N_pos);
extern void V_DelMenuListing(void);
extern void V_SetMenuTitle(char *aCh_title);
extern void V_GenHistListing(char *aCh_title, char *aCh_url);
extern void V_DestroyHistoryData(void);
extern void V_RememberListWinSize(void);
extern void V_CloseListWin(void *w, void *client_data, void *cbs);
extern void V_ResizeMenuWin(void *w, void *client_data, void *event, void *crap);
extern void V_AddStringToList(char *s, int indent);
extern int  mynewsize(int height);

static int local_caCh_entries = 0;

void V_GenMenuListWin(void)
{
    if (Wig_top2 != NULL) return;

    g_menuController = [[GopherMenuWindowController alloc] init];
    Wig_top2 = (void *)CFBridgingRetain(g_menuController);
    [[g_menuController window] setDelegate:g_menuController];
    [[g_menuController window] makeKeyAndOrderFront:nil];
}

void V_GenMenuListing(char *aCh_text, int N_pos)
{
    if (!g_menuController) return;
    GopherMenuWindowController *ctrl = g_menuController;
    NSString *text = aCh_text ? [NSString stringWithUTF8String:aCh_text] : @"";
    if (!text) text = @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        [ctrl.menuItems addObject:text];
        [ctrl.menuTable reloadData];
    });
}

void V_DelMenuListing(void)
{
    if (!g_menuController) return;
    GopherMenuWindowController *ctrl = g_menuController;
    dispatch_async(dispatch_get_main_queue(), ^{
        [ctrl.menuItems removeAllObjects];
        [ctrl.menuTable reloadData];
    });
}

void V_SetMenuTitle(char *aCh_title)
{
    if (!g_menuController) return;
    GopherMenuWindowController *ctrl = g_menuController;
    NSString *title = [NSString stringWithUTF8String:aCh_title ? aCh_title : "Gopher VR"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [ctrl.titleButton setTitle:title];
    });
}

extern void V_GenHistUrlListing(char *aCh_url);

void V_GenHistListing(char *aCh_title, char *aCh_url)
{
    if (!g_menuController) return;
    GopherMenuWindowController *ctrl = g_menuController;
    V_GenHistUrlListing(aCh_url);
    local_caCh_entries++;
    ctrl.caCh_entries = local_caCh_entries;
    NSString *title = [NSString stringWithUTF8String:aCh_title ? aCh_title : ""];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *indented = [@"" stringByPaddingToLength:(local_caCh_entries)
                                               withString:@" "
                                          startingAtIndex:0];
        indented = [indented stringByAppendingString:title];
        [ctrl.historyItems addObject:indented];
        [ctrl.historyTable reloadData];
        NSInteger lastRow = [ctrl.historyItems count] - 1;
        if (lastRow >= 0) {
            [ctrl.historyTable scrollRowToVisible:lastRow];
        }
    });
}

void V_DestroyHistoryData(void)
{
    if (!g_menuController) return;
    if (local_caCh_entries <= 1) return;
    local_caCh_entries--;
    g_menuController.caCh_entries = local_caCh_entries;
    GopherMenuWindowController *ctrl = g_menuController;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([ctrl.historyItems count] > 0) {
            [ctrl.historyItems removeLastObject];
            [ctrl.historyTable reloadData];
        }
    });
}

void V_RememberListWinSize(void)
{
    /* Geometry is saved in windowWillClose */
}

void V_CloseListWin(void *w, void *client_data, void *cbs)
{
    (void)w; (void)client_data; (void)cbs;
    if (g_menuController) {
        GopherMenuWindowController *ctrl = g_menuController;
        dispatch_async(dispatch_get_main_queue(), ^{
            [ctrl.window close];
        });
    }
}

void V_ResizeMenuWin(void *w, void *client_data, void *event, void *crap)
{
    (void)w; (void)client_data; (void)event; (void)crap;
    /* Not needed in Cocoa — autoresizing handles this */
}

void V_AddStringToList(char *s, int indent)
{
    if (!g_menuController || !s) return;
    GopherMenuWindowController *ctrl = g_menuController;
    NSString *str = [NSString stringWithUTF8String:s];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *spaces = [@"" stringByPaddingToLength:indent
                                             withString:@" "
                                        startingAtIndex:0];
        NSString *indented = [spaces stringByAppendingString:str];
        [ctrl.historyItems addObject:indented];
        [ctrl.historyTable reloadData];
    });
}

int mynewsize(int height)
{
    int newsize = 15 + ((height - 460) / 18);
    if (newsize < 1) newsize = 1;
    return newsize;
}
