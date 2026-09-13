/*
 * stub_helpdiag.c
 *
 * Stub implementations of helpdiag.c functions.
 * These are no-ops while we build the Cocoa replacement.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Stub out Widget/XtPointer as void* for prototypes */
typedef void* Widget;
typedef void* XtPointer;

void V_HelpWin(Widget w, XtPointer client_data, XtPointer call_data)
{
    (void)w; (void)client_data; (void)call_data;
}

void V_ScanHelpFile(void) {}

void V_TwoPercents1(void) {}

void V_GetTopicName(void) {}

void V_GetTopicBody(void) {}

void V_TwoPercents2(char rCh_desc[], int *irCh_index)
{
    (void)rCh_desc; (void)irCh_index;
}

void V_AddToTopicList(char *aCh_topic, int cCh_len)
{
    (void)aCh_topic; (void)cCh_len;
}

void V_AddToTopicBodyList(char *aCh_desc, int cCh_len)
{
    (void)aCh_desc; (void)cCh_len;
}
