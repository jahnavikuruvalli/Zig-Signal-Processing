const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Public module: zig-signal
    const signal_module = b.addModule("zig-signal", .{
        .root_source_file = b.path("src/signal.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Example executable
    const exe = b.addExecutable(.{
        .name = "fft_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/fft_example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Make zig-signal available to the example
    exe.root_module.addImport("zig-signal", signal_module);

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run fft_example");
    run_step.dependOn(&run_cmd.step);
}
