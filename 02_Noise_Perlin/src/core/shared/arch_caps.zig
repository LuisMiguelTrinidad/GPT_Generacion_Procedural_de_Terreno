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

pub const has_avx2 = is_x86_64 and
	std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx2);
pub const has_avx512bw = is_x86_64 and
	std.Target.x86.featureSetHas(builtin.target.cpu.features, .avx512bw);

pub const has_arm_neon = switch (builtin.target.cpu.arch) {
	.aarch64 => std.Target.aarch64.featureSetHas(builtin.target.cpu.features, .neon),
	else => false,
};
pub const has_arm_simd = has_arm_neon;

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

pub const vector_backend: VectorBackend = blk: {
	if (has_avx512bw) break :blk .avx512bw;
	if (has_avx2) break :blk .avx2;
	if (has_arm_simd) break :blk .neon;
	break :blk .scalar;
};

pub fn simd_vector_bytes() comptime_int {
	return switch (vector_backend) {
		.avx512bw => 64,
		.avx2 => 32,
		.neon => 16,
		.scalar => 1,
	};
}

pub fn lanes_for(comptime T: type) comptime_int {
	return simd_vector_bytes() / @sizeOf(T);
}