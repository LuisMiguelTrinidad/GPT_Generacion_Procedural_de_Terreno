const arch_caps = @import("../shared/arch_caps.zig");

pub const has_avx2 = arch_caps.has_avx2;
pub const has_avx512bw = arch_caps.has_avx512bw;
pub const has_arm_simd = arch_caps.has_arm_simd;

pub const simd_vector_bytes = arch_caps.simd_vector_bytes;
pub const lanes_for = arch_caps.lanes_for;
