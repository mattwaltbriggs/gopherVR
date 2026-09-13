/*
 * stub_dialogs.c
 * Stub implementations for dialogs.c functions.
 * V_OpenGeneralDiag, V_OpenTwoEntryDiag, f_V_URL_ok, f_V_SEARCH_ok,
 * f_V_FTP_ok are now in cocoa_dialogs.m.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void *Widget;
typedef void *XtPointer;
typedef int Boolean;

typedef struct {
    int    F_which_one;
    int    F_which_help;
    Widget Wig_text1;
    Widget Wig_text2;
    Widget Wig_parent;
} TWOTEXTW, *P_TWOTEXTW;

typedef struct {
    int    F_which_help;
    Widget Wig_text;
    Widget Wig_parent;
} ONETEXTW, *P_ONETEXTW;

extern void showError(char *parm);

char *Search = "Search items for:";

void
V_FileSelDiag(Widget Wig_diag, XtPointer client_data, XtPointer call_data)
{
    (void)Wig_diag; (void)client_data; (void)call_data;
}

Widget
CreateActionArea(P_ONETEXTW pOtw_data, void (*f_V_callback)(Widget, XtPointer, XtPointer))
{
    (void)pOtw_data; (void)f_V_callback;
    return NULL;
}

Widget
CreateActionArea2(P_TWOTEXTW pTtw_data, void (*f_V_callback)(Widget, XtPointer, XtPointer))
{
    (void)pTtw_data; (void)f_V_callback;
    return NULL;
}

void
V_DiagClose1(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)call_data;
    if (client_data) free(client_data);
}

void
V_DiagClose2(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)call_data;
    if (client_data) free(client_data);
}

void
V_ClearOneText(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)client_data; (void)call_data;
}

void
V_ClearTwoText(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)client_data; (void)call_data;
}

void
activate_cb(Widget Wig_text, XtPointer client_data, XtPointer call_data)
{
    (void)Wig_text; (void)client_data; (void)call_data;
}

void
V_SetActiv1(Widget Wig_text, XtPointer client_data, XtPointer call_data)
{
    (void)Wig_text; (void)call_data;
    if (client_data) {
        P_TWOTEXTW p = (P_TWOTEXTW)client_data;
        p->F_which_one = 1;
    }
}

void
V_SetActiv2(Widget Wig_text, XtPointer client_data, XtPointer call_data)
{
    (void)Wig_text; (void)call_data;
    if (client_data) {
        P_TWOTEXTW p = (P_TWOTEXTW)client_data;
        p->F_which_one = 2;
    }
}
