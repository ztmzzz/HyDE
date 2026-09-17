#!/usr/bin/env sh
# Personal display integration and initial state must be expressed by the
# original defaults without committing hardware-specific or generated state.

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
export REPO_ROOT
_failures=0
fail() {
    _failures=$((_failures + 1))
    printf '    fail: %s\n' "$1"
}
finish() {
    [ "$_failures" -eq 0 ] || exit 1
    printf 'Personal desktop configuration checks passed.\n'
}

hyprland_config="$REPO_ROOT/Configs/.config/hypr/hyprland.lua"
monitor_config="$REPO_ROOT/Configs/.config/hypr/monitors.lua"
state_dir="$REPO_ROOT/Configs/.local/state/hyde"
metafile="$REPO_ROOT/Scripts/dots/hyprland.toml"
hyde_metafile="$REPO_ROOT/Scripts/dots/hyde.toml"
desktop_config="$REPO_ROOT/Configs/.config/hyde/config.toml"
fontconfig="$REPO_ROOT/Configs/.config/fontconfig/fonts.conf"
uwsm_user_env="$REPO_ROOT/Configs/.config/uwsm/env-hyprland.d/10-user.sh"

grep -Fq 'check_require("monitors")' "$REPO_ROOT/Configs/.local/share/hypr/hyde.lua" ||
    fail "upstream entry point does not load monitor settings"
grep -Eq '^[[:space:]]*require\("monitors"\)' "$hyprland_config" &&
    fail "personal configuration redundantly loads monitor settings"

if grep -Eq 'output[[:space:]]*=|mode[[:space:]]*=|scale[[:space:]]*=' "$monitor_config"; then
    fail "default monitors.lua contains hardware-specific settings"
fi

for generated_state in animations workflows hypr_theme shaders ui; do
    [ ! -e "$state_dir/lua_state/$generated_state.lua" ] ||
        fail "officially generated lua_state/$generated_state.lua is shipped as a default"
    grep -Fq "lua_state/$generated_state.lua" "$metafile" &&
        fail "hyprland metafile deploys generated lua_state/$generated_state.lua"
done

[ ! -e "$state_dir/staterc" ] ||
    fail "fresh-install selector state is still shipped"
grep -Fq 'staterc' "$metafile" &&
    fail "hyprland metafile deploys fresh-install selector state"

grep -Fq 'default_key = "disable"' "$REPO_ROOT/Configs/.local/lib/hyde/shaders.lua" ||
    fail "shader selector does not default to disable"
grep -Fq 'find(opts.default_key or "default")' \
    "$REPO_ROOT/Configs/.local/lib/hyde/luautils/selector/common.lua" ||
    fail "selector fallback does not honor its declared default key"

grep -Fq 'mkdir -p "$XDG_STATE_HOME/hyde/lua_state"' \
    "$REPO_ROOT/Configs/.local/lib/hyde/theme.switch.sh" ||
    fail "theme switch does not create its generated Lua state directory"
grep -Fq 'mkdir -p "$(dirname "$ui_state")"' \
    "$REPO_ROOT/Configs/.local/lib/hyde/color/hypr.sh" ||
    fail "color integration does not create its generated Lua state directory"

grep -Fq 'FONT=${DESKTOP_UI_FONT:-$FONT}' \
    "$REPO_ROOT/Configs/.local/lib/hyde/theme.switch.sh" ||
    fail "theme switch does not prefer the documented desktop UI font"
grep -Fq '__FONT=${DESKTOP_UI_FONT:-${__FONT:-}}' \
    "$REPO_ROOT/Configs/.local/lib/hyde/color/hypr.sh" ||
    fail "color integration does not prefer the documented desktop UI font"
grep -Fq 'DESKTOP_UI_' "$REPO_ROOT/Configs/.local/lib/hyde/color/dconf.lua" ||
    fail "dconf integration does not read desktop UI values"

grep -Fq 'font = "Noto Sans"' "$desktop_config" ||
    fail "personal UI font is not stored in config.toml"
grep -Fq 'monospace_font = "JetBrains Mono"' "$desktop_config" ||
    fail "personal monospace font is not stored in config.toml"
grep -Fq '<string>Noto Sans Mono CJK SC</string>' "$fontconfig" ||
    fail "fontconfig does not select the Simplified Chinese monospace face"
grep -Fq 'paths = "fonts.conf"' "$hyde_metafile" ||
    fail "fontconfig is not deployed on a fresh installation"
grep -Fq 'paths = ["dconf"]' "$hyde_metafile" ||
    fail "the HyDE dconf profile is not deployed on a fresh installation"
grep -Fq '"gtk-xft-hintstyle" "hint$FONT_HINTING"' \
    "$REPO_ROOT/Configs/.local/lib/hyde/theme.switch.sh" ||
    fail "GTK font hinting does not follow desktop.ui.font_hinting"
if grep -Fq 'font-noto-sans-cjk-ttc' "$REPO_ROOT/Scripts/dots/archives.toml" ||
    grep -Fq 'Font_NotoSansCJK' "$REPO_ROOT/Scripts/restore_fnt.lst"; then
    fail "the package-managed CJK font is still deployed from a duplicate archive"
fi

[ ! -e "$REPO_ROOT/Scripts/migrations/v26.7.4-personal.sh" ] ||
    fail "legacy-only personal migration is still shipped"

grep -Fq 'paths = ["hyprland.lua", "monitors.lua"]' "$metafile" ||
    fail "hyprland metafile does not preserve nwg-displays output"

grep -Fq 'shadow = {enabled = false}' "$hyprland_config" ||
    fail "global window shadows are not disabled"
grep -Fq 'gaps_in = 1' "$hyprland_config" ||
    fail "personal inner gap is not migrated"
grep -Fq 'gaps_out = 1' "$hyprland_config" ||
    fail "personal outer gap is not migrated"
grep -Fq 'border_size = 3' "$hyprland_config" ||
    fail "personal border size is not configured"
grep -Fq 'hl.animation({leaf = "borderangle", enabled = false})' "$hyprland_config" ||
    fail "border angle animation is not disabled"
grep -Fq 'personal_border_flow' "$hyprland_config" &&
    fail "the removed personal border angle curve is still configured"
grep -Fq 'GDK_SCALE' "$hyprland_config" &&
    fail "personal GTK scale is still configured too late in hyprland.lua"
grep -Fxq 'GDK_SCALE=2' "$uwsm_user_env" ||
    fail "personal GTK scale is not persisted in the UWSM Hyprland environment"
grep -Fq 'export GDK_SCALE' "$uwsm_user_env" ||
    fail "personal GTK scale is not exported from the UWSM Hyprland environment"
grep -Fq '"w[tv1]s[false]"' "$hyprland_config" ||
    fail "single-window smart gaps are not configured"
grep -Fq 'no_shadow = true' "$hyprland_config" ||
    fail "single-window edge shadow is not disabled"
grep -Fq 'main_mod .. " + F"' "$hyprland_config" ||
    fail "personal floating keybind is not migrated"
grep -Fq 'main_mod .. " + M"' "$hyprland_config" ||
    fail "personal fullscreen keybind is not migrated"
grep -Fq 'main_mod .. " + mouse_up"' "$hyprland_config" ||
    fail "personal workspace wheel direction is not migrated"

grep -Fq '$LAYOUT_PATH=$HOME/.config/hypr/hyprlock/HyDE.conf' \
    "$REPO_ROOT/Configs/.config/hypr/hyprlock.conf" ||
    fail "HyDE hyprlock layout is not the fresh-install default"

finish
