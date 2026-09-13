/*
 * stub_motiftools.c
 * Stub implementations for motiftools.c functions.
 * Errormsg, StatusNew, StatusUpdate are now in cocoa_dialogs.m.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void *Widget;
typedef void *XtPointer;
typedef int Boolean;

/*
 * Global variables referenced by other files.
 */
void *Colors = NULL;
int ncolors = 0;

int stale_fps = 0;

/*
 * Busy indicator stubs
 */
void
BusyThingNew(Widget parent)
{
    (void)parent;
}

void
BusyUpdate(void)
{
}

/*
 * Menu callbacks
 */
void
MenuQuit_CB(Widget w, XtPointer menuitem, XtPointer call_data)
{
    (void)w; (void)menuitem; (void)call_data;
    exit(0);
}

void
MenuNewDocument(Widget w, XtPointer menuitem, XtPointer call_data)
{
    (void)w; (void)menuitem; (void)call_data;
}

void
MenuNotImplemented(Widget w, XtPointer menuitem, XtPointer call_data)
{
    (void)w; (void)menuitem; (void)call_data;
    fprintf(stderr, "GopherVR: Not implemented yet\n");
}

/*
 * Cursor stubs
 */
void
TimeoutCursors(Boolean on)
{
    (void)on;
}

void
UseOurCursor(int cursortype)
{
    (void)cursortype;
}

void
HiddenCursors(Boolean on)
{
    (void)on;
}

/*
 * Input handling stub
 */
void
AddInput(int fd, char *(*proc)(int, XtPointer))
{
    (void)fd; (void)proc;
}

/*
 * Prompt stub
 */
void
PromptFor(char *txt, void *(*function)(void))
{
    (void)txt; (void)function;
}

/*
 * File picker stub
 */
void
filepicker(char *suggestion, void *gs)
{
    (void)suggestion; (void)gs;
}

/*
 * Save/load stubs
 */
void
savecancel(Widget Wig_diag, XtPointer client_data, XtPointer call_data)
{
    (void)Wig_diag; (void)client_data; (void)call_data;
}

void
saveok(Widget widget, XtPointer client_data, XtPointer call_data)
{
    (void)widget; (void)client_data; (void)call_data;
}
