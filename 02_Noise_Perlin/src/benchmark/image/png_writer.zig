const std = @import("std");
const zigimg = @import("zigimg");
const image_types = @import("types.zig");

pub fn write_gray8_png_owned(
	allocator: std.mem.Allocator,
	stdout: anytype,
	stderr: anytype,
	image: image_types.Gray8Image,
	output_path: []const u8,
) !void {
	_ = stderr;
	errdefer allocator.free(image.pixels);

	var img = try zigimg.Image.fromRawPixelsOwned(image.width, image.height, image.pixels, .grayscale8);
	defer img.deinit(allocator);

	try std.fs.cwd().makePath("output");
	const write_buf: []u8 = try allocator.alloc(u8, (image.width * image.height));
	defer allocator.free(write_buf);

	try img.writeToFilePath(allocator, output_path, write_buf, .{ .png = .{} });
	try stdout.print("Saved composite to {s}\n", .{output_path});
}