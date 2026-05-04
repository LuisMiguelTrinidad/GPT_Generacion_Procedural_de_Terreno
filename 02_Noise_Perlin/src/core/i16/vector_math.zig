const arch_caps = @import("../shared/arch_caps.zig");

extern fn @"llvm.x86.avx2.pmul.hr.sw"(a: @Vector(16, i16), b: @Vector(16, i16)) @Vector(16, i16);
extern fn @"llvm.x86.avx512.pmulhrsw.512"(a: @Vector(32, i16), b: @Vector(32, i16)) @Vector(32, i16);
extern fn @"llvm.aarch64.neon.sqrdmulh.v8i16"(a: @Vector(8, i16), b: @Vector(8, i16)) @Vector(8, i16);
extern fn @"llvm.aarch64.neon.sqrdmlah.v8i16"(acc: @Vector(8, i16), a: @Vector(8, i16), b: @Vector(8, i16)) @Vector(8, i16);

pub const simd_vector_bytes = arch_caps.simd_vector_bytes;
pub const lanes_for = arch_caps.lanes_for;

/// Fixed-point Q0.15 multiply with high-rounding semantics.
pub inline fn mul_q15_round(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
	const Vec = comptime @TypeOf(a);
	const info = comptime @typeInfo(Vec).vector;

	// AVX 512 -> AVX2 -> Neon -> Scalar fallback.
	const avx512_case = comptime arch_caps.has_avx512bw and info.len == 32;
	const avx2_case = comptime arch_caps.has_avx2 and info.len == 16;
	const neon_case = comptime arch_caps.has_arm_neon and info.len == 8;

	if (avx512_case) {
      return @"llvm.x86.avx512.pmulhrsw.512"(a, b);
  } else if (avx2_case) {
      return @"llvm.x86.avx2.pmul.hr.sw"(a, b);
  } else if (neon_case) {
      return @"llvm.aarch64.neon.sqrdmulh.v8i16"(a, b);
  }
    
	const Vec32 = @Vector(info.len, i32);
	const prod: Vec32 = @as(Vec32, a) * @as(Vec32, b);
	const rounded: Vec32 = (prod + @as(Vec32, @splat(@as(i32, 0x4000)))) >>  @splat(15);
	return @as(Vec, @truncate(rounded));
}

/// Fixed-point Q0.15 multiply-add with high-rounding semantics.
pub inline fn mul_add_q15_round(acc: anytype, a: @TypeOf(acc), b: @TypeOf(acc)) @TypeOf(acc) {
	const Vec = comptime @TypeOf(acc);
	const info = comptime @typeInfo(Vec).vector;

	comptime {
		if (info.child != i16) {
			@compileError("mul_add_q15_round expects vector of i16");
		}
	}

	const neon_case = comptime arch_caps.has_arm_neon and info.len == 8;

	if (neon_case) {
		return @"llvm.aarch64.neon.sqrdmlah.v8i16"(acc, a, b);
	}

	return mul_q15_round(a, b) + acc;
}
