const std = @import("std");

const random = @import("random");

const HashChoice = enum {
	custom_v2,
	custom_v1,
	rapidhash,
};

const Result = struct {
	s_result: [65]u64 = [_]u64{0} ** 65,
	x_result: [65]u64 = [_]u64{0} ** 65,
	y_result: [65]u64 = [_]u64{0} ** 65,
};


const Sac = struct {
	s_sac: [64][64]u64 = [_][64]u64{[_]u64{0} ** 64} ** 64,
	x_sac: [64][64]u64 = [_][64]u64{[_]u64{0} ** 64} ** 64,
	y_sac: [64][64]u64 = [_][64]u64{[_]u64{0} ** 64} ** 64,
};

const WorkerCtx = struct {
	entries: u64,
	seed: u64,
	result: Result = .{},
	sac: Sac = .{}
};

fn add_sac(sac_dst: *Sac, sac_src: *const Sac) void {
	for (0..64) |i| {
		for (0..64) |j| {
			sac_dst.s_sac[i][j] += sac_src.s_sac[i][j];
			sac_dst.x_sac[i][j] += sac_src.x_sac[i][j];
			sac_dst.y_sac[i][j] += sac_src.y_sac[i][j];
		}
	}
}

fn add_results(result_dst: *Result, result_src: *const Result) void {
	for (0..65) |i| {
		result_dst.s_result[i] += result_src.s_result[i];
		result_dst.x_result[i] += result_src.x_result[i];
		result_dst.y_result[i] += result_src.y_result[i];
	}
}

fn printSacArray(writer: *std.Io.Writer, prefix: []const u8, arr: *const [64]u64) !void {
	try writer.print("{s}[", .{prefix});
	for (arr, 0..) |val, j| {
		try writer.print("{d}{s}", .{ val, if (j == 63) "" else "," });
	}
	try writer.print("]", .{});
}

fn print_results(stdout: *std.Io.Writer, global_results: *const Result, global_sac: *const Sac) !void {
	for (0..65) |i| {
		try stdout.print("{d:0>3}, {d:0>12}, {d:0>12}, {d:0>12}\n", .{ 
			i, global_results.s_result[i], global_results.x_result[i], global_results.y_result[i] 
		});
	}

	for (0..64) |i| {
		var s_sum: u64 = 0;
		var x_sum: u64 = 0;
		var y_sum: u64 = 0;

		for (0..64) |j| {
			s_sum += global_sac.s_sac[i][j];
			x_sum += global_sac.x_sac[i][j];
			y_sum += global_sac.y_sac[i][j];
		}

		try stdout.print("{d:0>3}: {d:0>12}, {d:0>12}, {d:0>12} | ", .{ i, s_sum, x_sum, y_sum });
        
		try printSacArray(stdout, "S", &global_sac.s_sac[i]);
		try stdout.print(" ", .{});
		try printSacArray(stdout, "X", &global_sac.x_sac[i]);
		try stdout.print(" ", .{});
		try printSacArray(stdout, "Y", &global_sac.y_sac[i]);
		try stdout.print("\n", .{});
	}
}

fn avalanche_worker(
	comptime hash_fn: anytype,
	ctx: *WorkerCtx
) void {
	var rng_state = random.xorshift64(ctx.seed ^ 0x9E3779B97F4A7C15);

	for (0..ctx.entries) |_| {
		rng_state = random.xorshift64(rng_state);
		const x: i64 = @bitCast(rng_state);

		rng_state = random.xorshift64(rng_state);
		const y: i64 = @bitCast(rng_state);

		rng_state = random.xorshift64(rng_state);
		const s = rng_state;

		const g1 = hash_fn(s, x, y);

		for (0..64) |bit_pos| {
			const bit_mask: u64 = @as(u64, 1) << @as(u6, @intCast(bit_pos));

			const g_s2 = hash_fn(s ^ bit_mask, x, y);
			const g_x2 = hash_fn(s, x ^ @as(i64, @bitCast(bit_mask)), y);
			const g_y2 = hash_fn(s, x, y ^ @as(i64, @bitCast(bit_mask)));

			const diff_s = g1 ^ g_s2;
			const diff_x = g1 ^ g_x2;
			const diff_y = g1 ^ g_y2;

			ctx.result.s_result[@popCount(g1 ^ g_s2)] += 1;
			ctx.result.x_result[@popCount(g1 ^ g_x2)] += 1;
			ctx.result.y_result[@popCount(g1 ^ g_y2)] += 1;

			for (0..64) |j| {
				ctx.sac.s_sac[bit_pos][j] += (diff_s >> @as(u6, @intCast(j))) & 1;
				ctx.sac.x_sac[bit_pos][j] += (diff_x >> @as(u6, @intCast(j))) & 1;
				ctx.sac.y_sac[bit_pos][j] += (diff_y >> @as(u6, @intCast(j))) & 1;
			}
		}
	}
}

fn runAvalanche64b(
	comptime hash_fn: anytype,
	stdout: *std.Io.Writer, 
	stderr: *std.Io.Writer, 
	number_of_entries: u64, 
	random_seed: u64
) !void {
	_ = stderr;
	var global_results: Result = .{};
	var global_sac: Sac = .{};

	const allocator = std.heap.page_allocator;
	const thread_count = try std.Thread.getCpuCount();

	var threads = try allocator.alloc(std.Thread, thread_count);
	defer allocator.free(threads);

	var contexts = try allocator.alloc(WorkerCtx, thread_count);
	defer allocator.free(contexts);

	const base = number_of_entries /  thread_count;
	const rem = number_of_entries % thread_count;

	for (0..thread_count) |t| {
		contexts[t] = .{
			.entries = if (t < rem) base + 1 else base, // Gestionar remanente
			.seed = random_seed ^ ((t + 1) *% 0x9E3779B97F4A7C15),
		};
		threads[t] = try std.Thread.spawn(.{}, avalanche_worker, .{hash_fn, &contexts[t]});
	}

	for (0..thread_count) |t| {
		threads[t].join();
		add_results(&global_results, &contexts[t].result);
		add_sac(&global_sac, &contexts[t].sac);
	}

	try print_results(stdout, &global_results, &global_sac);
}

pub fn main() !void {
	var stdout_writer = std.fs.File.stdout().writer(&.{});
	var stderr_writer = std.fs.File.stderr().writer(&.{});

	const stdout = &stdout_writer.interface;
	const stderr = &stderr_writer.interface;

	var gpa = std.heap.page_allocator;

	const args = try std.process.argsAlloc(gpa);
	defer gpa.free(args);

	if (args.len != 4) {
		stderr.print("USO: {s} <number_of_entries> <random_seed> <hash> \nHASH: custom_v2 | custom_v1 | rapidhash\n", .{args[0]}) catch {};
		return error.InvalidArguments;
	}

	const entries = try std.fmt.parseInt(u64, args[1], 10);
	const seed = try std.fmt.parseInt(u64, args[2], 10);
	const hash_choice = std.meta.stringToEnum(HashChoice, args[3]) orelse {
		stderr.print("ERROR: Hash desconocido. Opciones: custom_v2 | custom_v1 | rapidhash\n", .{}) catch {};
		return error.InvalidHashChoice;
	};


	switch (hash_choice) {
		.custom_v2 => try runAvalanche64b(
			random.custom_hash_v2_full, 
			stdout, stderr, 
			entries, seed
		),
		.custom_v1 => try runAvalanche64b(
			random.custom_hash_v1, 
			stdout, stderr, 
			entries, seed
		),
		.rapidhash => try runAvalanche64b(
			random.rapidhashnano_full, 
			stdout, stderr, 
			entries, seed
		),
	}
}
