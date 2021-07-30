const std = @import("std");

const c = @import("c.zig");

/// the size of the view; pixels
const size_view = [2]comptime_int { 640, 480, };

/// how wide the view is; ratio between pixels and radians
const scale: comptime_float = 0.004;

/// the title of the view window
const window_title = "zig_ray";

/// how sensetive the mouse is; ratio between pixels and radians
const mouse_sensitivity: comptime_float = 0.001;

/// the maximum distance for a hit; less is more precise; space units
const hit_threshold: f32 = 0.01;

/// the furthest point to render; the size of the rendered cube; space units
const boundry: comptime_float = 10;

const space = [_]object_t {
    object_t {
        .sdf = struct {
            fn f (origin: triple_t) f32 {
                var a = origin;
                a[2] -= 10;
                return magnitude(a) - 2;
            }
        }.f,
        .colour = colour_t { 0x00, 0x00, 0xFF, },
    },
    object_t {
        .sdf = struct {
            fn f (origin: triple_t) f32 {
                var a = origin;
                a[2] -= 5;

                var q = @fabs(a) - @splat(3, @as(f32, 1.5));
                return magnitude(triple_t {
                    std.math.max(0, q[0],),
                    std.math.max(0, q[1],),
                    std.math.max(0, q[2],),
                }) + std.math.min(@reduce(.Max, q), 0);
            }
        }.f,
        .colour = colour_t { 0x00, 0xFF, 0x00, },
    },
};

/// an B.G.R. colour type
const colour_t = std.meta.Vector(3, u8,);

/// a floating, 2D vector type
const couple_t = std.meta.Vector(2, f32,);

/// a floating, 3D vector type
const triple_t = std.meta.Vector(3, f32,);



//TODO document...
/// a marching-ray type
const ray_t = struct {
    /// the current position of the ray; space units
    origin: triple_t,

    /// the direction of the ray; coordinates on a unit sphere
    direction: triple_t,
};

//TODO document...
const matireal_t = struct {
    colour: colour_t,
}

//TODO document...
/// an object type
const object_t = struct {
    /// the object's signed distance function; space units
    sdf: fn (triple_t) f32,

    /// the object's matireal
    matireal: matireal_t,
};


/// represents a 3D angle as coordinates on a unit sphere
///
/// angles: the x and y angles to represent; radians
//TODO add assertions
fn unit_sphere(angles: couple_t) triple_t {
    var xy = @sin(angles,);
    var z = @reduce(.Mul, @cos(angles,),);
    return triple_t { xy[0], xy[1], z, };
}


pub fn main() anyerror!void {
    try interactive_view();
}

fn magnitude(a: triple_t) f32 {
    return std.math.hypot(f32, a[0], std.math.hypot(f32, a[1], a[2]));
}
