//! Test runner for zig-signal-processing
//!
//! This file forces Zig to instantiate the entire library,
//! ensuring all inline tests in all modules are executed.

const std = @import("std");
const signal = @import("signal.zig");

test "run all library tests" {
    std.testing.refAllDecls(signal);
}
