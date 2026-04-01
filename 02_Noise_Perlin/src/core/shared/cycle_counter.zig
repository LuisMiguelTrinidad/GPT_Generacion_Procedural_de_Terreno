const arch_caps = @import("arch_caps.zig");

extern fn @"llvm.readcyclecounter"() u64;
extern fn @"llvm.x86.sse2.lfence"() void;
extern fn @"llvm.aarch64.isb"(i32) void;

pub inline fn read() u64 {
	comptime {
		if (!arch_caps.has_cycle_counter) {
			@compileError("No cycle counter available for this target architecture.");
		}
	}

	pre_read_fence();
	const cycles = @"llvm.readcyclecounter"();
	post_read_fence();

	return cycles;
}

inline fn pre_read_fence() void {
	switch (arch_caps.arch) {
		.x86_64 => @"llvm.x86.sse2.lfence"(),
		.aarch64 => @"llvm.aarch64.isb"(15),
		.other => unreachable,
	}
}

inline fn post_read_fence() void {
	pre_read_fence();
}