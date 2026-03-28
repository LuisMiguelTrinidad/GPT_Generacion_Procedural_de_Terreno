const std = @import("std");

const size: u64 = 64;

pub const grad: [size][2]f32 = generate_perlin_gradients(size);
pub const grad_soa: [2][size]f32 = generate_perlin_gradients_soa(size);
pub const grad_mask: u64 = grad.len - 1;

fn generate_perlin_gradients(comptime table_size: u16) [table_size][2]f32 {
  var grad_table: [table_size][2]f32 = undefined;

  const radius: f32 = std.math.sqrt2;
  const angle_step = (2.0 * std.math.pi) / @as(f32, @floatFromInt(table_size));

  for (0..table_size) |i| {
    const angle = @as(f32, @floatFromInt(i)) * angle_step;
    grad_table[i][0] = radius * @sin(angle);
    grad_table[i][1] = radius * @cos(angle);
  }

  return grad_table;
}

fn generate_perlin_gradients_soa(comptime table_size: u16) [2][table_size]f32 {
  var grad_table: [2][table_size]f32 = undefined;

  const radius: f32 = std.math.sqrt2;
  const angle_step = (2.0 * std.math.pi) / @as(f32, @floatFromInt(table_size));

  for (0..table_size) |i| {
    const angle = @as(f32, @floatFromInt(i)) * angle_step;
    grad_table[0][i] = radius * @sin(angle);
    grad_table[1][i] = radius * @cos(angle);
  }

  return grad_table;
}
