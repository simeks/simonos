const std = @import("std");

pub fn build(b: *std.Build) void {

    // TODO:
    // Need to disable some features until we actually enable them in the OS
    var disabled_features: std.Target.Cpu.Feature.Set = .empty;
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse3));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse4_1));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse4_2));

    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .abi = .none,
            .cpu_features_sub = disabled_features,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = b.path("src/kernel_main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    });
    kernel.addAssemblyFile(b.path("src/_start.s"));
    kernel.setLinkerScript(b.path("src/linker.ld"));
    b.installArtifact(kernel);
}
