const std = @import("std");

const perlin_o0 = @import("00_ref.zig");
const perlin_o1 = @import("01_custom_hash.zig");
const perlin_o2 = @import("02_caching.zig");
const perlin_o3 = @import("03_tiling.zig");
const perlin_o4 = @import("04_simd.zig");
const perlin_o5 = @import("05_fpa.zig");
const perlin_o6 = @import("06_licm.zig");
pub const OptMode = enum { O0, O1, O2, O3, O4, O5, O6 };

pub const SampleKind = enum {
    f32,
    i16,
};

pub const GradLayout = enum {
    aos,
    soa,
};

pub const ModeSpec = struct {
    module: type,
    sample_kind: SampleKind,
    grad_layout: GradLayout,
    required_alignment: u29,
};

fn validate_perlin_module(comptime mod: type) void {
    comptime {
        if (!@hasDecl(mod, "perlin_init_config")) {
            @compileError("Perlin module is missing perlin_init_config");
        }
        if (!@hasDecl(mod, "perlin_generate_chunk2d")) {
            @compileError("Perlin module is missing perlin_generate_chunk2d");
        }
        if (!@hasDecl(mod, "RequiredAlignment")) {
            @compileError(std.fmt.comptimePrint(
                "Perlin module {s} must declare RequiredAlignment",
                .{@typeName(mod)},
            ));
        }

        const alignment = mod.RequiredAlignment;
        if (alignment == 0 or (alignment & (alignment - 1)) != 0) {
            @compileError(std.fmt.comptimePrint(
                "Perlin module {s} has invalid RequiredAlignment: expected non-zero power of two",
                .{@typeName(mod)},
            ));
        }
    }
}

fn build_mode_spec(comptime mod: type, sample_kind: SampleKind, grad_layout: GradLayout) ModeSpec {
    validate_perlin_module(mod);
    return .{
        .module = mod,
        .sample_kind = sample_kind,
        .grad_layout = grad_layout,
        .required_alignment = mod.RequiredAlignment,
    };
}

pub fn get_mode_spec(comptime mode: OptMode) ModeSpec {
    return switch (mode) {
        .O0 => build_mode_spec(perlin_o0, .f32, .aos),
        .O1 => build_mode_spec(perlin_o1, .f32, .aos),
        .O2 => build_mode_spec(perlin_o2, .f32, .aos),
        .O3 => build_mode_spec(perlin_o3, .f32, .aos),
        .O4 => build_mode_spec(perlin_o4, .f32, .soa),
        .O5 => build_mode_spec(perlin_o5, .i16, .soa),
        .O6 => build_mode_spec(perlin_o6, .i16, .soa),
    };
}

pub fn parse_mode(mode_arg: []const u8) ?OptMode {
    return std.meta.stringToEnum(OptMode, mode_arg);
}
