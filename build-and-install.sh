#!/bin/bash
set -e

PROJECT="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${HOME}/.local"
BUILD_TYPE="${1:-release}"

echo "=== LumiWeb: build ($BUILD_TYPE) + install ==="

# Rust core
echo "→ Rust core..."
(cd "$PROJECT/src/rust/core" && cargo build --release)

# Rust theme_engine
echo "→ Rust theme_engine..."
(cd "$PROJECT/src/rust/theme_engine" && cargo build --release)

# Rust settings
echo "→ Rust settings..."
(cd "$PROJECT/src/rust/settings" && cargo build --release)

# Vala
echo "→ Vala binary..."
cd "$PROJECT"
valac --pkg gtk4 --pkg webkitgtk-6.0 --pkg json-glib-1.0 \
    --vapidir=src/vala \
    -X -Isrc/vala \
    -X -Lsrc/rust/core/target/release \
    -X -llumiweb_core \
    -X -O2 \
    src/vala/main.vala src/vala/lumiweb_core.vapi \
    -o lumiweb

# === INSTALL ===
echo "→ Install do $PREFIX..."
mkdir -p "$PREFIX/bin"
mkdir -p "$PREFIX/lib/lumiweb"
mkdir -p "$PREFIX/share/icons/hicolor/scalable/apps"
mkdir -p "$PREFIX/share/applications"

cp -f lumiweb "$PREFIX/bin/lumiweb"
cp -f src/rust/settings/target/release/lumiweb-settings "$PREFIX/bin/lumiweb-settings"
cp -f src/rust/theme_engine/target/release/theme_engine "$PREFIX/lib/lumiweb/theme_engine"
cp -f src/rust/core/target/release/liblumiweb_core.so "$PREFIX/lib/lumiweb/"
cp -f share/icons/hicolor/scalable/apps/lumiweb.svg "$PREFIX/share/icons/hicolor/scalable/apps/"

# Wrapper: ustawia LD_LIBRARY_PATH
cat > "$PREFIX/bin/lumiweb-launcher" << WRAPPER
#!/bin/bash
export LD_LIBRARY_PATH="$PREFIX/lib/lumiweb:\$LD_LIBRARY_PATH"
# Generuj theme.css jeśli nie istnieje
if [ ! -f "\$HOME/.config/lumiweb/theme.css" ]; then
    mkdir -p "\$HOME/.config/lumiweb"
    "$PREFIX/lib/lumiweb/theme_engine" 2>/dev/null || true
fi
exec "$PREFIX/bin/lumiweb" "\$@"
WRAPPER
chmod +x "$PREFIX/bin/lumiweb-launcher"

# Desktop file
sed "s|@INSTALL_PREFIX@|$PREFIX|g" \
    share/applications/lumiweb.desktop.template \
    > "$PREFIX/share/applications/lumiweb.desktop"

# Odśwież cache
gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true

# Initial theme
mkdir -p "$HOME/.config/lumiweb"
"$PREFIX/lib/lumiweb/theme_engine" 2>/dev/null || true

echo ""
echo "✅ Zainstalowane!"
echo ""
echo "Uruchom:"
echo "  lumiweb-launcher                 # pusta przeglądarka"
echo "  lumiweb-launcher google.com      # otwórz URL"
echo "  lumiweb-launcher ~/file.html     # otwórz lokalny plik"
echo ""
echo "Ustaw jako domyślną:"
echo "  xdg-settings set default-web-browser lumiweb.desktop"
echo ""
echo "Sprawdź PATH — jeśli ~/.local/bin nie jest w PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
