pub const PerlinConfig = struct {
  seed: u64,
  chunk_size: u64,
  scale: u64,
  octaves: u64,
  persistence: f32,
  lacunarity: f32,
  cached_values: []f32,
  cached_smoothed_values: []f32,
};