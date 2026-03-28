-- Your Hyprland configuration. HyDE never overwrites this file.
--
-- It loads after HyDE's own binds, so settings here take precedence. Replacing
-- a bind needs more than that: see below. HyDE's defaults live in
-- ~/.local/share/hypr/lua/ and are overwritten on every update, so edits there
-- do not survive.
--
-- Adding a keybind:
--
--     hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(hyde.sh.gamelauncher()), {
--         description = "[Utilities] game launcher",
--     })
--
-- Replacing one of HyDE's: bind the same combination again and yours takes
-- over, but copy its flags across as well. A bind counts as the same one only
-- when its flags match, and `description` is not a flag — miss one and both
-- binds stay live on that combination. Copy the whole options table from
-- ~/.local/share/hypr/lua/key_binds.lua and change only what you need:
--
--     hl.bind("F9", hl.dsp.exec_cmd(hyde.sh.volumecontrol("-o", "m")), {
--         locked = true,
--         description = "[Hardware Controls|Audio] un/mute output",
--     })
--
-- Press SUPER + / to see what is actually loaded, your own binds included.
-- The full reference is KEYBINDINGS.md in the HyDE repository.
--
-- Other Lua files next to this one can be pulled in with require("name").

-- nwg-displays owns this file and rewrites it whenever a display profile is
-- applied. Keeping the import here makes those generated settings effective.
require("monitors")

-- Personal settings migrated from the old userprefs.conf. They load after the
-- generated theme, while a selected workflow can still override them later.
hyde.env("GDK_SCALE", "2")
hl.env("GDK_SCALE", "2")
hl.config({
    general = {
        gaps_in = 1,
        gaps_out = 1,
        border_size = 3,
    },
    decoration = {
        -- Keep the desktop shadowless regardless of the selected theme or the
        -- number of windows.
        shadow = {enabled = false},
    },
})

-- Keep the two-color active border static even when an animation preset
-- enables rotating border colors.
hl.animation({leaf = "borderangle", enabled = false})

-- Fill regular workspaces when only one tiled window is visible. Restore the
-- theme's gaps, borders, and rounding automatically when another window opens.
for index, workspace in ipairs({"w[tv1]s[false]", "f[1]s[false]"}) do
    hl.workspace_rule({
        workspace = workspace,
        gaps_in = 0,
        gaps_out = 0,
    })
    hl.window_rule({
        name = "smart-single-window-" .. index,
        match = {
            float = false,
            workspace = workspace,
        },
        border_size = 0,
        rounding = 0,
        no_shadow = true,
    })
end

-- Personal key choices migrated from keybindings.conf. Keep HyDE's new
-- upstream actions, but expose only the combinations enabled in the old file.
local main_mod = hyde.config.modifiers.main
local disabled_binds = {
    "ALT + F4",
    main_mod .. " + Delete",
    "CTRL + ALT + DELETE",
    main_mod .. " + CTRL + B",
    main_mod .. " + C",
    "CTRL + SHIFT + ESCAPE",
    "F10",
    "F11",
    "F12",
    "XF86AudioMute",
    "XF86AudioMicMute",
    "XF86AudioLowerVolume",
    "XF86AudioRaiseVolume",
    "XF86AudioPlay",
    "XF86AudioPause",
    "XF86AudioNext",
    "XF86AudioPrev",
    main_mod .. " + CONTROL + M",
    "XF86MonBrightnessUp",
    "XF86MonBrightnessDown",
    main_mod .. " + K",
    main_mod .. " + ALT + G",
    main_mod .. " + SHIFT + G",
    main_mod .. " + ALT + Right",
    main_mod .. " + ALT + Left",
    main_mod .. " + SHIFT + W",
    main_mod .. " + ALT + Up",
    main_mod .. " + ALT + Down",
    main_mod .. " + SHIFT + R",
    main_mod .. " + SHIFT + T",
    main_mod .. " + SHIFT + Y",
    main_mod .. " + SHIFT + U",
}

for _, keycombo in ipairs(disabled_binds) do
    hl.unbind(keycombo)
end

-- Preserve the old Super+F floating and Super+M fullscreen choices while
-- using the current upstream Lua dispatchers.
hl.unbind(main_mod .. " + W")
hl.bind(main_mod .. " + F", hl.dsp.window.float({action = "toggle"}), {
    description = "[Window Management] toggle floating",
})

local cycle_fullscreen = function()
    local active_window = assert(hl.get_active_window(), "No active window to toggle fullscreen")
    local current_state = tonumber(active_window.fullscreen) or 0
    local next_state = (current_state + 1) % 3
    hl.dispatch(hl.dsp.window.fullscreen_state({
        internal = next_state,
        client = next_state,
        window = active_window,
    }))
end

hl.unbind("SHIFT + F11")
hl.bind(main_mod .. " + M", cycle_fullscreen, {
    description = "[Window Management] cycle fullscreen",
})

-- The old config intentionally used the opposite wheel direction from HyDE's
-- default for workspace navigation.
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({workspace = "e+1"}), {
    description = "[Workspaces|Navigation|Mouse] next workspace",
})
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({workspace = "e-1"}), {
    description = "[Workspaces|Navigation|Mouse] previous workspace",
})
