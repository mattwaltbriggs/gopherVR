# GopherVR — macOS Port

A macOS (Apple Silicon) port of [GopherVR](https://github.com/michael-lazar/gopherVR), the original 3D Gopher client from the 1990s by Paul Lindner.

GopherVR renders [Gopher](https://en.wikipedia.org/wiki/Gopher_protocol) space as a navigable 3D environment using X11/Motif. This fork compiles and runs natively on Apple Silicon Macs with [XQuartz](https://www.xquartz.org/) and [OpenMotif](https://motif.ics.com/).

> **Native Cocoa port available!** See [GopherVR-Cocoa](https://github.com/mattwaltbriggs/GopherVR-Cocoa) — runs natively on macOS without X11 or Motif. Full AppKit/Cocoa replacement with text windows, search dialogs, and a proper .app bundle.

## What was done

This port required resolving several issues that prevented the original 1990s-era codebase from compiling on modern macOS with Apple Silicon:

### Case-insensitive filesystem fix

macOS uses a case-insensitive filesystem by default. The gopher object library contains headers named `Stdlib.h`, `String.h`, and `Locale.h` which shadow the corresponding system headers (`<stdlib.h>`, `<string.h>`, `<locale.h>`) when `-I gopher/object` is in the include path.

- Renamed `Regex.h`/`Regex.c` → `GRegex.h`/`GRegex.c` to avoid collision with the system `<regex.h>`
- Changed `-I../gopher/object` to `-iquote ../gopher/object` in the Makefile so that `#include <stdlib.h>` resolves to the system header while quoted includes like `#include "GSgopherobj.h"` still find the gopher headers
- Kept `-I../gopher` for `config.h` which is included via angle brackets in `compatible.h`

### libXt linkage fix (crash fix)

OpenMotif 2.3.8 was built against Homebrew's arm64 libXt. The original Makefile linked against XQuartz's x86_64-compatible libXt (`/opt/X11/lib/`), causing an ABI mismatch that crashed in `XtWidgetToApplicationContext` during `XtVaAppInitialize`.

- Changed library link order to: `-L$(brew --prefix openmotif)/lib -lXm -L$(brew --prefix libxt)/lib -lXt -L/opt/X11/lib -lX11`
- This links against Homebrew's arm64 libXt for OpenMotif compatibility, then XQuartz's libX11 for display

### K&R → ANSI C conversions

All K&R-style function definitions and empty-parens `()` forward declarations were converted to ANSI C across 14 source files and 8 headers. This was required because modern clang (Apple clang 15+) is stricter about implicit function declarations and types. Files converted:

- `burrower.c`, `error.c`, `text.c`, `gopherto3d.c`, `gif.c`, `compat_regex.c`, `motiftools.c`, `parse.c`, `parse_nff.c`, `lcube.c`, `menus.c`, `gophwin.c`, `dialogs.c`, `helpdiag.c`
- `error.h`, `gif.h`, `menus.h`, `dialogs.h`, `helpdiag.h`, `vogltools.h`

### Other fixes

- `saved_home` variable added to cache `getenv("HOME")` before Xt/Motif toolkit initialization (the toolkit environment modifies the environment)
- `showError` forward declaration added to `text.c` and `dialogs.c` to resolve conflicting types
- Empty-parens callback prototypes in `menus.h`, `dialogs.h`, `helpdiag.h` replaced with proper `(Widget, XtPointer, XtPointer)` signatures
- libvogl X11 driver headers updated for modern clang compatibility

### macOS .app bundle

- Created `GopherVR.app` bundle with `Info.plist` and Hershey font in `Contents/Resources/fonts/`
- Binary auto-detects `.app` launch context via `_NSGetExecutablePath` to locate font files
- Auto-sets `DISPLAY=:0` for XQuartz if not already set
- Custom icon: teal wireframe 3D cube with "G" on dark blue circle

## Building from source

### Prerequisites

```bash
# Install XQuartz
brew install --cask xquartz

# Install OpenMotif and dependencies
brew install openmotif libxt

# Start XQuartz (log out and back in after install to ensure DISPLAY is set)
open -a XQuartz
```

### Build

```bash
# Build the libraries (gopher object, vogl, hershey, tracker)
make -C gopher/object -f Makefile
make -C libvogl
make -C libhershey
make -C libtracker

# Build gophervr
cd gophervr
make -f Makefile.macosx-arm64
```

### Run

```bash
# Connect to a Gopher server
./gophervr gopher.floodgap.com 70

# Or launch the .app bundle (requires XQuartz)
open GopherVR.app
```

## Repository structure

```
gophervr/              GopherVR application source + macOS Makefile
gopher/object/         Gopher protocol library
libvogl/               Very Ordinary GL (3D rendering library)
libhershey/            Hershey font library
libtracker/            Audio tracker library
lib/                   Compiled static libraries
GopherVR.app/          Pre-built macOS application bundle
```

## Credits

- **Paul Lindner** — Original GopherVR author
- **Floodgap** — Running `gopher.floodgap.com`, the public Gopher server used as the default

## License

This project retains the original GopherVR license. See the source files for details.
