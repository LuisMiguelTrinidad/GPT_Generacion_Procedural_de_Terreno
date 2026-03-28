const std = @import("std");

const engine = @import("benchmark/engine.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Error: Uso incorrecto.\nFormato esperado: {s} <modo>\nModos disponibles: O0, O1, O2, O3, O4, O5, O6\n", .{args[0]});
        return;
    }

    const mode_arg = args[1];
    const mode_opt = engine.parse_mode(mode_arg);

    if (mode_opt) |runtime_mode| {
        switch (runtime_mode) {
            inline else => |comptime_m| {
                try engine.run_mode(comptime_m, allocator);
            },
        }
    } else {
        std.debug.print("Modo desconocido, no se ejecutará '{s}'\n", .{mode_arg});
    }
}