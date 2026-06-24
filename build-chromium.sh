#!/bin/bash
set -e

APP="Chromium"
ARCH="x86_64"
APPDIR="${APP}.AppDir"

pacman -S --noconfirm wget curl xorg-server-xvfb chromium patchelf strace file binutils

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

wget -q "https://github.com/pkgforge-dev/appimagetool/releases/latest/download/appimagetool-x86_64-linux" -O appimagetool
chmod +x appimagetool

wget -q "https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-x86_64" -O sharun
chmod +x sharun

./sharun lib4bin --hard-links --dst-dir ./"$APPDIR" /usr/lib/chromium/chromium

ICU_FILE=$(find /usr/share/icu -name "icudtl.dat" | head -n 1)

for dir in "bin" "shared/bin" "shared/lib"; do
    find /usr/lib/chromium/ -mindepth 1 -maxdepth 1 ! -name "chromium" -exec cp -rLn {} "./$APPDIR/$dir/" \;

    if [ -n "$ICU_FILE" ]; then
        cp -L "$ICU_FILE" "./$APPDIR/$dir/"
    fi
done

cp /usr/share/applications/chromium.desktop ./"$APPDIR"/
cp /usr/share/icons/hicolor/256x256/apps/chromium.png ./"$APPDIR"/
cp ./"$APPDIR"/chromium.png ./"$APPDIR"/.DirIcon

cat <<'EOF' > ./"$APPDIR"/AppRun
#!/bin/sh
export APPDIR="$(dirname "$(readlink -f "${0}")")"
if [ -n "$GITHUB_ACTIONS" ]; then
    exec "$APPDIR/bin/chromium" --no-sandbox "$@"
else
    exec "$APPDIR/bin/chromium" "$@"
fi
EOF

chmod +x ./"$APPDIR"/AppRun

sed -i 's|^Exec=.*|Exec=AppRun %U|g' ./"$APPDIR"/chromium.desktop

VERSION=$(pacman -Q chromium | awk '{print $2}' | cut -d '-' -f 1)
APPIMAGE_NAME="$APP-$VERSION-$ARCH.AppImage"

export OPTIMIZE_LAUNCH=1
export OUTNAME="$APPIMAGE_NAME"

xvfb-run -a ./appimagetool ./"$APPDIR" -o ./dist

mv ./dist/"$APPIMAGE_NAME" "$GITHUB_WORKSPACE/"

echo "appimage_name=$APPIMAGE_NAME" >> "$GITHUB_OUTPUT"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
