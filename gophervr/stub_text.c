/*
 * stub_text.c
 * Stub implementations for text.c functions.
 * displayTempFile, displayIndexTempFile, displayTextString are now
 * in cocoa_dialogs.m with real Cocoa text window implementations.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/param.h>

typedef void *Widget;
typedef void *XtPointer;
typedef int Boolean;

void
showError(char *parm)
{
    if (parm)
        fprintf(stderr, "%s\n", parm);
}

void
GTXTdone(Widget w, XtPointer client_data, XtPointer cbs)
{
    (void)w; (void)client_data; (void)cbs;
}

void
GTXTprint(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)client_data; (void)call_data;
}

void
GTXTsave(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)client_data; (void)call_data;
}

Widget
GTXTmenubar(Widget parent, void *tep)
{
    (void)parent; (void)tep;
    return NULL;
}

void
GTXTcleanUpTextProc(void)
{
}

int
is_writable(char *file)
{
    (void)file;
    return -1;
}

void
V_FileSelDone(Widget Wig_diag, XtPointer client_data, XtPointer call_data)
{
    (void)Wig_diag; (void)client_data; (void)call_data;
}

void
new_file_cb(Widget widget, XtPointer client_data, XtPointer call_data)
{
    (void)widget; (void)client_data; (void)call_data;
}

void
do_search(Widget widget, XtPointer search_data)
{
    (void)widget; (void)search_data;
}
