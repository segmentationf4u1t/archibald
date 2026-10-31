-- Hyprland config for the Quickshell benchmark's nested compositor (bench/env).
-- A bare, quiet, deterministic desktop (no autostart, no binds, no window rules) that still renders
-- the bar's layers the way ~/.config/hypr/hyprland.lua does: same blur, shadow, layer animations and
-- qs-bar / qs-dropdown layer rules, so compositor cost and open/close visuals match the live desktop.

-- Whatever output the host (cage) provides, at its preferred mode, scale 1.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
    misc = {
        -- No logo / splash drawn under the windows: one less thing rendered every frame.
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        -- Started by bench/env, not by start-hyprland: no on-screen warning about it.
        disable_watchdog_warning = true,
    },

    -- No update / donation popups (they would be composited over the bar).
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },

    -- No cursor is ever drawn; nothing moves it anyway.
    cursor = {
        invisible = true,
    },

    -- Stock input settings (no real devices are attached to the headless host).
    input = {
        kb_layout = "us",
    },

    -- The bar is Wayland-only: no Xwayland process, no X11 sockets in /tmp.
    xwayland = {
        enabled = false,
    },

    -- Copied from ~/.config/hypr/hyprland.lua (keep in sync).
    decoration = {
        rounding       = 12,
        rounding_power = 2,
        shadow = { enabled = true, range = 18, render_power = 3, color = "rgba(08040399)" },
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            new_optimizations = true,
            xray              = false,
            noise             = 0.02,
            vibrancy          = 0.17,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Layer animations and rules from ~/.config/hypr/hyprland.lua (keep in sync).
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "popin 92%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2.5,  bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.5,  bezier = "easeOutQuint" })

hl.layer_rule({ name = "blur-qs-bar",      match = { namespace = "^qs-bar$" },      blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-qs-dropdown", match = { namespace = "^qs-dropdown$" }, blur = true, ignore_alpha = 0.3, no_anim = true })
