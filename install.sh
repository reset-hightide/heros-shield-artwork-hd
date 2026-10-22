#!/bin/sh
# Hero's Shield Artwork HD - installer for Linux, Steam Deck and macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/reset-hightide/heros-shield-artwork-hd/main/install.sh | sh
#
# Copies the mods into Zelda 64: Recompiled's mods folder, downloads Player Model Manager and its
# dependencies from Thunderstore (only the ones that are missing), and picks HW Young Link HD and
# Hero's Shield HD in Player Model Manager (only if nothing else is picked there yet).
# Set RECOMP_DIR to use a different Zelda64Recompiled folder (portable installs).
set -eu

REPO_RAW="https://raw.githubusercontent.com/reset-hightide/heros-shield-artwork-hd/main"
OUR_FILES="hwmm_young_link_hd.nrm hwmm_young_link_hd_textures.rtz hwmm_heros_shield_hd.nrm hwmm_heros_shield_hd_textures.rtz hwmm_heros_shield_aftermatch_heavy.nrm hwmm_heros_shield_aftermatch_heavy_textures.rtz hwmm_heros_shield_n64.nrm"
# Thunderstore packages: namespace/name/version/file that tells us it is already installed
DEPS="YAZMT/YAZMT_Core/0.1.1/yazmt_mm_corelib.nrm
YAZMT/Global_Objects/0.1.1/yazmt_mm_global_objects.nrm
LT_Schmiddy/RecompExternalPython_for_Zelda64Recompiled/2.0.0/RecompExternalPython_API.nrm
YAZMT/Player_Model_Manager/0.6.1/yazmt_mm_playermodelmanager.nrm"

say() { printf '%s\n' "$*"; }
fail() { say ""; say "ERRO / ERROR: $*"; exit 1; }

say "=== Hero's Shield Artwork HD ==="

OS="$(uname -s)"
# native libraries built for another OS (Thunderstore packages ship all of them)
other_os() {
    case "$1" in
        *.dll) return 0 ;;
        *.dylib) [ "$OS" != Darwin ] ;;
        *.so|*.so.*) [ "$OS" = Darwin ] ;;
        *) return 1 ;;
    esac
}

if [ -n "${RECOMP_DIR:-}" ]; then
    APP="$RECOMP_DIR"
elif [ "$OS" = Darwin ]; then
    APP="$HOME/Library/Application Support/Zelda64Recompiled"
else
    APP="$HOME/.config/Zelda64Recompiled"
fi
if [ ! -d "$APP" ]; then
    fail "Zelda64Recompiled nao encontrado em / not found at: $APP
Abra o Zelda 64: Recompiled pelo menos uma vez antes. / Run Zelda 64: Recompiled once first."
fi
MODS="$APP/mods"
mkdir -p "$MODS"
say "Pasta de mods / Mods folder: $MODS"

if pgrep -x Zelda64Recompiled >/dev/null 2>&1 || pgrep -f '[Z]elda64Recompiled.*AppImage' >/dev/null 2>&1; then
    fail "Feche o jogo antes de instalar. / Close the game before installing."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fetch() { curl -fsSL --retry 3 -o "$2" "$1" || fail "download falhou / download failed: $1"; }

# 1. our mods: from the mods/ folder next to this script (release zip), or from GitHub
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo .)"
for f in $OUR_FILES; do
    if [ -f "$HERE/mods/$f" ]; then
        cp "$HERE/mods/$f" "$MODS/$f"
    else
        fetch "$REPO_RAW/mods/$f" "$TMP/$f"
        cp "$TMP/$f" "$MODS/$f"
    fi
    say "  + $f"
done

# 2. dependencies (skipped when already installed)
printf '%s\n' "$DEPS" | while IFS=/ read -r ns name ver marker; do
    if [ -f "$MODS/$marker" ]; then
        say "  = $name (ja instalado / already installed)"
        continue
    fi
    fetch "https://thunderstore.io/package/download/$ns/$name/$ver/" "$TMP/pkg.zip"
    rm -rf "$TMP/pkg" && mkdir -p "$TMP/pkg"
    unzip -q -o "$TMP/pkg.zip" -d "$TMP/pkg" || fail "unzip falhou / failed: $name"
    for p in "$TMP"/pkg/*; do
        f="$(basename "$p")"
        case "$f" in
            manifest.json|README.md|CHANGELOG.md|icon.png|LICENSE*) continue ;;
        esac
        other_os "$f" || cp -R "$p" "$MODS/"
    done
    say "  + $name $ver"
done

# 3. pick the models in Player Model Manager (never overrides the player's own choice)
INI_DIR="$APP/mod_data/yazmt_z64_playermodelmanager"
INI="$INI_DIR/models.ini"
mkdir -p "$INI_DIR"
if [ ! -f "$INI" ]; then
    printf '[meta]\ncfg_version = 1\n\n[mm.player1]\nchild = hwmm_young_link_hd\nshield2 = hwmm_heros_shield_hd\n' > "$INI"
    say "  * Player Model Manager: HW Young Link HD + Hero's Shield HD"
else
    cp "$INI" "$INI.before-heros-shield-artwork"
    sed -e 's/^child[[:space:]]*=[[:space:]]*$/child = hwmm_young_link_hd/' \
        -e 's/^shield2[[:space:]]*=[[:space:]]*$/shield2 = hwmm_heros_shield_hd/' "$INI" > "$TMP/models.ini"
    cp "$TMP/models.ini" "$INI"
    say "  * Player Model Manager: models.ini atualizado / updated (backup: models.ini.before-heros-shield-artwork)"
fi

say ""
say "Pronto! Abra o jogo. Para trocar de modelo: menu do Player Model Manager (L + A)."
say "Done! Start the game. To switch models: Player Model Manager menu (L + A)."
