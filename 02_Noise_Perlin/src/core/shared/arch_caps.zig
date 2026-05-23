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

pub const has_avx2 = std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx2);
pub const has_avx512bw = std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx512bw);
pub const has_arm_neon = std.Target.aarch64.featureSetHas(builtin.target.cpu.features, .neon);

pub const has_cycle_counter = switch (arch) {
	.x86_64, .aarch64 => true,
	.other => false,
};

pub const VectorBackend = enum {
	scalar,
	neon,
	avx2,
	avx512bw,
};

pub fn simd_vector_bytes() comptime_int {
	if (comptime has_avx512bw) {
		return 64;
	} else if (comptime has_avx2) {
		return 32;
	} else if (comptime has_arm_neon) {
		return 16;
	} else {
		return 1;
	}
}

pub fn lanes_for(comptime T: type) comptime_int {
	return simd_vector_bytes() / @sizeOf(T);
}