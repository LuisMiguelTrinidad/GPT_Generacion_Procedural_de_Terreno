const arch_caps = @import("arch_caps.zig");
const builtin = @import("builtin");

extern fn @"llvm.readcyclecounter"() u64;
extern fn @"llvm.x86.sse2.lfence"() void;
extern fn @"llvm.aarch64.isb"(i32) void;

const std = @import("std");	

const CPU_FREQ_HZ: u128 = 2_200_000_000; 

pub inline fn read() u64 {
    comptime {
        if (!arch_caps.has_cycle_counter) {
            @compileError("No cycle counter available for this target architecture.");
        }
    }

    fence();
    
    var cycles: u64 = 0;

    if (builtin.target.cpu.arch == .aarch64) {
        // 1. Leemos los ticks universales (siempre permitido en EL0)
        var ticks: u64 = undefined;
        asm volatile ("mrs %[res], cntvct_el0" : [res] "=r" (ticks));
        
        // 2. Leemos la frecuencia de esos ticks (los 19.2 MHz)
        var timer_freq: u64 = undefined;
        asm volatile ("mrs %[res], cntfrq_el0" : [res] "=r" (timer_freq));

        // 3. Equivalencia Matemática: Ciclos = (Ticks * FrecuenciaCPU) / FrecuenciaTimer
        // Usamos u128 para evitar que la multiplicación desborde el límite del u64
        cycles = @as(u64, @intCast((@as(u128, ticks) * CPU_FREQ_HZ) / @as(u128, timer_freq)));
    } else {
        // Para x86_64 y otros que sí soportan el intrínseco directo sin bloqueos
        cycles = @"llvm.readcyclecounter"();
    }

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
