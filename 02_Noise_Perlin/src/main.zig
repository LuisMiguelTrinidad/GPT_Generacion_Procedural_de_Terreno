const std = @import("std");

const engine = @import("benchmark/engine.zig");

pub fn main() !void {
	var stdout_writer = std.fs.File.stdout().writer(&.{});
	var stderr_writer = std.fs.File.stderr().writer(&.{});

	const stdout = &stdout_writer.interface;
	const stderr = &stderr_writer.interface;

	const allocator = std.heap.page_allocator;

	const args = try std.process.argsAlloc(allocator);
	defer std.process.argsFree(allocator, args);

	if (args.len != 2) {
		try stderr.print(
			"USO: {s} <modo>\nModos disponibles: O0 | O1 | O2 | O3 | O4 | O5 | O6 | O7\n",
			.{args[0]},
		);
		return error.InvalidArguments;
	}

	const mode = engine.parse_mode(args[1]) orelse {
		try stderr.print("ERROR: Modo desconocido. Opciones: O0 | O1 | O2 | O3 | O4 | O5 | O6 | O7\n", .{});
		return error.InvalidMode;
	};

	switch (mode) {
		inline else => |comptime_mode| {
			try engine.run_mode(comptime_mode, allocator, stdout, stderr);
		},
	}
}