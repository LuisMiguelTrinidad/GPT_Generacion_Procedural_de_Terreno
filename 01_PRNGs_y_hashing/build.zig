const std = @import("std");

fn addTool(
	b: *std.Build,
	target: std.Build.ResolvedTarget,
	optimize: std.builtin.OptimizeMode,
	name: []const u8,
	source_path: []const u8,
	imports: anytype,
) void {
	const exe = b.addExecutable(.{
		.name = name,
		.root_module = b.createModule(.{
			.root_source_file = b.path(source_path),
			.target = target,
			.optimize = optimize,
			.imports = imports,
		}),
	});
	if (optimize == .ReleaseFast) {
		exe.want_lto = true;
		exe.root_module.strip = true;
		exe.lto = .full;
	}

	b.installArtifact(exe);
}

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{
		.preferred_optimize_mode = .ReleaseFast,
	});

	const hashing_mod = b.createModule(.{
		.root_source_file = b.path("common/random.zig"),
		.target = target,
		.optimize = optimize,
	});

	const cycle_counter_mod = b.createModule(.{
		.root_source_file = b.path("common/cycle_counter.zig"),
		.target = target,
		.optimize = optimize,
	});

	const imports_hashing = [_]std.Build.Module.Import{
		.{ .name = "random", .module = hashing_mod },
	};
	const imports_throughput = [_]std.Build.Module.Import{
		.{ .name = "random", .module = hashing_mod },
		.{ .name = "cycle_counter", .module = cycle_counter_mod },
	};

	addTool(
		b, 
		target, 
		optimize, 
		"avalanche_64b", 
		"tests/avalanche_64b.zig", 
		&imports_hashing
	);
	addTool(
		b, target, 
		optimize, 
		"uniformity_64b", 
		"tests/uniformity_64b.zig", 
		&imports_hashing
	);
	addTool(
		b, 
		target, 
		optimize, 
		"pattern_64b", 
		"tests/pattern_64b.zig", 
		&imports_hashing
	);
	addTool(
		b, 
		target, 
		optimize, 
		"throughput_64b", 
		"tests/throughput_64b.zig", 
		&imports_throughput
	);
	addTool(
		b, 
		target, 
		optimize, 
		"collisions_64b", 
		"tests/collisions_64b.zig", 
		&imports_hashing
	);
}
