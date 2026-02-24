//! Test runner for zig-signal-processing
//!
//! This file forces Zig to instantiate the entire library,
//! ensuring all inline tests in all modules are executed.

const std = @import("std");
const signal = @import("signal.zig");

test "run all library tests" {
    std.testing.refAllDecls(signal);
}

test {
    _ = @import("tests/biquad-test.zig");
    _ = @import("tests/bandpass-test.zig");
    _ = @import("tests/derivative-test.zig");
    _ = @import("tests/square-test.zig");
    _ = @import("tests/moving-average-test.zig");
    _ = @import("tests/peak-detector-test.zig");
    _ = @import("tests/pipeline-test.zig");
    _ = @import("tests/stream-demo-test.zig");
}
