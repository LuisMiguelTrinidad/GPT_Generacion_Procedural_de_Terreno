pub const SEED: u64 = 0xDEADBEEFCAFEBABE;
pub const CHUNK_SIZE: u64 = 256;
pub const SCALE: u64 = 256;
pub const OCTAVES: u64 = 1;
pub const PERSISTENCE: f32 = 2.0;
pub const LACUNARITY: f32 = 2.0;

pub const CPU_BASE_FREQ: f64 = 3_400_000_000.0; // Cambiar según la CPU
pub const CPU_FREQ: f64 = 4_600_000_000.0;      // Cambiar según la CPU

pub const WARMUP_CHUNK_COUNT: u64 = 10_000;
pub const BENCHMARK_CHUNK_COUNT: u64 = 100_000;
pub const SAVE_CHUNKS_PER_SIDE: u64 = 0;