#!/bin/bash
set -e

APP="AyuGram"
ARCH="x86_64"
APPDIR="${APP}.AppDir"

pacman -S --noconfirm wget xorg-server-xvfb ayugram-desktop-git qt6-imageformats patchelf strace file binutils

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

wget -q "https://github.com/pkgforge-dev/appimagetool/releases/latest/download/appimagetool-x86_64-linux" -O appimagetool
chmod +x appimagetool

wget -q "https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-x86_64" -O sharun
chmod +x sharun

./sharun lib4bin --hard-links --dst-dir ./"$APPDIR" /usr/bin/AyuGram

for dir in "bin" "shared/bin" "shared/lib"; do
    mkdir -p ./"$APPDIR"/"$dir"
done

mkdir -p ./"$APPDIR"/qt-plugins
cp -rLn /usr/lib/qt6/plugins/* ./"$APPDIR"/qt-plugins/

./sharun lib4bin --hard-links --dst-dir ./"$APPDIR" /usr/lib/qt6/plugins/*/*.so || true

cp /usr/share/applications/com.ayugram.desktop.desktop ./"$APPDIR"/
cp /usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png ./"$APPDIR"/ayugram.png
cp ./"$APPDIR"/ayugram.png ./"$APPDIR"/.DirIcon

cat <<'EOF' > ./"$APPDIR"/AppRun
#!/bin/sh
export APPDIR="$(dirname "$(readlink -f "${0}")")"
export QT_PLUGIN_PATH="$APPDIR/qt-plugins"
export QML2_IMPORT_PATH="$APPDIR/qt-plugins/qml"
export LD_LIBRARY_PATH="$APPDIR/shared/lib:$LD_LIBRARY_PATH"
export QT_QPA_PLATFORM=xcb
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
exec "$APPDIR/bin/AyuGram" "$@"
EOF

chmod +x ./"$APPDIR"/AppRun

sed -i 's|^Exec=.*|Exec=AppRun %u|g' ./"$APPDIR"/com.ayugram.desktop.desktop
sed -i 's|^Icon=.*|Icon=ayugram|g' ./"$APPDIR"/com.ayugram.desktop.desktop

VERSION=$(pacman -Q ayugram-desktop-git | awk '{print $2}' | cut -d '-' -f 1)
APPIMAGE_NAME="$APP-$VERSION-$ARCH.AppImage"

export OPTIMIZE_LAUNCH=1
export OUTNAME="$APPIMAGE_NAME"

xvfb-run -a ./appimagetool ./"$APPDIR" -o ./dist

mv ./dist/"$APPIMAGE_NAME" "$GITHUB_WORKSPACE/"

echo "appimage_name=$APPIMAGE_NAME" >> "$GITHUB_OUTPUT"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
