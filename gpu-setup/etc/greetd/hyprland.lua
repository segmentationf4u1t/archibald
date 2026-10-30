-- Hyprland for the greetd login screen (runs as the "greeter" user, started by /etc/greetd/config.toml).
-- It only shows the Quickshell greeter from /etc/greetd/quickshell and exits when the greeter does
-- (after a successful login), so greetd can start the user session. No binds: nothing else can be
-- started from the login screen.

-- Same GPU order as ~/.config/hypr/hyprland.lua: in the "RTX for host" boot the RTX 4070 renders
-- (the iiyama and the right BenQ are wired to it), in the normal boot the RTX belongs to vfio-pci and
-- the Quadro P400 is the only card. cardN numbers change between boots, so cards are found by PCI address.
-- Skipped when nested inside a running session (testing), where Hyprland uses the Wayland backend.
local function drmCard(pciSlot)
    for n = 0, 7 do
        local f = io.open("/sys/class/drm/card" .. n .. "/device/uevent")
        if f then
            local uevent = f:read("*a")
            f:close()
            if uevent:find("PCI_SLOT_NAME=" .. pciSlot, 1, true) then
                return "/dev/dri/card" .. n
            end
        end
    end
end

if os.getenv("WAYLAND_DISPLAY") == nil then
    local drmDevices = {}
    for _, pciSlot in ipairs({ "0000:01:00.0", "0000:07:00.0" }) do   -- first = primary renderer
        local card = drmCard(pciSlot)
        if card then
            drmDevices[#drmDevices + 1] = card
        end
    end
    if #drmDevices > 0 then
        hl.env("AQ_DRM_DEVICES", table.concat(drmDevices, ":"))
    end
end

hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_SIZE", "24")

-- Monitor layout as on the desktop (matched by description, connector names change between boots)
hl.monitor({ output = "desc:BNQ BenQ GW2480 S9J0069301Q",            mode = "preferred", position = "0x0",    scale = 1 })
hl.monitor({ output = "desc:iiyama Corporation PL2480C 1245053601761", mode = "1920x1080@180", position = "1920x0", scale = 1 })
hl.monitor({ output = "desc:BNQ BenQ GW2470 K1H08194019",            mode = "preferred", position = "3840x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
    general = {
        border_size = 0,
        gaps_in     = 0,
        gaps_out    = 0,
    },
    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = false },   -- the greeter blurs its own wallpaper
    },
    input = {
        kb_layout     = "pl",             -- password typed with the desktop layout (ą, ę, ... on AltGr)
        accel_profile = "flat",
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

hl.on("hyprland.start", function ()
    hl.exec_cmd("quickshell -p /etc/greetd/quickshell; hyprctl dispatch 'hl.dsp.exit()'")
end)
