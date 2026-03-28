#!/usr/bin/env sh
# Personal display integration and initial state must be expressed by the
# original defaults without committing hardware-specific or generated state.

. "$(dirname -- "$0")/lib/common.sh"

hyprland_config="$REPO_ROOT/Configs/.config/hypr/hyprland.lua"
monitor_config="$REPO_ROOT/Configs/.config/hypr/monitors.lua"
state_dir="$REPO_ROOT/Configs/.local/state/hyde"
metafile="$REPO_ROOT/Scripts/dots/hyprland.toml"

require_count=$(grep -Ec '^[[:space:]]*require\("monitors"\)' "$hyprland_config")
[ "$require_count" -eq 1 ] || fail "monitor module import count is $require_count, expected 1"

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
grep -Fq 'opts.default_key and find(opts.default_key)' \
    "$REPO_ROOT/Configs/.local/lib/hyde/luautils/selector/common.lua" ||
    fail "selector fallback does not honor its declared default key"

grep -Fq 'mkdir -p "$XDG_STATE_HOME/hyde/lua_state"' \
    "$REPO_ROOT/Configs/.local/lib/hyde/theme.switch.sh" ||
    fail "theme switch does not create its generated Lua state directory"
grep -Fq 'mkdir -p "$(dirname "$ui_state")"' \
    "$REPO_ROOT/Configs/.local/lib/hyde/color/hypr.sh" ||
    fail "color integration does not create its generated Lua state directory"

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
grep -Fq 'hl.env("GDK_SCALE", "2")' "$hyprland_config" ||
    fail "personal GTK scale is not migrated"
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
