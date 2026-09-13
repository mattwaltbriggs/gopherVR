#!/bin/bash
# Build script for GopherVR Cocoa .app bundle

APPDIR="GopherVR-Cocoa.app"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(dirname "$SRCDIR")"

echo "Building GopherVR-Cocoa.app..."

# Build the binary
cd "$SRCDIR"
rm -f *.cocoa.o gophervr-cocoa
make -f Makefile.cocoa.debug
if [ ! -f gophervr-cocoa ]; then
    echo "Error: build failed"
    exit 1
fi

# Create app bundle structure
rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS"
mkdir -p "$APPDIR/Contents/Resources/fonts"

# Copy binary
cp gophervr-cocoa "$APPDIR/Contents/MacOS/"

# Copy Hershey fonts (futura.hfont is the one used by Init_GL)
cp "$SRCDIR"/futura.hfont "$APPDIR/Contents/Resources/" 2>/dev/null || true
cp "$SRCDIR"/futura.hfont "$APPDIR/Contents/Resources/fonts/" 2>/dev/null || true

# Copy icon
cp "$ROOTDIR"/GopherVR.app/Contents/Resources/GopherVR.icns "$APPDIR/Contents/Resources/" 2>/dev/null
if [ ! -f "$APPDIR/Contents/Resources/GopherVR.icns" ]; then
    echo "Warning: GopherVR.icns not found"
fi

# Create Info.plist
cat > "$APPDIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GopherVR</string>
    <key>CFBundleDisplayName</key>
    <string>GopherVR</string>
    <key>CFBundleIdentifier</key>
    <string>com.floodgap.gophervr</string>
    <key>CFBundleVersion</key>
    <string>0.5.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.5.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>gophervr-cocoa</string>
    <key>CFBundleIconFile</key>
    <string>GopherVR</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
</dict>
</plist>
PLIST

echo "Built: $APPDIR"
echo "Run with: open $SRCDIR/$APPDIR"
