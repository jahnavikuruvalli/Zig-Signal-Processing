const std = @import("std");

pub fn derivative(
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

pub fn square(
    allocator: std.mem.Allocator,
    input: []f64,
) ![]f64 {
    var out = try allocator.alloc(f64, input.len);

    for (input, 0..) |v, i| {
        out[i] = v * v;
    }

    return out;
}

pub fn movingAverage(
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

pub fn detectPeaks(
    allocator: std.mem.Allocator,
    signal: []f64,
    fs: f64,
) ![]usize {
    const refractory = @as(usize, @intFromFloat(0.2 * fs));

    var peaks = std.ArrayList(usize).init(allocator);
    defer peaks.deinit();

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
            try peaks.append(i);
            last_peak = @as(isize, @intCast(i));
        }
    }

    return peaks.toOwnedSlice();
}

/// Example pipeline for peak detection in noisy signals.
/// This is commonly used for ECG R-peak detection, but is kept generic.
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
