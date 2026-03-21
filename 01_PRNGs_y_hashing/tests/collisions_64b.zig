const std = @import("std");
const random = @import("random");

const HashChoice = enum {
	custom_v2,
	custom_v1,
	rapidhash,
};

const Result = struct {
	x_collisions: @Vector(8, u64) = @splat(0),
	y_collisions: @Vector(8, u64) = @splat(0),
};

const WorkerCtx = struct {
	number_of_seeds: u64,
	exploration_depth: u64,
	seed: u64,
	result: Result = .{},
};

fn reduce_results(result_dst: *Result, result_src: *const Result) void {
	result_dst.x_collisions += result_src.x_collisions;
	result_dst.y_collisions += result_src.y_collisions;
}

fn collision_worker(comptime hash_fn: anytype, ctx: *WorkerCtx) void {
	var prng = random.xorshift64(ctx.seed);

	const vec_ones: @Vector(8, u64) = @splat(1);
	const vec_zeros: @Vector(8, u64) = @splat(0);
	const vec_zero_bytes: @Vector(8, u8) = @splat(0);

	for (0..ctx.number_of_seeds) |_| {
		const seed = prng;
		prng = random.xorshift64(prng);
		const x = @as(i64, @bitCast(prng));
		prng = random.xorshift64(prng);
		const y = @as(i64, @bitCast(prng));

		const base_hash = hash_fn(seed, x, y);
		var hash_x_n0 = base_hash;
    var hash_y_n0 = base_hash;

    // Un solo bucle para X e Y
    for (0..ctx.exploration_depth) |offset| {
      // Sumamos 1 directamente aquí para reutilizarlo en ambas coordenadas
      const offset_i64 = @as(i64, @bitCast(offset)) + 1;

      const hash_x_n1 = hash_fn(seed, x + offset_i64, y);
			const v_diff_x: @Vector(8, u8) = @bitCast(hash_x_n0 ^ hash_x_n1);
      const is_zero_x = v_diff_x == vec_zero_bytes;
            
    	ctx.result.x_collisions += @select(u64, is_zero_x, vec_ones, vec_zeros);
      hash_x_n0 = hash_x_n1;

      // --- Exploración Vertical (Y) ---
      const hash_y_n1 = hash_fn(seed, x, y + offset_i64);
      const v_diff_y: @Vector(8, u8) = @bitCast(hash_y_n0 ^ hash_y_n1);
      const is_zero_y = v_diff_y == vec_zero_bytes;
            
      ctx.result.y_collisions += @select(u64, is_zero_y, vec_ones, vec_zeros);
      hash_y_n0 = hash_y_n1;
    }

		prng = random.xorshift64(prng);
	}
}

fn print_results(stdout: *std.Io.Writer, global_results: *const Result) !void {
	const arr_x: [8]u64 = global_results.x_collisions;
	const arr_y: [8]u64 = global_results.y_collisions;

	for (0..8) |w| {
		try stdout.print("  Byte {d} | {d:12} | {d:12} \n", .{w, arr_x[w], arr_y[w]});
	}
}

fn runCollisions64b(
	comptime hash_fn: anytype,
	stdout: *std.Io.Writer,
	stderr: *std.Io.Writer,
	depth: u64,
	number_of_seeds: u64,
	random_seed: u64,
) !void {
	_ = stderr;
	var global_results: Result = .{};

	const allocator = std.heap.page_allocator;
	const thread_count = try std.Thread.getCpuCount();

	var threads = try allocator.alloc(std.Thread, thread_count);
	defer allocator.free(threads);

	var contexts = try allocator.alloc(WorkerCtx, thread_count);
	defer allocator.free(contexts);

	const base = number_of_seeds / thread_count;
	const rem = number_of_seeds % thread_count;

	for (0..thread_count) |t| {
		contexts[t] = .{
			.number_of_seeds = base + @as(u64, @intFromBool(t < rem)),
			.exploration_depth = depth,
			.seed = random_seed ^ ((t + 1) *% 0x9E3779B97F4A7C15),
		};
		threads[t] = try std.Thread.spawn(
			.{},
			collision_worker,
			.{ hash_fn, &contexts[t] },
		);
	}

	for (0..thread_count) |t| {
		threads[t].join();
		reduce_results(&global_results, &contexts[t].result);
	}

	try print_results(stdout, &global_results);
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
		try stderr.print("USO: {s} <number_of_seeds> <exploration_depth> <random_seed> <hash> \nHASH: custom_v2 | custom_v1 | rapidhash\n", .{args[0]});
		return error.InvalidArguments;
	}

	const seeds = try std.fmt.parseInt(u64, args[1], 10);
	const depth: u64 = try std.fmt.parseInt(u64, args[2], 10);
	const seed = try std.fmt.parseInt(u64, args[3], 10);
	const hash_choice = std.meta.stringToEnum(HashChoice, args[4]) orelse {
		std.debug.print("ERROR: Hash desconocido. Opciones: custom_v2 | custom_v1 | rapidhash\n", .{});
		return error.InvalidHashChoice;
	};

	switch (hash_choice) {
		.custom_v2 => try runCollisions64b(
			random.custom_hash_v2_full, 
			stdout, stderr,
			depth, seeds, seed
		),
		.custom_v1 => try runCollisions64b(
			random.custom_hash_v1_full, 
			stdout, stderr, 
			depth, seeds, seed
		),
		.rapidhash => try runCollisions64b(
			random.rapidhashnano_full, 
			stdout, stderr, 
			depth, seeds, seed
		),
	}
}