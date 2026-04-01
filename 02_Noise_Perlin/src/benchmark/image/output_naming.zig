const std = @import("std");

pub fn make_composite_output_path(
	allocator: std.mem.Allocator,
	mode_str: []const u8,
	save_chunks_per_side: u64,
) ![]u8 {
	return try std.fmt.allocPrint(
		allocator,
		"output/perlin_composite_{d}x{d}_zig_{s}.png",
		.{ save_chunks_per_side, save_chunks_per_side, mode_str },
	);
}