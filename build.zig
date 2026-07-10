const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("flag", .{
        .root_source_file = b.path("src/lib.zig"),
        .optimize = optimize,
        .target = target,
    });

    const exbin_step = b.step("bin", "create example bin");
    const exbin_exe = b.addExecutable(.{
        .name = "arg_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_main.zig"),
            .optimize = .Debug,
            .target = b.graph.host,
        }),
    });
    const exbin_install = b.addInstallArtifact(exbin_exe, .{});
    exbin_step.dependOn(&exbin_install.step);
}
