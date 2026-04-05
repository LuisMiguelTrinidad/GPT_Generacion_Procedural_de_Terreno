const std = @import("std");

const size: u64 = 64;

pub const grad_table: [2][size]i16 = generate_perlin_grad_table(size);
pub const grad_mask: u64 = grad_table[0].len - 1;

fn generate_perlin_grad_table(comptime table_size: u16) [2][table_size]i16 {
  var table_data: [2][table_size]i16 = undefined;

  const radius: f64 = std.math.sqrt2 / 4.0;
  const angle_step = (2.0 * std.math.pi) / @as(f64, @floatFromInt(table_size));

  for (0..table_size) |i| {
    const angle = @as(f64, @floatFromInt(i)) * angle_step;
    table_data[0][i] = @as(i16, @intFromFloat(radius * @sin(angle) * 32767.0));
    table_data[1][i] = @as(i16, @intFromFloat(radius * @cos(angle) * 32767.0));
  }

  return table_data;
}
