const std = @import("std");

/// First-order low-pass IIR filter.
///
/// - Smooths high-frequency components
/// - Simple and computationally cheap
///
/// The returned buffer is heap-allocated and must be freed by the caller.
pub fn lowPass(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    cutoff: f64,
) ![]f64 {
    var output = try allocator.alloc(f64, input.len);

    const alpha =
        (2.0 * std.math.pi * cutoff) /
        ((2.0 * std.math.pi * cutoff) + fs);

    output[0] = input[0];

    for (1..input.len) |i| {
        output[i] = output[i - 1] + alpha * (input[i] - output[i - 1]);
    }

    return output;
}

/// First-order high-pass IIR filter.
///
/// - Removes low-frequency drift
/// - Useful for baseline correction
///
/// The returned buffer is heap-allocated and must be freed by the caller.
pub fn highPass(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    cutoff: f64,
) ![]f64 {
    var output = try allocator.alloc(f64, input.len);

    const alpha = fs / (fs + 2.0 * std.math.pi * cutoff);

    output[0] = input[0];

    for (1..input.len) |i| {
        output[i] = alpha * (output[i - 1] + input[i] - input[i - 1]);
    }

    return output;
}

/// First-order bandpass filter implemented as:
/// high-pass → low-pass.
///
/// This is intended for:
/// - learning
/// - lightweight preprocessing
///
/// Not zero-phase; use Butterworth + filtfilt for ECG-grade filtering.
pub fn firstOrderBandPass(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    low: f64,
    high: f64,
) ![]f64 {
    const hp = try highPass(allocator, input, fs, low);
    defer allocator.free(hp);

    return lowPass(allocator, hp, fs, high);
}

test "lowPass smooths step signal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const fs = 100.0;
    const cutoff = 5.0;

    var input = [_]f64{ 0, 0, 0, 1, 1, 1, 1, 1 };

    const output = try lowPass(
        allocator,
        input[0..],
        fs,
        cutoff,
    );
    defer allocator.free(output);

    // After the step, values should increase monotonically
    for (4..output.len - 1) |i| {
        try std.testing.expect(output[i + 1] >= output[i]);
    }

    // Output should not overshoot
    for (output) |v| {
        try std.testing.expect(v <= 1.0);
    }
}

test "highPass attenuates DC component" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const fs = 100.0;
    const cutoff = 5.0;

    var input = [_]f64{ 1, 1, 1, 1, 1, 1, 1, 1 };

    const output = try highPass(
        allocator,
        input[0..],
        fs,
        cutoff,
    );
    defer allocator.free(output);

    // DC should be attenuated (not eliminated)
    for (4..output.len) |i| {
        try std.testing.expect(@abs(output[i]) < 0.5);
    }
}
