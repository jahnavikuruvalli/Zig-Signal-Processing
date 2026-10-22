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
            .root_source_file = b.path("src/examples/fft_example.zig"),
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
            .root_source_file = b.path("src/examples/ecg_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    ecg_demo.root_module.addImport("signal", signal_module);
    b.installArtifact(ecg_demo);

    // PSD demo executable
    const psd_demo = b.addExecutable(.{
        .name = "psd_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/examples/psd_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    psd_demo.root_module.addImport("signal", signal_module);
    b.installArtifact(psd_demo);

    // Run steps
    const run_fft = b.addRunArtifact(fft_example);
    const run_fft_step = b.step("run-fft", "Run FFT example");
    run_fft_step.dependOn(&run_fft.step);

    const run_ecg = b.addRunArtifact(ecg_demo);
    const run_ecg_step = b.step("run-ecg", "Run ECG demo");
    run_ecg_step.dependOn(&run_ecg.step);

    const run_psd = b.addRunArtifact(psd_demo);
    const run_psd_step = b.step("run-psd", "Run PSD demo (writes psd_signal.csv, psd_output.csv)");
    run_psd_step.dependOn(&run_psd.step);

    // Unit tests: `zig build test`
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_tests.step);
}
