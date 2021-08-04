const std = @import("std");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});


/// the size of the view; pixels
const size_view = [2]comptime_int { 640, 480, };

/// the title of the view window
const window_title = "zig_ray";

/// how sensetive the mouse is; ratio between pixels and radians
const mouse_sensitivity: comptime_float = 0.001;

/// the maximum distance for a hit; less is more precise; space units
const epsilon: f32 = 0.01;

/// the delta for the normal estimation; less is more precise; space units
const normal_delta: f32 = 0.01;


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


/// a type for all the objects in space
const space_t = struct {
    /// a list of all the objects to render
    objects: [3]object_t, //TODO do not specify a no. here, this should be dynamic!

    /// the camera location
    camera: camera_t,

    /// the colour of the boundries
    colour_boundries: colour_t = colour_t { 0, 0, 0, },

    /// the furthest point to render; the size of the rendered cube; space units
    dis_boundries: f32 = 20,
};

/// an B.G.R. colour type
const colour_t = std.meta.Vector(3, u8,);

/// a floating, 2D vector type
const couple_t = std.meta.Vector(2, f32,);

/// a floating, 3D vector type
const triple_t = std.meta.Vector(3, f32,);

/// a pixel buffer type with the size of the view
const buffer_t = [size_view[0] * size_view[1]]colour_t;

/// an individual ray type
const ray_t = struct {
    /// the current position of the ray; space units
    origin: triple_t,

    /// the direction of the ray; unit vector //TODO maybe Quaternions are better suited than unit vectors?
    direction: triple_t,
};

/// an matireal type; for handling rays that hit objects with it
const matireal_t = struct {
    /// the colour of the object
    colour: colour_t,
};

/// a type for objects in space
const object_t = struct {
    /// the object's signed distance function; space units
    sdf: fn (triple_t) f32,

    /// the normal of the surface; coordinates on a unit sphere
    normal: fn (triple_t) triple_t,

    /// the object's matireal
    matireal: matireal_t,
};

/// a type for camera location
const camera_t = struct {
    /// the position of the camera; space units
    position: triple_t = @splat(3, @as(f16, 0,),),

    /// the rotation of the camera; radians // TODO are Euler angles really the best for this?
    rotation: couple_t = @splat(2, @as(f16, 0,),),

    /// how wide the view is; ratio between pixels and radians
    scale: f32 = 0.004,
};


// TODO state that all the vectors are Cartesian

/// calculates the norm of a vector
///
/// a: the vector to calculate the norm of; space units
///
/// returns the norm of the vector; space units
fn norm(a: triple_t) f32 {
    return std.math.hypot(f32, a[0], std.math.hypot(f32, a[1], a[2]));
}

// /// estimates the normal of an object given an S.D.F. and a position
// ///
// /// origin: the position to calculate the normal of
// /// object: the object to calculate the normal of
// ///
// /// returns the normal as coordinates on a unit sphere
// fn estimate_normal(origin: triple_t, sdf: fn(triple_t) triple_t) triple_t {
//     const a = object.sdf(origin);
// 
//     var n = triple_t {
//         sdf(triple_t { origin[0] + normal_delta, origin[1], origin[2] }) - a,
//         sdf(triple_t { origin[0], origin[1] + normal_delta, origin[2] }) - a,
//         sdf(triple_t { origin[0], origin[1], origin[2] + normal_delta }) - a,
//     };
//     n = n / @splat(3, norm(n,),);
// 
//     return n;
// }

/// estimates the normal of an object given an S.D.F. and a position
///
/// origin: the position to calculate the normal of
/// object: the object to calculate the normal of
///
/// returns the normal as coordinates on a unit sphere
fn estimate_normal(comptime sdf: fn(triple_t) f32) fn (origin: triple_t) triple_t {
    return struct {
        fn f(origin: triple_t) triple_t {
            const a = sdf(origin);

            var n = triple_t {
                sdf(triple_t { origin[0] + normal_delta, origin[1], origin[2] }) - a,
                sdf(triple_t { origin[0], origin[1] + normal_delta, origin[2] }) - a,
                sdf(triple_t { origin[0], origin[1], origin[2] + normal_delta }) - a,
            };
            n = n / @splat(3, norm(n,),);

            return n;
        }
    }.f;
}

/// converts Euler angles to unit vectors
///
/// a: the x and y Euler angles to represent; radians
//TODO add assertions
fn unit_vector(a: couple_t) triple_t {
    var xy = @sin(a,);
    var z = @reduce(.Mul, @cos(a,),);
    return triple_t { xy[0], xy[1], z, };
}
// TODO pre-calculate the space-SDF around specific points in 3D space, for use as a "cache"
// TODO profiling, just profile everything

/// marches a ray with its direction until an object is hit, or the boundries are reached
///
/// ray: the ray to march, the function will update its origin
/// space: the space to march the ray in
///
/// returns a pointer to the object that was hit, or null in case the boundries were reached
fn march_ray(ray: *ray_t, space: *space_t) ?*object_t {
    // while the ray is within the boundries
    while (@reduce(.Max, @fabs(ray.origin)) < space.dis_boundries) {
        // calculate the SDF for all the objects in space
        var distances: [space.objects.len]f32 = undefined;

        for (space.objects) |obj, i| {
            distances[i] = obj.sdf(ray.origin);
        }

        var distance_min: f32 = std.math.inf(f32);
        for (distances) |distance| {
            distance_min = std.math.min(distance_min, distance);
        }

        // check for a hit
        if (distance_min < epsilon) {
            for (distances) |distance, i| {
                if (distance == distance_min) {
                    return &space.objects[i];
                }
            }
        }

        // step
        ray.origin += @splat(3, distance_min) * ray.direction;
    }

    return null;
}

// TODO document...
// TODO rename to direction
fn sphere_angles(coordinates: triple_t,) couple_t {
    return couple_t {
        std.math.asin(coordinates[0],),
        std.math.asin(coordinates[1],),
    };
}

/// traces a single ray through space and returns its colour
/// 
/// ray: the ray to trace
/// space: the space to trace the ray i
///
/// the resulting colour of the ray
fn trace_ray(ray: ray_t, space: *space_t) colour_t {
    const max_hits = 4;
    var ray_ = ray;
    var no_hits: u8 = 0;
    var sum_colour = space.colour_boundries;

    while (no_hits < max_hits) {
        no_hits += 1;

        const obj = march_ray(&ray_, space) orelse break;
        sum_colour += obj.matireal.colour / @splat(3, @as(u8, 4));
        
        ray_.direction = unit_vector(
            sphere_angles(ray_.direction) - sphere_angles(obj.normal(ray_.origin))
        );
        ray_.origin += @splat(3, epsilon) * ray_.direction;
    }

    return sum_colour;
}

/// renders a scene into a buffer
///
/// buffer: the output buffer
/// camera: the location of the camera in space
/// space: all the objects to consider
fn ray_march(
    buffer: *buffer_t,
    camera: camera_t,
    space: *space_t,
) void {
    // calculate a ray for every pixel in the view
    var y: usize = 0;
    while (y < size_view[1]) {
        var x: usize = 0;
        while (x < size_view[0]) {
            // determine the direction of the ray
            var ray_angles = @splat(2, @as(f32, space.camera.scale,),) * couple_t {
                @intToFloat(f32, x,) - @as(f32, size_view[0] >> 1),
                @intToFloat(f32, y) - @as(f32, size_view[1] >> 1),
            } + camera.rotation;

            var ray = ray_t {
                .origin = camera.position,
                .direction = unit_vector(ray_angles),
            };

            buffer[size_view[0] * y + x] = trace_ray(ray, space,);

            x += 1;
        }
        y += 1;
    }
}



// TODO organise the order of the funcions and such...

//TODO add comma (,) after each parameter in every function..



/// creates an interactive view window using SDL2
///
/// space: the space to present
pub fn view_interactive(space: *space_t,) !void {
    //TODO special config option for tracy
    const t = tracy.trace(@src());
    defer t.end();

    // initialise SDL
    if (c.SDL_Init(c.SDL_INIT_VIDEO,) != 0) {
        std.log.err("{s}", .{ c.SDL_GetError(), },);
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
        c.SDL_WINDOW_OPENGL,
    ) orelse {
        std.log.err("{s}", .{ c.SDL_GetError(), },);
        return error.sdl_window;
    };
    defer c.SDL_DestroyWindow(window,);

    // make the cursor stay hidden and inside the window
    if (c.SDL_SetRelativeMouseMode(c.SDL_TRUE,) != 0) {
        std.log.err("{s}", .{ c.SDL_GetError(), },);
        return error.sdl_mouse_mode;
    }
    c.SDL_WarpMouseInWindow(window, size_view[0] >> 1, size_view[1] >> 1);

    // create a renderer
    const renderer = c.SDL_CreateRenderer(
        window,
        0,
        c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
    ) orelse {
        std.log.err("{s}", .{ c.SDL_GetError(), },);
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
        std.log.err("{s}", .{ c.SDL_GetError(), },);
        return error.sdl_texture_create;
    };
    defer c.SDL_DestroyTexture(texture,);

    // declare a pixels buffer
    var buffer: buffer_t = undefined;

    // mouse movement, relative to the last frame; pixels
    var mouse_motion: couple_t = undefined;

    // camera state
    var camera: camera_t = camera_t {};

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
                    if (event.key.keysym.scancode == c.SDL_SCANCODE_Q) {
                        break :frames;
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
            camera.position += unit_vector(camera.rotation,);
        } else if (state_keys[c.SDL_SCANCODE_A] == 1) {
            var a = camera.rotation;
            a[0] -= std.math.pi / 2.0;
            camera.position += unit_vector(a,);
        } else if (state_keys[c.SDL_SCANCODE_S] == 1) {
            camera.position -= unit_vector(camera.rotation,);
        } else if (state_keys[c.SDL_SCANCODE_D] == 1) {
            var a = camera.rotation;
            a[0] += std.math.pi / 2.0;
            camera.position += unit_vector(a,);
        }

        // rotate the camera
        camera.rotation += @splat(2, @as(f32, mouse_sensitivity)) * mouse_motion;

        // render the view
        ray_march(&buffer, camera, space);

        // apply the buffer to the window
        if (c.SDL_UpdateTexture(
            texture,
            null,
            &buffer,
            size_view[0] * @sizeOf(colour_t),
        ) != 0) {
            std.log.err("{s}", .{ c.SDL_GetError(), },);
            return error.texture_update;
        }
        if (c.SDL_RenderClear(renderer,) != 0) {
            std.log.err("{s}", .{ c.SDL_GetError(), },);
            return error.sdl_render_clear;
        }
        if (c.SDL_RenderCopy(renderer, texture, null, null,) != 0) {
            std.log.err("{s}", .{ c.SDL_GetError(), },);
            return error.sdl_render_copy;
        }
        c.SDL_RenderPresent(renderer,);
    }
}
//TODO
    fn foo(origin: triple_t) f32 {
        var a = origin;
        a[2] -= 3;
        var b = std.math.hypot(f32, a[0], a[1]) - 1;
        return std.math.hypot(f32, b, a[2]) - 0.5;
    }
pub fn main() anyerror!void {
    var obj_a = object_t {
        .sdf = struct {
            fn f(origin: triple_t,) f32 {
                var a = origin;
                a[0] += 3;
                a[1] += 1.5;
                a[2] -= 5;
                return norm(a,) - 1;
            }
        }.f,
        .normal = struct {
            fn f(origin: triple_t,) triple_t {
                var a = origin;
                a[0] -= 3;
                a[1] -= 1.5;
                a[2] += 5;
                return a / @splat(3, norm(a,),);
            }
        }.f,
        .matireal = matireal_t {
            .colour = colour_t { 0x00, 0x00, 0xFF, },
        },
    };
    var obj_b = object_t {
        .sdf = struct {
            fn f(origin: triple_t) f32 {
                var a = origin;
                a[0] -= 5;

                var q = @fabs(a) - @splat(3, @as(f32, 1.5));
                return norm(triple_t {
                    std.math.max(0, q[0],),
                    std.math.max(0, q[1],),
                    std.math.max(0, q[2],),
                }) + std.math.min(@reduce(.Max, q), 0);
            }
        }.f,
        .normal = struct {
            fn f(origin: triple_t) triple_t {
                var a = [_]f32 { origin[0], origin[1], origin[2], };
                a[0] -= 5;

                var b: triple_t = triple_t { 0, 0, 0 };

                for (a) |v, i| {
                    if (v <= -1.5) {
                        b[i] = -1;
                    } else if (v >= 1.5) {
                        b[i] = 1;
                    }
                }

                return b / @splat(3, norm(b,),);
            }
        }.f,
        .matireal = matireal_t {
            .colour = colour_t { 0x00, 0xFF, 0x00, },
        },
    };
    var obj_c = object_t {
        .sdf = foo,
        .normal = estimate_normal(foo),
        .matireal = matireal_t {
            .colour = colour_t { 0x80, 0x10, 0xF0, },
        },
    };

    var my_space = space_t {
        .camera = camera_t {},
        .objects = [3]object_t { obj_a, obj_b, obj_c, },
        .colour_boundries = colour_t { 0, 0, 0, },
    };

    try view_interactive(&my_space);
}
