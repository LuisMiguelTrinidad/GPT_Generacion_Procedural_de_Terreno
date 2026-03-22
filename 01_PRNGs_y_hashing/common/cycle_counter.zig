const arch_caps = @import("arch_caps.zig");
const builtin = @import("builtin");

extern fn @"llvm.readcyclecounter"() u64;
extern fn @"llvm.x86.sse2.lfence"() void;
extern fn @"llvm.aarch64.isb"(i32) void;

const std = @import("std");	

pub inline fn read() u64 {
	comptime {
		if (!arch_caps.has_cycle_counter) {
			@compileError("No cycle counter available for this target architecture.");
		}
	}

	fence();
	const cycles = @"llvm.readcyclecounter"();
	fence();
	return cycles;
}

inline fn fence() void {
	switch (builtin.target.cpu.arch) {
		.x86_64 => @"llvm.x86.sse2.lfence"(),
		.aarch64 => @"llvm.aarch64.isb"(15),
		else => unreachable,
	}
}
