const std = @import("std");

const random = @import("random");

const HashChoice = enum {
	custom_v2,
	custom_v1,
	rapidhash,
};

fn patternTest(
	comptime hash_fn: anytype,
	allocator: std.mem.Allocator, 
	s_in: u64, 
	x_in: i64, 
	y_in: i64, 
	size: usize, 
	out_dir: []const u8
) !void {
	const total_pixels = size * size;

	const xy_data = try allocator.alloc(u64, total_pixels);
	defer allocator.free(xy_data);

	const xs_data = try allocator.alloc(u64, total_pixels);
	defer allocator.free(xs_data);

	const sy_data = try allocator.alloc(u64, total_pixels);
	defer allocator.free(sy_data);

	for (0..size) |i| {
		for (0..size) |j| {
			const x_abs = x_in + @as(i64, @bitCast(j));
			const y_abs = y_in + @as(i64, @bitCast(i));

			xy_data[(size - 1 - i) * size + j] = hash_fn(s_in, x_abs, y_abs);
			xs_data[(size - 1 - i) * size + j] = hash_fn(s_in + i, x_abs, y_in);
			sy_data[(size - 1 - i) * size + j] = hash_fn(s_in + j, x_in, y_abs);
		}
	}

	try std.fs.cwd().makePath(out_dir);

	// 1. Array XY
	const path_xy = try std.fmt.allocPrint(allocator, "{s}/pattern_xy.bin", .{out_dir});
	defer allocator.free(path_xy);
	
	var file_xy = try std.fs.cwd().createFile(path_xy, .{});
	defer file_xy.close();
	
	var writer_xy = std.fs.File.writer(file_xy, &.{});
	try writer_xy.interface.writeAll(std.mem.sliceAsBytes(xy_data));

	// 2. Array XS
	const path_xs = try std.fmt.allocPrint(allocator, "{s}/pattern_xs.bin", .{out_dir});
	defer allocator.free(path_xs);
	
	var file_xs = try std.fs.cwd().createFile(path_xs, .{});
	defer file_xs.close();
	
	var writer_xs = std.fs.File.writer(file_xs, &.{});
	try writer_xs.interface.writeAll(std.mem.sliceAsBytes(xs_data));

    // 3. Array SY
	const path_sy = try std.fmt.allocPrint(allocator, "{s}/pattern_sy.bin", .{out_dir});
	defer allocator.free(path_sy);
	
	var file_sy = try std.fs.cwd().createFile(path_sy, .{});
	defer file_sy.close();
	
	var writer_sy = std.fs.File.writer(file_sy, &.{});
	try writer_sy.interface.writeAll(std.mem.sliceAsBytes(sy_data));
}

pub fn main() !void {
	var gpa = std.heap.page_allocator;

	const args = try std.process.argsAlloc(gpa);
	defer gpa.free(args);

	if (args.len != 7) {
		std.debug.print("USO: <s> <x> <y> <size> <out_dir> <hash> \nHASH: custom_v2 | custom_v1 | rapidhash\n", .{});
		return error.InvalidArguments;
	}

	const s = try std.fmt.parseInt(u64, args[1], 10);
	const x = try std.fmt.parseInt(i64, args[2], 10);
	const y = try std.fmt.parseInt(i64, args[3], 10);
	const size = try std.fmt.parseInt(usize, args[4], 10);
	const out_dir = args[5];
	const hash_choice = std.meta.stringToEnum(HashChoice, args[6]) orelse {
		std.debug.print("ERROR: Hash desconocido. Opciones: custom_v2 | custom_v1 | rapidhash\n", .{});
		return error.InvalidHashChoice;
	};

	switch (hash_choice) {
		.custom_v2 => try patternTest(
			random.custom_hash_v2_full, gpa, 
			s, x, y, size, out_dir
		),
		.custom_v1 => try patternTest(
			random.custom_hash_v1, gpa, 
			s, x, y, 
			size, out_dir
		),
		.rapidhash => try patternTest(
			random.rapidhashnano_full, gpa, 
			s, x, y, 
			size, out_dir
		)
	}
}
