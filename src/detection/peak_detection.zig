const std = @import("std");

/// Compute the discrete first derivative of a signal.
fn derivative(
    allocator: std.mem.Allocator,
    input: []const f64,
) ![]f64 {
    const out = try allocator.alloc(f64, input.len);
    if (out.len > 0) out[0] = 0.0;

    for (1..input.len) |i| {
        out[i] = input[i] - input[i - 1];
    }

    return out;
}

/// Square each sample of a signal.
fn square(
    allocator: std.mem.Allocator,
    input: []const f64,
) ![]f64 {
    const out = try allocator.alloc(f64, input.len);

    for (input, 0..) |v, i| {
        out[i] = v * v;
    }

    return out;
}

/// Moving average filter with a fixed window size.
fn movingAverage(
    allocator: std.mem.Allocator,
    input: []const f64,
    window_in: usize,
) ![]f64 {
    const window = @max(window_in, 1);
    const out = try allocator.alloc(f64, input.len);
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
    signal: []const f64,
    fs: f64,
) ![]usize {
    if (signal.len < 3) return allocator.alloc(usize, 0);
    const refractory = @as(usize, @intFromFloat(0.2 * fs));

    var peaks = std.ArrayList(usize).empty;
    defer peaks.deinit(allocator);

    var max_val: f64 = 0.0;
    for (signal) |v| {
        if (v > max_val) max_val = v;
    }

    const threshold = 0.15 * max_val;
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

/// Helper to refine peak location to local maximum
fn snapToLocalMax(
    signal: []const f64,
    idx: usize,
    radius: usize,
) usize {
    var best = idx;
    var best_val = signal[idx];

    const start = if (idx > radius) idx - radius else 0;
    const end = @min(signal.len - 1, idx + radius);

    var i = start;
    while (i <= end) : (i += 1) {
        if (signal[i] > best_val) {
            best_val = signal[i];
            best = i;
        }
    }
    return best;
}

/// High-level peak detection pipeline for noisy signals.
pub fn detectPeaksFromSignal(
    allocator: std.mem.Allocator,
    signal: []const f64,
    fs: f64,
) ![]usize {
    if (signal.len < 3) return allocator.alloc(usize, 0);

    const diff = try derivative(allocator, signal);
    defer allocator.free(diff);

    const sq = try square(allocator, diff);
    defer allocator.free(sq);

    const window = @as(usize, @intFromFloat(0.15 * fs));
    const ma = try movingAverage(allocator, sq, window);
    defer allocator.free(ma);

    const rough = try detectPeaks(allocator, ma, fs);
    defer allocator.free(rough);

    const refined = try allocator.alloc(usize, rough.len);

    for (rough, 0..) |p, i| {
        refined[i] = snapToLocalMax(signal, p, @as(usize, @intFromFloat(0.05 * fs)));
    }

    return refined;
}

test "detectPeaksFromSignal detects physiologically plausible peaks in synthetic ECG" {
    const allocator = std.testing.allocator;

    const fs = 250.0;
    const duration = 4.0;
    const heart_rate = 60.0;

    const signal_lib = @import("../signal.zig");

    const ecg = try signal_lib.signals.synthetic_ecg.syntheticECG(
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

test "detectPeaksFromSignal handles empty and tiny inputs" {
    const allocator = std.testing.allocator;
    const empty = [_]f64{};
    const p0 = try detectPeaksFromSignal(allocator, &empty, 250.0);
    defer allocator.free(p0);
    try std.testing.expectEqual(@as(usize, 0), p0.len);

    const two = [_]f64{ 1.0, 2.0 };
    const p2 = try detectPeaksFromSignal(allocator, &two, 250.0);
    defer allocator.free(p2);
    try std.testing.expectEqual(@as(usize, 0), p2.len);
}
