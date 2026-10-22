const std = @import("std");
const butter = @import("butterworth.zig");

/// Internal second-order IIR filter implementation.
fn iirFilter(
    allocator: std.mem.Allocator,
    input: []const f64,
    b: [3]f64,
    a: [3]f64,
) ![]f64 {
    const y = try allocator.alloc(f64, input.len);
    @memset(y, 0.0);

    for (0..input.len) |n| {
        y[n] += b[0] * input[n];

        if (n >= 1) {
            y[n] += b[1] * input[n - 1];
            y[n] -= a[1] * y[n - 1];
        }
        if (n >= 2) {
            y[n] += b[2] * input[n - 2];
            y[n] -= a[2] * y[n - 2];
        }
    }

    return y;
}

/// Reverse a signal (used internally for zero-phase filtering).
fn reverse(
    allocator: std.mem.Allocator,
    input: []const f64,
) ![]f64 {
    const out = try allocator.alloc(f64, input.len);
    const n = input.len;

    for (0..n) |i| {
        out[i] = input[n - 1 - i];
    }

    return out;
}

/// Zero-phase Butterworth bandpass filtering using forward–backward IIR filtering.
///
/// This is equivalent in spirit to `scipy.signal.filtfilt`.
///
/// - Applies Butterworth bandpass coefficients
/// - Filters forward, reverses, filters again, reverses back
/// - Eliminates phase distortion
///
/// Notes:
/// - Returned buffer is heap-allocated
/// - Caller is responsible for freeing it
/// - Requires 0 < low < high < fs/2, otherwise `error.InvalidFrequency`
/// - No edge padding: expect start/end transients of a few filter time
///   constants (unlike SciPy, which pads by default)
pub fn filtfilt(
    allocator: std.mem.Allocator,
    input: []const f64,
    fs: f64,
    low: f64,
    high: f64,
) ![]f64 {
    if (!(low > 0.0 and low < high and high < fs / 2.0))
        return error.InvalidFrequency;

    const coeffs = butter.butterworthBandpass(fs, low, high);

    const forward = try iirFilter(
        allocator,
        input,
        coeffs.b,
        coeffs.a,
    );
    defer allocator.free(forward);

    const reversed = try reverse(allocator, forward);
    defer allocator.free(reversed);

    const backward = try iirFilter(
        allocator,
        reversed,
        coeffs.b,
        coeffs.a,
    );
    defer allocator.free(backward);

    return reverse(allocator, backward);
}

test "Butterworth filtfilt significantly attenuates DC in steady state" {
    const allocator = std.testing.allocator;

    const fs = 100.0;
    const low = 0.5;
    const high = 40.0;

    const N = 256;
    const input = try allocator.alloc(f64, N);
    defer allocator.free(input);

    for (input) |*v| {
        v.* = 1.0;
    }

    const output = try filtfilt(
        allocator,
        input,
        fs,
        low,
        high,
    );
    defer allocator.free(output);

    const start = N / 4;
    const end = N - start;

    var max_abs: f64 = 0.0;
    for (start..end) |i| {
        const a = @abs(output[i]);
        if (a > max_abs) max_abs = a;
    }

    // DC should be attenuated by at least ~10x
    try std.testing.expect(max_abs < 0.2);
}

test "filtfilt rejects invalid band edges" {
    const allocator = std.testing.allocator;
    const x = [_]f64{ 1, 2, 3, 4 };
    try std.testing.expectError(error.InvalidFrequency, filtfilt(allocator, &x, 100.0, 0.0, 40.0));
    try std.testing.expectError(error.InvalidFrequency, filtfilt(allocator, &x, 100.0, 10.0, 5.0));
    try std.testing.expectError(error.InvalidFrequency, filtfilt(allocator, &x, 100.0, 1.0, 60.0));
}

test "filtfilt has zero phase: in-band sine keeps its timing" {
    const allocator = std.testing.allocator;
    const fs = 200.0;
    const N = 800;
    const x = try allocator.alloc(f64, N);
    defer allocator.free(x);
    for (x, 0..) |*v, i| {
        v.* = std.math.sin(2.0 * std.math.pi * 10.0 * @as(f64, @floatFromInt(i)) / fs);
    }
    const y = try filtfilt(allocator, x, fs, 5.0, 20.0);
    defer allocator.free(y);
    // away from the edges, output tracks input closely (zero phase, ~unity gain)
    for (N / 4..3 * N / 4) |i| {
        try std.testing.expectApproxEqAbs(x[i], y[i], 0.05);
    }
}
