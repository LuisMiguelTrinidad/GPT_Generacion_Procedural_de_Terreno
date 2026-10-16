pub const SEED: u64 = 0xDEADBEEFCAFEBABE;
pub const CHUNK_SIZE: u64 = 256;
pub const SCALE: u64 = 256;

pub const CPU_BASE_FREQ: f64 = 3_800_000_000.0; // 3.8 GHz - Frecuencia base del Ryzen 7 9700X
pub const CPU_FREQ: f64 = 5_500_000_000.0;       // 5.5 GHz - Frecuencia turbo máxima oficial

pub const WARMUP_CHUNK_COUNT: u64 = 1_000;
pub const BENCHMARK_CHUNK_COUNT: u64 = 10_000;
pub const SAVE_CHUNKS_PER_SIDE: u64 = 2;

pub const BENCHMARK_CHUNK_SIZES = [_]u64{32, 64, 128, 256, 512, 1024};
pub const BENCHMARK_SCALES = [_]u64{32, 64, 128, 256, 512, 1024};
