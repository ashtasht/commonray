/// a type for camera location
const camera_t = struct {
    /// the position of the camera; space units
    position: triple_t = @splat(3, @as(f16, 0,),),

    /// the rotation of the camera; radians
    rotation: couple_t = @splat(2, @as(f16, 0,),),
};

const space_t = struct {
    objects: []object_t,
    camera: camera_t,
}

//TODO: document...
fn ray_march(ray: *ray_t) colour_t {
    // while the ray is within the boundries
    //TODO: substract the camera position from ray.origin
    while (@reduce(.Max, @fabs(ray.origin)) < boundry) {
        var distances: std.meta.Vector(space.len, f32,) = undefined;

        for (space) |obj, i| {
            distances[i] = obj.sdf(ray.origin);
        }

        const distance_min = @reduce(.Min, distances);

        if (distance_min < hit_threshold) {
            var i: u8 = 0;
            while (distances[i] != distance_min) {
                i += 1;
            }
            return space[i].colour;
        }

        ray.origin += @splat(3, distance_min) * ray.direction;
    }
    return colour_t { 0, 0, 0, }; //TODO sky colour
}

/// renders a scene into a buffer
///
/// size_view: the size of the view; pixels
/// buffer: the output buffer
/// camera: the location of the camera in space
/// space: all the objects to consider
fn render(
    size_view: [2]u16,
    buffer: *[size_view[0] * size_view[1]]colour_t,
    camera: state_camera_t,
    space: space_t,
) void {
    // calculate a ray for every pixel in the view
    var y: usize = 0;
    while (y < size_view[1]) {
        var x: usize = 0;
        while (x < size_view[0]) {
            // determine the direction of the ray
            var ray_angles = @splat(2, @as(f32, scale,),) * couple_t {
                @intToFloat(f32, x,) - @as(f32, size_view[0] >> 1),
                @intToFloat(f32, y) - @as(f32, size_view[1] >> 1),
            } + camera.rotation;

            var ray = ray_t {
                .origin = camera.position,
                .direction = unit_sphere(ray_angles),
            };

            buffer[window_size[0] * y + x] = ray_march(&ray, space,);

            x += 1;
        }
        y += 1;
    }
}
