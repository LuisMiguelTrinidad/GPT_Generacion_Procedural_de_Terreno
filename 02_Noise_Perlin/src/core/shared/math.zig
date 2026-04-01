pub inline fn dot_prod_2d(x0: f32, x1: f32, g0: f32, g1: f32) f32 {
  return x0 * g0 + x1 * g1;
}

pub inline fn lerp(a: f32, b: f32, t: f32) f32 {
  return a + t * (b - a);
}

pub inline fn smooth_step(t: f32) f32 {
  return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

pub inline fn fast_fract(v: f32) f32 {
  return v - @floor(v);
}
