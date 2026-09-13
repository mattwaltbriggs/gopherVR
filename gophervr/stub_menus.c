/*
 * stub_menus.c
 * Stub implementations for menus.c functions.
 * Allows compilation without X11/Motif while building the Cocoa replacement.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Minimal type definitions to satisfy function signatures */
typedef void *Widget;
typedef void *XtPointer;
typedef int Boolean;

/* Stub MenuItem struct matching menus.h layout (without X11 types) */
typedef struct _MenuItem {
    char        *label;
    void        *class;
    char         mnemonic;
    char        *accelerator;
    char        *accel_text;
    void       (*callback)(Widget, XtPointer, XtPointer);
    XtPointer    callback_data;
    struct _MenuItem *subitems;
} MenuItem;

/* Global menu pointer stub */
MenuItem *StandardHelpMenu = NULL;

Widget
BuildMenu(Widget parent,
          int menu_type,
          char *menu_title,
          char menu_mnemonic,
          Boolean tear_off,
          MenuItem *items)
{
    (void)parent; (void)menu_type; (void)menu_title;
    (void)menu_mnemonic; (void)tear_off; (void)items;
    return NULL;
}

Widget
Create_Menubar(Widget parent)
{
    (void)parent;
    return NULL;
}
