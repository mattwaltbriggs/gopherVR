/*
 * stub_burrower.c
 *
 * Stubs for functions defined in burrower.c that are still referenced
 * by other C files. The main() and Motif code is replaced by AppDelegate.m.
 *
 * popuptextfile and popupsearchdeally are now in cocoa_dialogs.m
 */

#include <stdio.h>
#include <stdlib.h>

/* Global variable from burrower.c */
int no_fps = 0;

/* External functions from other modules */
extern void sceneclick(int sceneid, int x, int y);
extern void ResetFps(void);
extern int SelectGopherDir(void);
extern void drawscene(void);
extern void EyeAirJordan(void (*df)(), float a, float b, float c, float d);
extern int oursceneid;

/* Called by gopherto3d.c and mouse handler */
void jumpto(int x, int y)
{
    sceneclick(oursceneid, x, y);
    ResetFps();
    drawscene();

    if (SelectGopherDir() < 0)
        EyeAirJordan(drawscene, .5, 150.0, 200.0, 3.0);

    drawscene();
}

/* ReloadCurrentDir is defined in gopherto3d.c, so don't stub it here */
