const std = @import("std");
const butter = @import("butterworth.zig");

/// Internal second-order IIR filter implementation.
fn iirFilter(
    allocator: std.mem.Allocator,
    input: []f64,
    b: [3]f64,
    a: [3]f64,
) ![]f64 {
    var y = try allocator.alloc(f64, input.len);
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
    input: []f64,
) ![]f64 {
    var out = try allocator.alloc(f64, input.len);
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
pub fn filtfilt(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    low: f64,
    high: f64,
) ![]f64 {
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
