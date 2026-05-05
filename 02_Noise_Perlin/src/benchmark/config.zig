pub const SEED: u64 = 0xDEADBEEFCAFEBABE;
pub const CHUNK_SIZE: u64 = 256;
pub const SCALE: u64 = 256;

pub const CPU_BASE_FREQ: f64 = 19_200_000.0; // aarch64: frecuencia del contador de referencia (CNTVCT). x86_64: frecuencia base estimada.
pub const CPU_FREQ: f64 = 2_200_000_000.0; // x86_64: frecuencia turbo estimada. aarch64: usada para estimar ciclos reales a frecuencia máxima.


pub const WARMUP_CHUNK_COUNT: u64 = 1_000;
pub const BENCHMARK_CHUNK_COUNT: u64 = 10_000;
pub const SAVE_CHUNKS_PER_SIDE: u64 = 2;

pub const BENCHMARK_CHUNK_SIZES = [_]u64{256};
pub const BENCHMARK_SCALES = [_]u64{16, 32, 64, 128, 256, 512, 1024};