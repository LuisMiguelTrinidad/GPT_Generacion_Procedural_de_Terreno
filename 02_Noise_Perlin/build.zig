const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{
    .preferred_optimize_mode = .fast,
  });

  const zigimg_dependency = b.dependency("zigimg", .{
    .target = target,
    .optimize = optimize,
  });

    // Módulo interno, creado de forma anónima y no expuesto globalmente
  const package_mod = b.createModule(.{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .optimize = optimize,
    .single_threaded = true,
  });

  const exe = b.addExecutable(.{
    .name = "perlin",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
      .imports = &.{
        .{ .name = "_02_Perlin_Noise", .module = package_mod },
        .{ .name = "zigimg", .module = zigimg_dependency.module("zigimg") },
      },
    }),
  });

  exe.use_llvm = true;
  exe.use_lld = true;

  b.installArtifact(exe);

  const run_cmd = b.addRunArtifact(exe);
  run_cmd.step.dependOn(b.getInstallStep());
  run_cmd.addPassthruArgs();

  const run_step = b.step("run", "Run the app");
  run_step.dependOn(&run_cmd.step);
}
