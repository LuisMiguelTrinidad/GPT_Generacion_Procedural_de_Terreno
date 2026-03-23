const std = @import("std");

const random = @import("random");

const WINDOW_16_SIZE: usize = 65536;
const NUM_WINDOWS: usize = 4;

const HashChoice = enum {
	custom_v2,
	custom_v1,
	rapidhash,
};

const WorkerCtx = struct {
	samples: u64,
	seed: u64,
	counts: [64]u64 = [_]u64{0} ** 64,
	histogram_16b: []u64,
};

fn uniformity_worker(comptime hash_fn: anytype, ctx: *WorkerCtx) void {
	var thread_rng = random.xorshift64(ctx.seed);

	for (0..ctx.samples) |_| {
		thread_rng = random.xorshift64(thread_rng);
		const s = thread_rng;
		thread_rng = random.xorshift64(thread_rng);
		const x: u64 = thread_rng;
		thread_rng = random.xorshift64(thread_rng);
		const y: u64 = thread_rng;

		const val = hash_fn(s, x, y);
		for (0..64) |b| {
			ctx.counts[b] += (val >> @as(u6, @intCast(b))) & 1;
		}

		ctx.histogram_16b[(0 * WINDOW_16_SIZE) + ((val >>  0) & 0xFFFF)] += 1;
		ctx.histogram_16b[(1 * WINDOW_16_SIZE) + ((val >> 16) & 0xFFFF)] += 1;
		ctx.histogram_16b[(2 * WINDOW_16_SIZE) + ((val >> 32) & 0xFFFF)] += 1;
		ctx.histogram_16b[(3 * WINDOW_16_SIZE) + ((val >> 48) & 0xFFFF)] += 1;
	}
}

fn runSamples(
	comptime hash_fn: anytype,
	allocator: std.mem.Allocator,
	num_samples: u64,
	counts: *[64]u64,
	histogram_16b: []u64,
	global_seed: u64
) !void {
	const bins = NUM_WINDOWS * WINDOW_16_SIZE;
	const thread_count = try std.Thread.getCpuCount();

	var threads = try allocator.alloc(std.Thread, thread_count);
	defer allocator.free(threads);

	var contexts = try allocator.alloc(WorkerCtx, thread_count);
	defer allocator.free(contexts);

	const base = num_samples / thread_count;
	const rem = num_samples % thread_count;

	for (0..thread_count) |t| {
		const local_hist = try allocator.alloc(u64, bins);
		@memset(local_hist, 0);

		contexts[t] = .{
			.samples = base + @intFromBool(t < rem),
			.seed = global_seed ^ ((t + 1) *% 0x9E3779B97F4A7C15),
			.histogram_16b = local_hist,
		};

		threads[t] = try std.Thread.spawn(.{}, uniformity_worker, .{hash_fn, &contexts[t]});
	}

	for (0..thread_count) |t| {
		threads[t].join();

		for (0..64) |b| {
			counts[b] += contexts[t].counts[b];
		}
		for (0..bins) |i| {
			histogram_16b[i] += contexts[t].histogram_16b[i];
		}
		allocator.free(contexts[t].histogram_16b);
	}
}

fn chiSquareWindow(histogram_16b: []const u64, window_idx: usize, total_samples: u64) f64 {
	const expected = @as(f64, @floatFromInt(total_samples)) / @as(f64, @floatFromInt(WINDOW_16_SIZE));
	var chi2: f64 = 0.0;
	const base = window_idx * WINDOW_16_SIZE;

	for (0..WINDOW_16_SIZE) |i| {
	const diff = @as(f64, @floatFromInt(histogram_16b[base + i])) - expected;
		chi2 += diff * diff;
	}
	return chi2 / expected;
}

fn entropyAvg16b(histogram_16b: []const u64, total_samples: u64) f64 {
	var sum_entropy: f64 = 0.0;
	const total = @as(f64, @floatFromInt(total_samples));

	for (0..NUM_WINDOWS) |w| {
		var w_ent: f64 = 0.0;
		const base = w * WINDOW_16_SIZE;

		for (0..WINDOW_16_SIZE) |i| {
			const h = histogram_16b[base + i];
			if (h == 0) continue;
			const p = @as(f64, @floatFromInt(h)) / total;
			w_ent -= p * std.math.log2(p);
		}
		sum_entropy += w_ent;
	}
	return sum_entropy / @as(f64, @floatFromInt(NUM_WINDOWS));
}

fn testController(
	comptime hash_fn: anytype,
	stdout: *std.io.Writer,
	stderr: *std.io.Writer,
	allocator: std.mem.Allocator,
	max_samples: u64,
	start_log_in: u64,
	log_factor: f64,
	seed: u64
) !void {
	_ = stderr;
    
	var counts: [64]u64 = [_]u64{0} ** 64;
	const histogram_16b = try allocator.alloc(u64, NUM_WINDOWS * WINDOW_16_SIZE);
	defer allocator.free(histogram_16b);
	@memset(histogram_16b, 0);

	var total: u64 = 0;
	var start_log = start_log_in;
	
	var i: u64 = 0;
	while (total < max_samples) : (i += 1) {
		const target = @min(max_samples, @max(start_log, total + 1));

		try runSamples(
			hash_fn, 
			allocator, 
			target - total, 
			&counts, 
			histogram_16b, 
			seed + i
		);
		total = target;

		const c0 = chiSquareWindow(histogram_16b, 0, total);
		const c1 = chiSquareWindow(histogram_16b, 1, total);
		const c2 = chiSquareWindow(histogram_16b, 2, total);
		const c3 = chiSquareWindow(histogram_16b, 3, total);
		const ent = entropyAvg16b(histogram_16b, total);

		try stdout.print("{{{d:0>15}, {d:.2}, {d:.2}, {d:.2}, {d:.2}, {d:.8}}}\n", .{ total, c0, c1, c2, c3, ent });

    start_log = @max(@as(u64, @intFromFloat(@as(f64, @floatFromInt(start_log)) * log_factor)), total + 1);
	}

	try stdout.print("\n\nDistribucion final de bits (frecuencia de 1s):", .{});
	for (0..64) |bit| {
		if ((bit & 7) == 0) {
			try stdout.print("\n", .{});
		}
		try stdout.print("{d:0>3}: {d:0>12}, ", .{ bit, counts[bit] });
	}
	try stdout.print("\n", .{});
}

pub fn main() !void {
	var stdout_writer = std.fs.File.stdout().writer(&.{});
	var stderr_writer = std.fs.File.stderr().writer(&.{});

	const stdout = &stdout_writer.interface;
	const stderr = &stderr_writer.interface;

	var gpa = std.heap.page_allocator;

	const args = try std.process.argsAlloc(gpa);
	defer gpa.free(args);

	if (args.len != 6) {
		try stderr.print("USO: {s} <num_samples> <start_log> <log_factor> <seed> <hash>\nHASH: custom_v2 | custom_v1 | rapidhash\n", .{args[0]});
		return error.InvalidArguments;
	}
	const num_samples = try std.fmt.parseInt(u64, args[1], 10);
	const start_log = try std.fmt.parseInt(u64, args[2], 10);
	const log_factor = try std.fmt.parseFloat(f64, args[3]);
	const seed = try std.fmt.parseInt(u64, args[4], 10);
	const hash_choice = std.meta.stringToEnum(HashChoice, args[5]) orelse {
		try stderr.print("ERROR: Hash desconocido. Opciones: custom_v2 | custom_v1 | rapidhash\n", .{});
		return error.InvalidHashChoice;
	};

	switch (hash_choice) {
		.custom_v2 => try testController(
			random.custom_hash_v2_full, 
			stdout, stderr, 
			gpa, 
			num_samples, 
			start_log,
			log_factor, 
			seed
		),
		.custom_v1 => try testController(
			random.custom_hash_v1_full, 
			stdout, stderr, 
			gpa, 
			num_samples, 
			start_log,
			log_factor, 
			seed
		),		
		.rapidhash => try testController(
			random.rapidhashnano_full, 
			stdout, stderr, 
			gpa, 
			num_samples, 
			start_log,
			log_factor, 
			seed
		),
	}
}
