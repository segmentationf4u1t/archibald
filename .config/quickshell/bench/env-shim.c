// LD_PRELOAD shims for bench/env's compositor scope: cage hosting a nested Hyprland, on the NVIDIA
// driver. `env start` builds this file twice (gcc -shared -fPIC) into its state dir:
//   -DSHIM_CAGE      -> env-shim-cage.so, preloaded into cage (needs the wlroots dev headers)
//   -DSHIM_HYPRLAND  -> env-shim-hypr.so, preloaded into the nested Hyprland
// cage is a kiosk host and Hyprland's nested (aquamarine) backend expects a friendlier one; none of
// these are bugs worth patching upstream for a throwaway benchmark host.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>

#ifdef SHIM_CAGE

#define WLR_USE_UNSTABLE
#include <wlr/types/wlr_xdg_shell.h>

// cage creates xdg_wm_base at version 5, but aquamarine binds version 6 and the host kills it with
// a protocol error. wlroots implements 6 just fine.
struct wlr_xdg_shell *wlr_xdg_shell_create(struct wl_display *display, uint32_t version) {
    struct wlr_xdg_shell *(*real)(struct wl_display *, uint32_t) = dlsym(RTLD_NEXT, "wlr_xdg_shell_create");
    return real(display, version < 6 ? 6 : version);
}

// aquamarine commits its first buffer before it acks the first configure (its xdg_toplevel.configure
// handler does all the monitor setup and commits; xdg_surface.configure is handled a dispatch
// later). wlroots rejects such a commit (xdg_surface error "unconfigured_buffer") and cage drops
// the connection; swallowing the error is not enough either, the rejected commit's frame callback
// is gone and Hyprland's frame loop then waits for it forever. cage sets a new toplevel's size
// right at its initial commit, before any configure is sent: from there on treat the surface as
// configured, so the early buffer is accepted and mapped like a well-ordered client's.
uint32_t wlr_xdg_toplevel_set_size(struct wlr_xdg_toplevel *toplevel, int32_t width, int32_t height) {
    uint32_t (*real)(struct wlr_xdg_toplevel *, int32_t, int32_t) = dlsym(RTLD_NEXT, "wlr_xdg_toplevel_set_size");
    toplevel->base->configured = true;
    return real(toplevel, width, height);
}

#endif  // SHIM_CAGE

#ifdef SHIM_HYPRLAND

struct gbm_device;
struct gbm_bo;

#define GBM_BO_USE_LINEAR_FLAG 0x10

// cage's headless output only gets aquamarine to ask for a LINEAR-only swapchain, and NVIDIA's GBM
// cannot allocate those (nor GBM_BO_USE_LINEAR at all): Hyprland would fail to create its output
// and loop on the error. Fall back to a driver-chosen layout, which the host imports fine (it
// advertises the block-linear modifiers).
struct gbm_bo *gbm_bo_create(struct gbm_device *dev, uint32_t w, uint32_t h, uint32_t format, uint32_t flags) {
    struct gbm_bo *(*real)(struct gbm_device *, uint32_t, uint32_t, uint32_t, uint32_t) = dlsym(RTLD_NEXT, "gbm_bo_create");
    return real(dev, w, h, format, flags & ~GBM_BO_USE_LINEAR_FLAG);
}

struct gbm_bo *gbm_bo_create_with_modifiers2(struct gbm_device *dev, uint32_t w, uint32_t h, uint32_t format,
                                             const uint64_t *modifiers, unsigned count, uint32_t flags) {
    struct gbm_bo *(*real)(struct gbm_device *, uint32_t, uint32_t, uint32_t, const uint64_t *, unsigned, uint32_t) =
        dlsym(RTLD_NEXT, "gbm_bo_create_with_modifiers2");
    struct gbm_bo *bo = real(dev, w, h, format, modifiers, count, flags);
    if (!bo && count == 1 && modifiers[0] == 0)  // DRM_FORMAT_MOD_LINEAR only
        bo = gbm_bo_create(dev, w, h, format, flags);
    return bo;
}

#endif  // SHIM_HYPRLAND
