const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Public library module: signal
    const signal_module = b.addModule("signal", .{
        .root_source_file = b.path("src/signal.zig"),
    });

    // FFT example executable
    const fft_example = b.addExecutable(.{
        .name = "fft_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/fft_example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    fft_example.root_module.addImport("signal", signal_module);
    b.installArtifact(fft_example);

    // ECG demo executable
    const ecg_demo = b.addExecutable(.{
        .name = "ecg_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/ecg_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    ecg_demo.root_module.addImport("signal", signal_module);
    b.installArtifact(ecg_demo);

    // Run steps
    const run_fft = b.addRunArtifact(fft_example);
    const run_fft_step = b.step("run-fft", "Run FFT example");
    run_fft_step.dependOn(&run_fft.step);

    const run_ecg = b.addRunArtifact(ecg_demo);
    const run_ecg_step = b.step("run-ecg", "Run ECG demo");
    run_ecg_step.dependOn(&run_ecg.step);
}
