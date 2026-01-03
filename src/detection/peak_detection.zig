const std = @import("std");

/// Compute the discrete first derivative of a signal.
fn derivative(
    allocator: std.mem.Allocator,
    input: []f64,
) ![]f64 {
    var out = try allocator.alloc(f64, input.len);
    out[0] = 0.0;

    for (1..input.len) |i| {
        out[i] = input[i] - input[i - 1];
    }

    return out;
}

/// Square each sample of a signal.
fn square(
    allocator: std.mem.Allocator,
    input: []f64,
) ![]f64 {
    var out = try allocator.alloc(f64, input.len);

    for (input, 0..) |v, i| {
        out[i] = v * v;
    }

    return out;
}

/// Moving average filter with a fixed window size.
fn movingAverage(
    allocator: std.mem.Allocator,
    input: []f64,
    window: usize,
) ![]f64 {
    var out = try allocator.alloc(f64, input.len);
    var sum: f64 = 0.0;

    for (0..input.len) |i| {
        sum += input[i];
        if (i >= window) {
            sum -= input[i - window];
        }

        if (i < window) {
            out[i] = sum / @as(f64, @floatFromInt(i + 1));
        } else {
            out[i] = sum / @as(f64, @floatFromInt(window));
        }
    }

    return out;
}

/// Threshold-based peak detection with refractory period.
fn detectPeaks(
    allocator: std.mem.Allocator,
    signal: []f64,
    fs: f64,
) ![]usize {
    const refractory = @as(usize, @intFromFloat(0.2 * fs));

    var peaks = std.ArrayList(usize){};
    defer peaks.deinit(allocator);

    var max_val: f64 = 0.0;
    for (signal) |v| {
        if (v > max_val) max_val = v;
    }

    const threshold = 0.3 * max_val;
    var last_peak: isize = -@as(isize, @intCast(refractory));

    for (1..signal.len - 1) |i| {
        if (signal[i] > threshold and
            signal[i] > signal[i - 1] and
            signal[i] > signal[i + 1] and
            @as(isize, @intCast(i)) - last_peak >= @as(isize, @intCast(refractory)))
        {
            try peaks.append(allocator, i);
            last_peak = @as(isize, @intCast(i));
        }
    }

    return peaks.toOwnedSlice(allocator);
}

/// High-level peak detection pipeline for noisy signals.
///
/// This function implements a derivative → squaring → moving-average
/// pipeline commonly used for ECG R-peak detection.
///
/// Returns indices of detected peaks.
/// The returned slice is heap-allocated and must be freed by the caller.
pub fn detectPeaksFromSignal(
    allocator: std.mem.Allocator,
    signal: []f64,
    fs: f64,
) ![]usize {
    const diff = try derivative(allocator, signal);
    defer allocator.free(diff);

    const sq = try square(allocator, diff);
    defer allocator.free(sq);

    const window = @as(usize, @intFromFloat(0.15 * fs));
    const ma = try movingAverage(allocator, sq, window);
    defer allocator.free(ma);

    return detectPeaks(allocator, ma, fs);
}

test "detectPeaksFromSignal detects physiologically plausible peaks in synthetic ECG" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const fs = 250.0;
    const duration = 4.0;
    const heart_rate = 60.0;

    const signal = @import("../signal.zig");

    const ecg = try signal.signals.synthetic_ecg.syntheticECG(
        allocator,
        fs,
        duration,
        heart_rate,
    );
    defer allocator.free(ecg);

    const peaks = try detectPeaksFromSignal(
        allocator,
        ecg,
        fs,
    );
    defer allocator.free(peaks);

    // At least one peak should be detected
    try std.testing.expect(peaks.len >= 1);

    // Peaks should not be unreasonably close
    for (1..peaks.len) |i| {
        const diff = peaks[i] - peaks[i - 1];
        try std.testing.expect(diff > @as(usize, @intFromFloat(0.4 * fs)));
    }
}
