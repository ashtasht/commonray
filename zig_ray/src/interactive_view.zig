const c = @import("c.zig");
const ray_marching = @import("ray_marching.zig");

/// error when initialising SDL2
const sdl_init = error.Failed;

/// error when creating an SDL2 window
const sdl_window = error.Failed;

/// error when creating an SDL2 renderer
const sdl_renderer = error.Failed;

/// error when creating an SDL2 texture
const sdl_texture_create = error.Failed;

/// error when updating an SDL2 texture
const sdl_texture_update = error.Failed;

/// error when clearing an SDL2 renderer
const sdl_render_clear = error.Failed;

/// error when copying an SDL2 texture
const sdl_render_copy = error.Failed;

/// error when waiting for an SDL2 event
const sdl_wait_event = error.Failed;

/// error when changing the SDL2 mouse mode
const sdl_mouse_mode = error.Failed;

/// creates an interactive view window using SDL2
///
/// size_view: the size and resolution of the view; pixels
/// render: a function that updates the buffer
fn view_interactive(
    size_view: [2]u16,
    render: fn (
        buffer: *[window_size[0] * window_size[1]]colour_t,
        camera: *state_camera_t,
    ) void,
) !void {
    // initialise SDL
    if (c.SDL_Init(c.SDL_INIT_VIDEO,) != 0) {
        return error.sdl_init;
    }
    defer c.SDL_Quit();

    // create a window
    const window = c.SDL_CreateWindow(
        window_title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        size_view[0],
        size_view[1],
        c.SDL_WINDOW_VULKAN,
    ) orelse {
        return error.sdl_window;
    };
    defer c.SDL_DestroyWindow(window,);

    // make the cursor stay hidden and inside the window
    if (c.SDL_SetRelativeMouseMode(c.SDL_bool.SDL_TRUE,) != 0) {
        return error.sdl_mouse_mode;
    }
    c.SDL_WarpMouseInWindow(window, size_view[0] >> 1, size_view[1] >> 1);

    // create a renderer
    const renderer = c.SDL_CreateRenderer(
        window,
        0,
        c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
    ) orelse {
        return error.sdl_renderer;
    };
    defer c.SDL_DestroyRenderer(renderer,);

    // create a texture
    const texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_RGB888,
        c.SDL_TEXTUREACCESS_STATIC,
        size_view[0],
        size_view[1],
    ) orelse {
        return error.sdl_texture_create;
    };
    defer c.SDL_DestroyTexture(texture,);

    // declare a pixels buffer
    var buffer: [size_view[0] * size_view[1]]colour_t = undefined;

    /// mouse movement, relative to the last frame; pixels
    var mouse_motion: couple_t = undefined;

    /// camera state
    camera: state_camera_t = state_camera_t {},

    var event: c.SDL_Event = undefined;

    // main rendering loop
    frames: while (true) {
        // reset the relative mouse position
        mouse_motion = @splat(2, @as(f32, 0));

        // update the state as needed
        while (c.SDL_PollEvent(&event) > 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    break :frames;
                },
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.scancode) {
                        c.SDL_Scancode.SDL_SCANCODE_Q => {
                            break :frames;
                        },
                        else => undefined,
                    }
                },
                c.SDL_MOUSEMOTION => {
                    mouse_motion[0] += @intToFloat(f32, event.motion.xrel,);
                    mouse_motion[1] += @intToFloat(f32, event.motion.yrel,);
                },
                else => undefined,
            }
        }

        // move the camera
        var state_keys = c.SDL_GetKeyboardState(null);

        if (state_keys[c.SDL_SCANCODE_W] == 1) {
            camera.position += unit_sphere(camera.rotation,);
        } else if (state_keys[c.SDL_SCANCODE_A] == 1) {
            var a = camera.rotation;
            a[0] -= std.math.pi / 2.0;
            camera.position += unit_sphere(a,);
        } else if (state_keys[c.SDL_SCANCODE_S] == 1) {
            camera.position -= unit_sphere(camera.rotation,);
        } else if (state_keys[c.SDL_SCANCODE_D] == 1) {
            var a = camera.rotation;
            a[0] += std.math.pi / 2.0;
            camera.position += unit_sphere(a,);
        }

        // rotate the camera
        camera.rotation += @splat(2, @as(f32, mouse_sensitivity)) * mouse_motion;

        // render the view
        render(&buffer, &camera);

        // apply the buffer to the window
        if (c.SDL_UpdateTexture(
            texture,
            null,
            &buffer,
            size_view[0] * @sizeOf(colour_t),
        ) != 0) {
            return error.texture_update;
        }
        if (c.SDL_RenderClear(renderer,) != 0) {
            return error.sdl_render_clear;
        }
        if (c.SDL_RenderCopy(renderer, texture, null, null,) != 0) {
            return error.sdl_render_copy;
        }
        c.SDL_RenderPresent(renderer,);
    }
}
