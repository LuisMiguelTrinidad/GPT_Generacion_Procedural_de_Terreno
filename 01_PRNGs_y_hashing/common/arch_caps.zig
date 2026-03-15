const std = @import("std");
const builtin = @import("builtin");

pub const Arch = enum {
    x86_64,
    aarch64,
    other,
};

pub const arch: Arch = switch (builtin.target.cpu.arch) {
    .x86_64 => .x86_64,
    .aarch64 => .aarch64,
    else => .other,
};

pub const is_x86_64 = arch == .x86_64;
pub const is_aarch64 = arch == .aarch64;

pub const has_cycle_counter = switch (arch) {
    .x86_64, .aarch64 => true,
    .other => false,
};

pub const has_avx2 = is_x86_64 and std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx2);
pub const has_avx512bw = is_x86_64 and std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx512bw);
