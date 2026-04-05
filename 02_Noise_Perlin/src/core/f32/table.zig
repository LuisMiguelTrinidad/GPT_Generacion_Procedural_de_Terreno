const std = @import("std");

const size: u64 = 64;

pub const grad: [size][2]f32 = generate_perlin_gradients(size);
pub const grad_table: [2][size]f32 = generate_perlin_grad_table(size);
pub const grad_mask: u64 = grad.len - 1;

fn generate_perlin_gradients(comptime table_size: u16) [table_size][2]f32 {
  var table_data: [table_size][2]f32 = undefined;

  const radius: f32 = std.math.sqrt2;
  const angle_step = (2.0 * std.math.pi) / @as(f32, @floatFromInt(table_size));

  for (0..table_size) |i| {
    const angle = @as(f32, @floatFromInt(i)) * angle_step;
    table_data[i][0] = radius * @sin(angle);
    table_data[i][1] = radius * @cos(angle);
  }

  return table_data;
}

fn generate_perlin_grad_table(comptime table_size: u16) [2][table_size]f32 {
  var table_data: [2][table_size]f32 = undefined;

  const radius: f32 = std.math.sqrt2;
  const angle_step = (2.0 * std.math.pi) / @as(f32, @floatFromInt(table_size));

  for (0..table_size) |i| {
    const angle = @as(f32, @floatFromInt(i)) * angle_step;
    table_data[0][i] = radius * @sin(angle);
    table_data[1][i] = radius * @cos(angle);
  }

  return table_data;
}
