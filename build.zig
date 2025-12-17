const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // FFT module (library)
    const fft_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/fft/fft.zig" },
    });

    // Executable example
    const exe = b.addExecutable(.{
        .name = "fft_example",
        .root_source_file = .{ .cwd_relative = "examples/fft_example.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Make FFT available as @import("fft")
    exe.root_module.addImport("fft", fft_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run FFT example");
    run_step.dependOn(&run_cmd.step);
}


