const std = @import("std");
const builtin = @import("builtin");

pub const has_cycle_counter = switch (builtin.target.cpu.arch) {
    .x86_64, .aarch64 => true,
    else => false, // Cambiado 'other' por 'else' para mayor robustez ante nuevos targets
};

// Evitamos el error de tipo comprobando la arquitectura antes de evaluar la feature
pub const has_avx2 = (builtin.target.cpu.arch == .x86_64) and 
    std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx2);

pub const has_avx512bw = (builtin.target.cpu.arch == .x86_64) and 
    std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx512bw);