const std = @import("std");

const random = @import("random");
const cycle_counter = @import("cycle_counter");

const HashChoice = enum {
	custom_v2,
	custom_v1,
	rapidhash,
};

inline fn _opaque(val: u64) u64 {
	var res = val;
	// "+r" significa que la variable entra y sale de un registro general.
	asm volatile ("" : [res] "+r" (res));
	return res;
}

fn testController(
	comptime hash_fn: anytype,
	stdout: *std.io.Writer,
	stderr: *std.io.Writer,
	reps: u64,
	batch_size: u64,
	state: anytype, 
) !void {
	_ = stderr;

	for (0..reps) |r| {
		const offset = r * batch_size;
		const t0 = cycle_counter.read();
				
		var i: u64 = 0;
		while (i < batch_size) : (i += 8) {
			const base = offset + i;

			// 1. Calculamos las bases con la suma o XOR (muy barato).
			// 2. Las pasamos por 'opaque()' para borrarle la memoria a LLVM.
			// 3. Ejecutamos el hash puramente en registros.
			const v0 = _opaque(base ^ 0);
			const v1 = _opaque(base ^ 1223);
			const v2 = _opaque(base ^ 4567);
			const v3 = _opaque(base ^ 7919);
			const v4 = _opaque(base ^ 9973);
			const v5 = _opaque(base ^ 10439);
			const v6 = _opaque(base ^ 17449);
			const v7 = _opaque(base ^ 99991);

			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v0), @bitCast(v0)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v1), @bitCast(v1)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v2), @bitCast(v2)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v3), @bitCast(v3)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v4), @bitCast(v4)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v5), @bitCast(v5)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v6), @bitCast(v6)));
			std.mem.doNotOptimizeAway(hash_fn(state, @bitCast(v7), @bitCast(v7)));
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
		try stderr.print("USO: <reps> <batch_size> <seed> <hash>\nHASH: custom_v2 | custom_v1 | rapidhash\n", .{});
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

	// Se inicializa el estado de la semilla en el main dependiendo del hash
	switch (hash_choice) {
		.custom_v2 => {
			const initialized_state = random.custom_hash_init_v2(seed);
			try testController(
				random.custom_hash_v2_no_init, 
				stdout, stderr, 
				reps, batch_size, initialized_state
			);
		},
		.custom_v1 => {
			// custom_v1 no requiere inicialización adicional, pasamos la semilla tal cual
			const initialized_state = random.custom_hash_init_v1(seed);
			try testController(
				random.custom_hash_v1_no_init, 
				stdout, stderr, 
				reps, batch_size, initialized_state
			);
		},
		.rapidhash => {
			const initialized_state = random.rapidhashnano_init_seed(seed);
			try testController(
				random.rapidhashnano_no_init, 
				stdout, stderr, 
				reps, batch_size, initialized_state
			);
		},
	}
}