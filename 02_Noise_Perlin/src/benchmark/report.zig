const std = @import("std");
const config = @import("config.zig");
const arch_caps = @import("../core/shared/arch_caps.zig");

// --- Añadimos las intersecciones correctas ---
const TOP_LEFT = "┌";
const TOP_RIGHT = "┐";
const BOTTOM_LEFT = "└";
const BOTTOM_RIGHT = "┘";
const JUNCTION = "┼";
const TOP_JUNCTION = "┬";
const BOTTOM_JUNCTION = "┴";
const LEFT_JUNCTION = "├";
const RIGHT_JUNCTION = "┤";
const HORIZONTAL = "─";
const VERTICAL = "│";

const HEADER_WIDTH: usize = 11;
const VALUE_WIDTH: usize = 10;

pub const BenchmarkResult = struct {
  total_cycles: u64,
  best_chunk_cycles: u64,
};

fn report_cycle_scale() f64 {
  return if (arch_caps.arch == .aarch64) config.CPU_FREQ / config.CPU_BASE_FREQ else 1.0;
}

fn report_cycles(raw_cycles: u64) f64 {
  const raw_cycles_f64 = @as(f64, @floatFromInt(raw_cycles));
  return raw_cycles_f64 * report_cycle_scale();
}

fn print_horizontal(stdout: anytype, width: usize) !void {
  for (0..width) |_| {
    try stdout.print("{s}", .{HORIZONTAL});
  }
}

fn print_border(stdout: anytype, col_count: usize) !void {
  try stdout.print("{s}", .{TOP_LEFT});
  try print_horizontal(stdout, HEADER_WIDTH + 2);
  for (0..col_count) |_| {
    // Usamos TOP_JUNCTION en lugar de JUNCTION
    try stdout.print("{s}", .{TOP_JUNCTION}); 
    try print_horizontal(stdout, VALUE_WIDTH + 2);
  }
  try stdout.print("{s}\n", .{TOP_RIGHT});
}

fn print_bottom_border(stdout: anytype, col_count: usize) !void {
  try stdout.print("{s}", .{BOTTOM_LEFT});
  try print_horizontal(stdout, HEADER_WIDTH + 2);
  for (0..col_count) |_| {
    try stdout.print("{s}", .{BOTTOM_JUNCTION});
    try print_horizontal(stdout, VALUE_WIDTH + 2);
  }
  try stdout.print("{s}\n", .{BOTTOM_RIGHT});
}

fn print_separator(stdout: anytype, col_count: usize) !void {
  try stdout.print("{s}", .{LEFT_JUNCTION}); 
  try print_horizontal(stdout, HEADER_WIDTH + 2);
  for (0..col_count) |_| {
    try stdout.print("{s}", .{JUNCTION});
    try print_horizontal(stdout, VALUE_WIDTH + 2);
  }

  try stdout.print("{s}\n", .{RIGHT_JUNCTION}); 
}

pub fn average_cycles_per_point(total_points: u64, result: BenchmarkResult) f64 {
  if (total_points == 0) {
    return 0.0;
  }

  const total_points_f64 = @as(f64, @floatFromInt(total_points));
  const total_cycles_f64 = report_cycles(result.total_cycles);
  return total_cycles_f64 / total_points_f64;
}

pub fn max_cycles_per_point(total_chunks: u64, total_points: u64, result: BenchmarkResult) f64 {
  if (total_chunks == 0 or total_points == 0) {
    return 0.0;
  }

  const chunk_points = total_points / total_chunks;
  if (chunk_points == 0) {
    return 0.0;
  }

  const chunk_points_f64 = @as(f64, @floatFromInt(chunk_points));
  const best_chunk_cycles_f64 = report_cycles(result.best_chunk_cycles);
  return best_chunk_cycles_f64 / chunk_points_f64;
}

pub fn print_comparison_table(
  stdout: anytype,
  title: []const u8,
  chunk_sizes: []const u64,
  scales: []const u64,
  cycles_cells: []const ?f64,
) !void {
  if (chunk_sizes.len == 0 or scales.len == 0) {
    return error.InvalidComparisonTableShape;
  }

  const row_count = chunk_sizes.len;
  const col_count = scales.len;
  if (cycles_cells.len != row_count * col_count) {
    return error.InvalidComparisonTableShape;
  }

  try stdout.print("\n{s}\n", .{title});
  try print_border(stdout, col_count);

  try stdout.print("{s} {s:>11} {s}", .{ VERTICAL, "CHUNK/SCALE", VERTICAL });
  for (scales) |scale| {
    try stdout.print(" {d:>10} {s}", .{ scale, VERTICAL });
  }
  try stdout.print("\n", .{});

  try print_separator(stdout, col_count);

  for (chunk_sizes, 0..) |chunk_size, row_idx| {
    try stdout.print("{s} {d:>11} {s}", .{ VERTICAL, chunk_size, VERTICAL });
    for (scales, 0..) |_, col_idx| {
      const flat_idx = row_idx * col_count + col_idx;
      if (cycles_cells[flat_idx]) |cycles| {
        try stdout.print(" {d:>10.4} {s}", .{ cycles, VERTICAL });
      } else {
        try stdout.print(" {s:>10} {s}", .{ "N/A", VERTICAL });
      }
    }
    try stdout.print("\n", .{});
  }

  try print_bottom_border(stdout, col_count);
}