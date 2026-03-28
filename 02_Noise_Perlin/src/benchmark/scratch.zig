const config = @import("config.zig");
const perlin_o6 = @import("../noise/perlin/06_licm.zig");

const I16Vec = @Vector(perlin_o6.Lanes, i16);
const I16_VEC_LANES: u64 = @typeInfo(I16Vec).vector.len;
const XCacheState = struct {
    sx: I16Vec,
    dot_x: [4]I16Vec,
};

pub fn bytes_for_mod(comptime mod: type) usize {
    if (mod != perlin_o6) return 0;
    const min_dim: u64 = @min(config.CHUNK_SIZE, config.SCALE);
    const vec_count: u64 = min_dim / I16_VEC_LANES;    
    return @as(usize, @intCast(vec_count)) * @sizeOf(XCacheState);
}

pub fn alignment_for_mod(comptime mod: type) comptime_int {

    if (mod != perlin_o6) return 1;
    return perlin_o6.RequiredAlignment;
}
