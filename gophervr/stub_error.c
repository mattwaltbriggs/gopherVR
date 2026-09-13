/*
 * stub_error.c
 *
 * Stub implementations of error.c functions (all were Motif dialogs).
 * Replaced by Cocoa NSAlert equivalents.
 */

#include <stdio.h>
#include <stdlib.h>

void makeErrorDialog(void *top)
{
    (void)top;
}

void displayError(char *errorText, int fatal)
{
    fprintf(stderr, "ERROR: %s\n", errorText ? errorText : "(null)");
    if (fatal)
        exit(14);
}

void makeInfoDialog(void *top)
{
    (void)top;
}

void displayInfo(char *infoText)
{
    fprintf(stderr, "INFO: %s\n", infoText ? infoText : "(null)");
}
