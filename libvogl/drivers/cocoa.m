/*
 * cocoa.m
 *
 * Objective-C backend for the vogl rendering library.
 * Renders to an in-memory bitmap via Core Graphics, suitable for
 * display by an NSImageView.
 */

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

#include "vogl.h"
#include "vodevice.h"
#include "drivers.h"

#ifndef MIN
#define MIN(x,y)	((x) < (y) ? (x) : (y))
#endif
#define CMAPSIZE	256

static unsigned char *backBuffer = NULL;
static unsigned char *frontBuffer = NULL;
static int bufW = 0, bufH = 0;
static int cur_x = 0, cur_y = 0;
static NSColor *cmap[CMAPSIZE];
static int cur_r = 0, cur_g = 0, cur_b = 0;
static int currentLineWidth = 1;
static Linestyle currentLineStyle = 0xffff;

static int back_used = 0;

static int mouse_x = 0, mouse_y = 0;

#define KEY_QUEUE_SIZE 64
static int keyQueue[KEY_QUEUE_SIZE];
static int keyHead = 0;
static int keyTail = 0;

static void enqueueKey(int key)
{
	keyQueue[keyTail] = key;
	keyTail = (keyTail + 1) % KEY_QUEUE_SIZE;
	if (keyTail == keyHead)
		keyHead = (keyHead + 1) % KEY_QUEUE_SIZE;
}

static int dequeueKey(void)
{
	int key;
	if (keyHead == keyTail)
		return 0;
	key = keyQueue[keyHead];
	keyHead = (keyHead + 1) % KEY_QUEUE_SIZE;
	return key;
}

static void cocoaCreateBitmaps(int w, int h)
{
	if (backBuffer) { free(backBuffer); backBuffer = NULL; }
	if (frontBuffer) { free(frontBuffer); frontBuffer = NULL; }

	bufW = w;
	bufH = h;
	if (bufW > 0 && bufH > 0) {
		backBuffer = (unsigned char *)calloc(bufW * bufH * 4, 1);
		frontBuffer = (unsigned char *)calloc(bufW * bufH * 4, 1);
	}
}

static void cocoaSetPixel(unsigned char *buf, int x, int y,
			  int r, int g, int b)
{
	if (!buf || x < 0 || x >= bufW || y < 0 || y >= bufH)
		return;
	int off = (y * bufW + x) * 4;
	buf[off + 0] = r;
	buf[off + 1] = g;
	buf[off + 2] = b;
	buf[off + 3] = 255;
}

static void cocoaFillRect(unsigned char *buf, int rx, int ry, int rw, int rh,
			  int r, int g, int b)
{
	int x, y;
	for (y = ry; y < ry + rh; y++) {
		for (x = rx; x < rx + rw; x++) {
			cocoaSetPixel(buf, x, y, r, g, b);
		}
	}
}

static void cocoaDrawLine(unsigned char *buf, int x0, int y0, int x1, int y1,
			  int lw, int r, int g, int b)
{
	int dx, dy, sx, sy, err, e2;

	if (lw < 1) lw = 1;

	dx = abs(x1 - x0);
	dy = abs(y1 - y0);
	sx = (x0 < x1) ? 1 : -1;
	sy = (y0 < y1) ? 1 : -1;
	err = dx - dy;

	for (;;) {
		int px, py;
		for (px = x0 - lw / 2; px < x0 - lw / 2 + lw; px++)
			for (py = y0 - lw / 2; py < y0 - lw / 2 + lw; py++)
				cocoaSetPixel(buf, px, py, r, g, b);

		if (x0 == x1 && y0 == y1)
			break;
		e2 = 2 * err;
		if (e2 > -dy) { err -= dy; x0 += sx; }
		if (e2 < dx) { err += dx; y0 += sy; }
	}
}

static void cocoaFillPolygon(unsigned char *buf, int n, int x[], int y[],
			     int r, int g, int b)
{
	int i, j, y_min, y_max;
	int *scanlineMin, *scanlineMax;

	if (n < 3)
		return;

	y_min = y_max = y[0];
	for (i = 1; i < n; i++) {
		if (y[i] < y_min) y_min = y[i];
		if (y[i] > y_max) y_max = y[i];
	}

	if (y_min < 0) y_min = 0;
	if (y_max >= bufH) y_max = bufH - 1;
	if (y_min > y_max)
		return;

	scanlineMin = (int *)malloc((y_max - y_min + 1) * sizeof(int));
	scanlineMax = (int *)malloc((y_max - y_min + 1) * sizeof(int));

	for (i = 0; i <= y_max - y_min; i++) {
		scanlineMin[i] = bufW;
		scanlineMax[i] = 0;
	}

	for (i = 0; i < n; i++) {
		j = (i + 1) % n;
		int x0 = x[i], y0 = y[i];
		int x1 = x[j], y1 = y[j];
		int sy0, sy1, tmp;

		if (y0 < 0 && y1 < 0) continue;
		if (y0 >= bufH && y1 >= bufH) continue;

		sy0 = y0; sy1 = y1;
		if (sy0 < y_min) sy0 = y_min;
		if (sy0 > y_max) sy0 = y_max;
		if (sy1 < y_min) sy1 = y_min;
		if (sy1 > y_max) sy1 = y_max;
		if (sy0 > sy1) { tmp = sy0; sy0 = sy1; sy1 = tmp; }

		if (y0 != y1) {
			for (int sy = sy0; sy <= sy1; sy++) {
				if (y1 == y0) continue;
				int ix = x0 + (x1 - x0) * (sy - y0) / (y1 - y0);
				int off = sy - y_min;
				if (ix < scanlineMin[off]) scanlineMin[off] = ix;
				if (ix > scanlineMax[off]) scanlineMax[off] = ix;
			}
		} else {
			int off = y0 - y_min;
			if (off >= 0 && off <= y_max - y_min) {
				int mx = (x0 < x1) ? x0 : x1;
				int Mx = (x0 > x1) ? x0 : x1;
				if (mx < scanlineMin[off]) scanlineMin[off] = mx;
				if (Mx > scanlineMax[off]) scanlineMax[off] = Mx;
			}
		}
	}

	for (i = 0; i <= y_max - y_min; i++) {
		int sy = y_min + i;
		if (scanlineMin[i] < bufW && scanlineMax[i] >= 0) {
			int sx = (scanlineMin[i] < 0) ? 0 : scanlineMin[i];
			int ex = (scanlineMax[i] >= bufW) ? bufW - 1 : scanlineMax[i];
			for (int px = sx; px <= ex; px++)
				cocoaSetPixel(buf, px, sy, r, g, b);
		}
	}

	free(scanlineMin);
	free(scanlineMax);
}

static CGImageRef cocoaCreateCGImage(unsigned char *pixels, int w, int h)
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef provider = CGDataProviderCreateWithData(
		NULL, pixels, w * h * 4, NULL);
	CGImageRef image = CGImageCreate(
		w, h,
		8, 32,
		w * 4,
		colorSpace,
		kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast,
		provider, NULL, true,
		kCGRenderingIntentDefault);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return image;
}

void Cocoa_SetMousePosition(int x, int y)
{
	mouse_x = x;
	mouse_y = y;
}

void Cocoa_PushKeyEvent(int key)
{
	enqueueKey(key);
}

unsigned char *Cocoa_GetFrontBuffer(void)
{
	return frontBuffer;
}

int Cocoa_GetBufferWidth(void)
{
	return bufW;
}

int Cocoa_GetBufferHeight(void)
{
	return bufH;
}

void Cocoa_ResizeBuffers(int w, int h)
{
	if (w == bufW && h == bufH)
		return;
	cocoaCreateBitmaps(w, h);
	vdevice.sizeSx = w;
	vdevice.sizeSy = h;
	vdevice.sizeX = vdevice.sizeY = MIN(h, w);
}

static void ensureBuffers(void)
{
	if (bufW != vdevice.sizeSx || bufH != vdevice.sizeSy)
		cocoaCreateBitmaps(vdevice.sizeSx, vdevice.sizeSy);
}

static int
Cocoa_backbuf(void)
{
	back_used = 1;
	return 1;
}

static void
Cocoa_frontbuf(void)
{
}

static int
Cocoa_swapbuf(void)
{
	if (backBuffer && frontBuffer && bufW > 0 && bufH > 0) {
		memcpy(frontBuffer, backBuffer, bufW * bufH * 4);
	}
	return 0;
}

static void
Cocoa_draw(int x, int y)
{
	int flipped_y = vdevice.sizeSy - vdevice.cpVy;
	int flipped_ey = vdevice.sizeSy - y;

	ensureBuffers();

	cocoaDrawLine(back_used ? backBuffer : frontBuffer,
		      vdevice.cpVx, flipped_y, x, flipped_ey,
		      currentLineWidth, cur_r, cur_g, cur_b);

	if (vdevice.sync) {
		Cocoa_swapbuf();
	}
}

static int
Cocoa_pnt(int x, int y)
{
	int flipped_y = vdevice.sizeSy - y;

	ensureBuffers();

	cocoaSetPixel(back_used ? backBuffer : frontBuffer,
		      x, flipped_y, cur_r, cur_g, cur_b);

	if (vdevice.sync) {
		Cocoa_swapbuf();
	}
	return 0;
}

static void
Cocoa_clear(void)
{
	ensureBuffers();

	unsigned int w = vdevice.maxVx - vdevice.minVx;
	unsigned int h = vdevice.maxVy - vdevice.minVy;
	unsigned char *buf = back_used ? backBuffer : frontBuffer;

	if (buf && bufW > 0 && bufH > 0) {
		int rx = vdevice.minVx + 1;
		int ry = vdevice.sizeSy - vdevice.maxVy;
		cocoaFillRect(buf, rx, ry, (int)w, (int)h, cur_r, cur_g, cur_b);
	}

	if (vdevice.sync) {
		Cocoa_swapbuf();
	}
}

static void
Cocoa_color(int ind)
{
	NSColor *c;
	CGFloat rr, gg, bb;

	if (ind < 0 || ind >= CMAPSIZE)
		return;

	c = cmap[ind];
	if (!c)
		return;

	rr = [c redComponent];
	gg = [c greenComponent];
	bb = [c blueComponent];

	cur_r = (int)(rr * 255.0 + 0.5);
	cur_g = (int)(gg * 255.0 + 0.5);
	cur_b = (int)(bb * 255.0 + 0.5);
}

static void
Cocoa_mapcolor(int i, int r, int g, int b)
{
	if (i >= CMAPSIZE)
		return;

	if (cmap[i]) {
		[cmap[i] release];
	}
	cmap[i] = [[NSColor colorWithCalibratedRed:(r / 255.0)
					     green:(g / 255.0)
					      blue:(b / 255.0)
					     alpha:1.0] retain];
}

static int
Cocoa_font(char *fontfile)
{
	vdevice.hheight = 15.0;
	vdevice.hwidth = 8.0;
	return 1;
}

static void
Cocoa_char(char c)
{
	ensureBuffers();

	int x = vdevice.cpVx;
	int flipped_y = vdevice.sizeSy - vdevice.cpVy;
	unsigned char *buf = back_used ? backBuffer : frontBuffer;

	if (!buf)
		return;

	/* Simple block placeholder for characters */
	int gw = (int)vdevice.hwidth;
	int gh = (int)vdevice.hheight;
	if (gw < 1) gw = 8;
	if (gh < 1) gh = 13;

	if (c != ' ') {
		for (int gy = 0; gy < gh; gy++)
			for (int gx = 0; gx < gw; gx++)
				cocoaSetPixel(buf, x + gx, flipped_y + gy,
					      cur_r, cur_g, cur_b);
	}
	vdevice.cpVx += gw;

	if (vdevice.sync) {
		Cocoa_swapbuf();
	}
}

static void
Cocoa_string(char s[])
{
	int i;
	for (i = 0; s[i] != '\0'; i++) {
		Cocoa_char(s[i]);
	}
}

static void
Cocoa_fill(int n, int x[], int y[])
{
	int i;
	int *flipped_y;

	if (0 == n)
		return;

	ensureBuffers();

	flipped_y = (int *)malloc(n * sizeof(int));
	for (i = 0; i < n; i++)
		flipped_y[i] = vdevice.sizeSy - y[i];

	cocoaFillPolygon(back_used ? backBuffer : frontBuffer,
			 n, x, flipped_y, cur_r, cur_g, cur_b);

	cocoaDrawLine(back_used ? backBuffer : frontBuffer,
		      x[0], flipped_y[0], x[n-1], flipped_y[n-1],
		      currentLineWidth, cur_r, cur_g, cur_b);

	vdevice.cpVx = x[n - 1];
	vdevice.cpVy = y[n - 1];

	free(flipped_y);

	if (vdevice.sync) {
		Cocoa_swapbuf();
	}
}

static void
Cocoa_exit(void)
{
	if (backBuffer) { free(backBuffer); backBuffer = NULL; }
	if (frontBuffer) { free(frontBuffer); frontBuffer = NULL; }
	bufW = 0;
	bufH = 0;

	for (int i = 0; i < CMAPSIZE; i++) {
		if (cmap[i]) {
			[cmap[i] release];
			cmap[i] = nil;
		}
	}
}

static int
Cocoa_init(void)
{
	if (bufW <= 0 || bufH <= 0) {
		cocoaCreateBitmaps(512, 512);
	}

	vdevice.sizeSx = bufW;
	vdevice.sizeSy = bufH;
	vdevice.sizeX = vdevice.sizeY = MIN(bufH, bufW);
	vdevice.depth = 24;
	vdevice.devname = "Cocoa";

	Cocoa_mapcolor(0, 0, 0, 0);
	Cocoa_mapcolor(1, 255, 255, 255);

	return 1;
}

static int
Cocoa_locator(int *wx, int *wy)
{
	*wx = mouse_x;
	*wy = vdevice.sizeSy - mouse_y;
	return 0;
}

static int
Cocoa_checkkey(void)
{
	return dequeueKey();
}

static int
Cocoa_getkey(void)
{
	int key;
	for (;;) {
		key = dequeueKey();
		if (key)
			return key;
		[[NSRunLoop currentRunLoop] runUntilDate:
			[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	return 0;
}

static void
Cocoa_setlw(short w)
{
	currentLineWidth = (w > 0) ? w : 1;
}

static void
Cocoa_setls(Linestyle ls)
{
	currentLineStyle = ls;
}

static void
Cocoa_sync(void)
{
	Cocoa_swapbuf();
}

static int
Cocoa_PointInPolygon(int x, int y, int npol, int xp[], int yp[])
{
	int i, j, c = 0;

	for (i = 0, j = npol - 1; i < npol; j = i++) {
		if ((((yp[i] <= y) && (y < yp[j])) ||
		     ((yp[j] <= y) && (y < yp[i]))) &&
		    (x < (xp[j] - xp[i]) * (y - yp[i]) / (yp[j] - yp[i]) + xp[i]))
			c = !c;
	}
	return c;
}

static DevEntry Cocodev = {
	"Cocoa",
	"large",
	"small",
	Cocoa_backbuf,
	Cocoa_char,
	Cocoa_checkkey,
	Cocoa_clear,
	Cocoa_color,
	Cocoa_draw,
	Cocoa_exit,
	Cocoa_fill,
	Cocoa_font,
	Cocoa_frontbuf,
	Cocoa_getkey,
	Cocoa_init,
	Cocoa_locator,
	Cocoa_mapcolor,
	Cocoa_setls,
	Cocoa_setlw,
	Cocoa_string,
	Cocoa_swapbuf,
	Cocoa_sync,
	Cocoa_PointInPolygon
};

int
_Cocoa_devcpy(void)
{
	vdevice.dev = Cocodev;
	return 0;
}
