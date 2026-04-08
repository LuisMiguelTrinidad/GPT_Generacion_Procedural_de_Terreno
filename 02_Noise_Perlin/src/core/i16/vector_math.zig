const arch_caps = @import("../shared/arch_caps.zig");

extern fn @"llvm.x86.avx2.pmul.hr.sw"(a: @Vector(16, i16), b: @Vector(16, i16)) @Vector(16, i16);
extern fn @"llvm.x86.avx512.pmulhrsw.512"(a: @Vector(32, i16), b: @Vector(32, i16)) @Vector(32, i16);
extern fn @"llvm.aarch64.neon.sqrdmulh.v8i16"(a: @Vector(8, i16), b: @Vector(8, i16)) @Vector(8, i16);

pub const simd_vector_bytes = arch_caps.simd_vector_bytes;
pub const lanes_for = arch_caps.lanes_for;

/// Fixed-point Q0.15 multiply with high-rounding semantics.
pub inline fn mul_q15_round(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
	const Vec = @TypeOf(a);
	const info = @typeInfo(Vec).vector;

	comptime {
		if (info.child != i16) {
			@compileError("mul_q15_round expects vector of i16");
		}
	}

	if (comptime arch_caps.has_avx512bw and info.len == 32) {
		return @"llvm.x86.avx512.pmulhrsw.512"(a, b);
	}

	if (comptime arch_caps.has_avx2 and info.len == 16) {
		return @"llvm.x86.avx2.pmul.hr.sw"(a, b);
	}

	if (comptime arch_caps.has_arm_simd and info.len == 8 and arch_caps.is_aarch64) {
		return @"llvm.aarch64.neon.sqrdmulh.v8i16"(a, b);
	}
    
	const Vec32 = @Vector(info.len, i32);
	const prod: Vec32 = @as(Vec32, a) * @as(Vec32, b);
	const rounded: Vec32 = (prod + @as(Vec32, @splat(@as(i32, 0x4000)))) >>  @splat(15);
	return @as(Vec, @truncate(rounded));
}
