const std = @import("std");
const builtin = @import("builtin");

pub const has_cycle_counter = switch (builtin.target.cpu.arch) {
	.x86_64, .aarch64 => true,
	else => false,
};