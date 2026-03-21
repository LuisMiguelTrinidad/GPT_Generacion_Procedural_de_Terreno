const std = @import("std");

const cycle_counter = @import("cycle_counter");
const random = @import("random");

const HashChoice = enum {
    custom_v2,
    custom_v1,
    rapidhash,
};

// Hemos añadido comptime unroll_factor
fn testController(
    comptime hash_fn: anytype,
    comptime unroll_factor: u64,
    stdout: anytype,
    stderr: anytype,
    reps: u64,
    batch_size: u64,
    base_state: anytype, // Recibimos el estado inicial
    data: []const i64,
) !void {
    _ = stderr;

    for (0..reps) |r| {
        const t0 = cycle_counter.read();
        var i: u64 = 0;
        
        var lane_states: [unroll_factor]u64 = undefined;
        inline for (0..unroll_factor) |step| {
            lane_states[step] = base_state + step;
        }

        while (i < batch_size) : (i += unroll_factor) {
            const p = i * 2;
            var results: [unroll_factor]u64 = undefined;

            inline for (0..unroll_factor) |step| {
                const idx = p + (step * 2);
                lane_states[step] = hash_fn(lane_states[step], data[idx], data[idx + 1]);
                results[step] = lane_states[step];
            }

            inline for (0..unroll_factor) |step| {
                std.mem.doNotOptimizeAway(results[step]);
            }

            asm volatile ("" ::: .{ .memory = true });
        }

        const elapsed_cycles: f64 = @floatFromInt(cycle_counter.read() - t0);
        const cycles_per_hash = elapsed_cycles / @as(f64, @floatFromInt(batch_size));

        try stdout.print("REP {d: >4} : {d:.4} cycles/hash\n", .{ r, cycles_per_hash });
    }
}

// Función auxiliar para despachar el unroll en tiempo de ejecución hacia una función comptime
fn dispatchUnroll(
    comptime hash_fn: anytype,
    unroll_param: u64,
    stdout: anytype,
    stderr: anytype,
    reps: u64,
    batch_size: u64,
    state: anytype,
    data: []const i64,
) !void {
    switch (unroll_param) {
        1 => try testController(hash_fn, 1, stdout, stderr, reps, batch_size, state, data),
        2 => try testController(hash_fn, 2, stdout, stderr, reps, batch_size, state, data),
        3 => try testController(hash_fn, 3, stdout, stderr, reps, batch_size, state, data),
        4 => try testController(hash_fn, 4, stdout, stderr, reps, batch_size, state, data),
        8 => try testController(hash_fn, 8, stdout, stderr, reps, batch_size, state, data),
        16 => try testController(hash_fn, 16, stdout, stderr, reps, batch_size, state, data),
        32 => try testController(hash_fn, 32, stdout, stderr, reps, batch_size, state, data),
        else => {
            try stderr.print("ERROR: Factor de unroll no soportado (usa 1, 2, 3, 4, 8, 16 o 32).\n", .{});
            return error.InvalidUnrollFactor;
        },
    }
}

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;

    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_alloc.deinit();
    const gpa = gpa_alloc.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 6) {
        try stderr.print("USO: <reps> <batch_size> <seed> <hash> <unroll>\nHASH: custom_v2 | custom_v1 | rapidhash\nUNROLL: 2, 4, 6, 16, 32\n", .{});
        return error.InvalidArguments;
    }

    const reps: u64 = try std.fmt.parseInt(u64, args[1], 10);
    const batch_size: u64 = try std.fmt.parseInt(u64, args[2], 10);
    const seed: u64 = try std.fmt.parseInt(u64, args[3], 10);
    const hash_choice = std.meta.stringToEnum(HashChoice, args[4]) orelse {
        try stderr.print("ERROR: Hash desconocido. Opciones: custom_v2 | custom_v1 | rapidhash\n", .{});
        return error.InvalidHashChoice;
    };
    const unroll_param: u64 = try std.fmt.parseInt(u64, args[5], 10);

    if (batch_size % unroll_param != 0) {
        try stderr.print("ERROR: Para evitar desbordamientos, batch_size DEBE ser multiplo del factor de unroll ({d}).\n", .{unroll_param});
        return error.InvalidBatchSize;
    }

    const data_array = try gpa.alloc(i64, batch_size * 2);
    defer gpa.free(data_array);

    var prng: u64 = 237489;
    for (data_array) |*item| {
        prng = random.splitmix64(prng);
        item.* = @as(i64, @bitCast(random.splitmix64(prng)));
    }

    switch (hash_choice) {
        .custom_v2 => {
            const initialized_state = random.custom_hash_init_v2(seed);
            try dispatchUnroll(random.custom_hash_v2_no_init, unroll_param, stdout, stderr, reps, batch_size, initialized_state, data_array);
        },
        .custom_v1 => {
            const initialized_state = random.custom_hash_init_v1(seed);
            try dispatchUnroll(random.custom_hash_v1_no_init, unroll_param, stdout, stderr, reps, batch_size, initialized_state, data_array);
        },
        .rapidhash => {
            const initialized_state = random.rapidhashnano_init_seed(seed);
            try dispatchUnroll(random.rapidhashnano_no_init, unroll_param, stdout, stderr, reps, batch_size, initialized_state, data_array);
        },
    }
}
