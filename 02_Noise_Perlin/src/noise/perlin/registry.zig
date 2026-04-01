const std = @import("std");
const mode_meta = @import("mode_meta.zig");

const perlin_O0 = @import("00_ref.zig");
const perlin_O1 = @import("01_custom_hash.zig");
const perlin_O2 = @import("02_caching.zig");
const perlin_O3 = @import("03_tiling.zig");
const perlin_O4 = @import("04_simd.zig");
const perlin_O5 = @import("05_fpa.zig");
const perlin_O6 = @import("06_licm.zig");

const mode_modules = .{
	.O0 = perlin_O0,
	.O1 = perlin_O1,
	.O2 = perlin_O2,
	.O3 = perlin_O3,
	.O4 = perlin_O4,
	.O5 = perlin_O5,
	.O6 = perlin_O6,
};

pub const OptMode = std.meta.FieldEnum(@TypeOf(mode_modules));
pub const SampleKind = mode_meta.SampleKind;
pub const GradLayout = mode_meta.GradLayout;

pub const ModeSpec = struct {
	module: type,
	sample_kind: SampleKind,
	grad_layout: GradLayout,
	required_alignment: u29,
};

fn mode_module(comptime mode: OptMode) type {
	return @field(mode_modules, @tagName(mode));
}

pub fn get_mode_spec(comptime mode: OptMode) ModeSpec {
	const mod = mode_module(mode);
	return .{
		.module = mod,
		.sample_kind = mod.sample_kind,
		.grad_layout = mod.grad_layout,
		.required_alignment = mod.RequiredAlignment,
	};
}

pub fn parse_mode(mode_arg: []const u8) ?OptMode {
	return std.meta.stringToEnum(OptMode, mode_arg);
}
