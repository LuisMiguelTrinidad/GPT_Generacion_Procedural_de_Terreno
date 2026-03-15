const std = @import("std");

const random = @import("random");
const cycle_counter = @import("cycle_counter");

const HashChoice = enum {
	custom_v2,
	custom_v1,
	rapidhash,
};

fn testControllerWithInit(
	comptime hash_fn: anytype,
	comptime init_fn: anytype,
	stdout: *std.io.Writer,
	stderr: *std.io.Writer,
	reps: u64,
	batch_size: u64,
	seed: u64,
) !void {
	_ = stderr;

	const seed_initialized = init_fn(seed);

	for (0..batch_size) |i| {
		std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(i), @bitCast(i)));
	}

	for (0..reps) |r| {
		const offset = r * batch_size;
		const t0 = cycle_counter.read();
		
		var i: u64 = 0;
		while (i < batch_size) : (i += 8) {
			const base = offset + i;

			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 0), @bitCast(base + 0)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 1223), @bitCast(base + 1223)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 4567), @bitCast(base + 4567)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 7919), @bitCast(base + 7919)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 9973), @bitCast(base + 9973)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 10439), @bitCast(base + 10439)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(base + 17449), @bitCast(base + 17449)));
			std.mem.doNotOptimizeAway(hash_fn(seed_initialized, @bitCast(i), @bitCast(i)));
		}
		const elapsed_cycles: f64 = @floatFromInt(cycle_counter.read() - t0);
		const cycles_per_hash = elapsed_cycles / @as(f64, @floatFromInt(batch_size));
		
		try stdout.print("REP {d: >4} : {d:.4} cycles/hash\n", .{ r, cycles_per_hash });
	}
}

fn testControllerNoInit(
	comptime hash_fn: anytype,
	stdout: *std.io.Writer,
	stderr: *std.io.Writer,
	reps: u64,
	batch_size: u64,
	seed: u64,
) !void {
	_ = stderr;

	for (0..batch_size) |i| {
		std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(i), @bitCast(i)));
	}
	for (0..reps) |r| {
		const offset = r * batch_size;
		const t0 = cycle_counter.read();

		var i: u64 = 0;
		while (i < batch_size) : (i += 8) {
			const base = offset + i;
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 0), @bitCast(base + 0)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 1223), @bitCast(base + 1223)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 4567), @bitCast(base + 4567)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 7919), @bitCast(base + 7919)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 9973), @bitCast(base + 9973)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 10439), @bitCast(base + 10439)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(base + 17449), @bitCast(base + 17449)));
			std.mem.doNotOptimizeAway(hash_fn(seed, @bitCast(i), @bitCast(i)));
		}
		const elapsed_cycles: f64 = @floatFromInt(cycle_counter.read() - t0);
		const cycles_per_hash = elapsed_cycles / @as(f64, @floatFromInt(batch_size));
		
		try stdout.print("REP {d: >4} : {d:.4} cycles/hash\n", .{ r, cycles_per_hash });
	}
}

pub fn main() !void {
	var stdout_writer = std.fs.File.stdout().writer(&.{});
	var stderr_writer = std.fs.File.stderr().writer(&.{});
	const stdout = &stdout_writer.interface;
	const stderr = &stderr_writer.interface;

	var gpa = std.heap.page_allocator;

	const args = try std.process.argsAlloc(gpa);
	defer gpa.free(args);

	if (args.len != 5) {
		try stderr.print("USO: <reps> <batch_size> <seed> <hash>\nHASH: custom_v2 | custom_v1 | rapidhash\n",.{});
		return error.InvalidArguments;
	}

	const reps: u64 = try std.fmt.parseInt(u64, args[1], 10);
	const batch_size: u64 = try std.fmt.parseInt(u64, args[2], 10);
	const seed: u64 = try std.fmt.parseInt(u64, args[3], 10);
	const hash_choice = std.meta.stringToEnum(HashChoice, args[4]) orelse {
		try stderr.print("ERROR: Hash desconocido. Opciones: custom_v2 | custom_v1 | rapidhash\n", .{});
		return error.InvalidHashChoice;
	};

	if (batch_size % 8 != 0) {
		try stderr.print("ERROR: Para maximo rendimiento, batch_size DEBE ser multiplo de 8.\n", .{});
		return error.InvalidBatchSize;
	}

	switch (hash_choice) {
		.custom_v2 => try testControllerWithInit(
			random.custom_hash_v2_no_init, random.custom_hash_init_v2, 
			stdout, stderr, 
			reps, batch_size, seed
		),
		.custom_v1 => try testControllerNoInit(
			random.custom_hash_v1,
			stdout, stderr, 
			reps, batch_size, seed
		),
		.rapidhash => try testControllerWithInit(
			random.rapidhashnano_no_init, random.rapidhashnano_init_seed,
			stdout, stderr, 
			reps, batch_size, seed
		)
	}
}
