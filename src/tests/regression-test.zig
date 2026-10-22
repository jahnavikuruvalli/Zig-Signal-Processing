//! Regression tests for bugs found during the audit. Each test would have
//! failed (or failed to compile / crashed) before the corresponding fix.

const std = @import("std");
const signal = @import("../signal.zig");
const PeakDetector = signal.core.PeakDetector;
const MovingAverage = signal.core.MovingAverage;

// ---------------------------------------------------------------- PeakDetector

test "peak detector finds the very first peak" {
    var pd = PeakDetector.init(5);
    var count: usize = 0;
    // First peak occurs at sample 3, i.e. inside the first `refractory` samples.
    for ([_]f32{ 0, 1, 5, 1, 0, 0 }) |x| {
        if (pd.process(x).detected) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), count);
}

test "peak detector finds every one of 400 identical peaks" {
    var pd = PeakDetector.init(5);
    var count: usize = 0;
    for (0..400) |_| {
        for ([_]f32{ 0, 1, 5, 1, 0, 0, 0, 0, 0, 0 }) |x| {
            if (pd.process(x).detected) count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 400), count);
}

test "peak detector works on a negative baseline with initWithFloor" {
    var pd = PeakDetector.initWithFloor(5, -6.0);
    var count: usize = 0;
    const sig = [_]f32{ -9, -9, -8, -5, -8, -9, -9, -9, -9, -9, -9, -8, -4, -8, -9 };
    for (sig) |x| {
        if (pd.process(x).detected) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "peak detector still finds smaller-than-average peaks" {
    var pd = PeakDetector.init(3);
    // Twenty tall peaks (height 10) followed by a clearly smaller one (height 6).
    for (0..20) |_| {
        for ([_]f32{ 0, 5, 10, 5, 0, 0, 0, 0 }) |x| _ = pd.process(x);
    }
    var found: f32 = 0;
    for ([_]f32{ 0, 3, 6, 3, 0, 0 }) |x| {
        const e = pd.process(x);
        if (e.detected) found = e.value;
    }
    try std.testing.expectEqual(@as(f32, 6.0), found);
}

test "peak detector respects the refractory period" {
    var pd = PeakDetector.init(20);
    var count: usize = 0;
    // Two peaks only 6 samples apart: the second must be suppressed.
    for ([_]f32{ 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0 }) |x| {
        if (pd.process(x).detected) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), count);
}

test "peak detector reset restores initial state" {
    var pd = PeakDetector.init(2);
    for ([_]f32{ 0, 4, 0, 0 }) |x| _ = pd.process(x);
    pd.reset();
    try std.testing.expectEqual(@as(f32, 0.0), pd.threshold);
    var count: usize = 0;
    for ([_]f32{ 0, 4, 0, 0 }) |x| {
        if (pd.process(x).detected) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), count);
}

// ---------------------------------------------------------------- MovingAverage

test "moving average does not drift after a huge spike" {
    var buf: [8]f32 = undefined;
    var ma = MovingAverage.init(&buf);
    _ = ma.process(1.0e8);
    var y: f32 = 0;
    for (0..100_000) |_| y = ma.process(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), y);
}

test "moving average reset" {
    var buf: [3]f32 = undefined;
    var ma = MovingAverage.init(&buf);
    _ = ma.process(3);
    _ = ma.process(3);
    ma.reset();
    try std.testing.expectEqual(@as(f32, 6.0), ma.process(6));
}

// ---------------------------------------------------------------- HRV

test "hrv metrics have the right values" {
    const allocator = std.testing.allocator;
    // fs = 250 Hz; RR = 1000, 1000, 1200 ms
    const peaks = [_]usize{ 0, 250, 500, 800 };
    const h = try signal.metrics.computeHRV(allocator, &peaks, 250.0);
    try std.testing.expectApproxEqAbs(115.4700538, h.sdnn, 1e-4);
    try std.testing.expectApproxEqAbs(141.4213562, h.rmssd, 1e-4);
    try std.testing.expectApproxEqAbs(50.0, h.pnn50, 1e-9);
}

test "hrv with too few peaks reports an error instead of dividing by zero" {
    const allocator = std.testing.allocator;
    const one = [_]usize{100};
    try std.testing.expectError(error.NotEnoughIntervals, signal.metrics.computeHRV(allocator, &one, 250.0));
    const two = [_]usize{ 100, 350 }; // a single RR interval: SDNN undefined
    try std.testing.expectError(error.NotEnoughIntervals, signal.metrics.computeHRV(allocator, &two, 250.0));

    const rr = [_]f64{800.0};
    try std.testing.expect(std.math.isNan(signal.metrics.sdnn(&rr)));
    try std.testing.expect(std.math.isNan(signal.metrics.rmssd(&rr)));
    try std.testing.expect(std.math.isNan(signal.metrics.pnn50(&rr)));
    const none: []const f64 = &.{};
    try std.testing.expect(std.math.isNan(signal.metrics.pnn50(none)));
}

// ---------------------------------------------------------------- signal generators

test "noisyPeaks compiles, has the right length, and is reproducible" {
    const allocator = std.testing.allocator;
    const a = try signal.signals.noisy_peaks.noisyPeaks(allocator, 100.0, 2.0, 0.5, 0.1);
    defer allocator.free(a);
    const b = try signal.signals.noisy_peaks.noisyPeaks(allocator, 100.0, 2.0, 0.5, 0.1);
    defer allocator.free(b);
    try std.testing.expectEqual(@as(usize, 200), a.len);
    try std.testing.expectEqualSlices(f64, a, b);
    // peaks at 0, 50, 100, 150 stand clearly above noise (+-0.05)
    try std.testing.expect(a[50] > 0.9);
}

test "noisyPeaks rejects a zero peak interval instead of looping forever" {
    try std.testing.expectError(
        error.InvalidPeakInterval,
        signal.signals.noisy_peaks.noisyPeaks(std.testing.allocator, 100.0, 1.0, 0.0, 0.1),
    );
}

test "syntheticECG rejects parameters that would loop forever" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.InvalidParameter, signal.signals.synthetic_ecg.syntheticECG(a, 250.0, 1.0, 0.0));
    try std.testing.expectError(error.HeartRateTooHighForSampleRate, signal.signals.synthetic_ecg.syntheticECG(a, 1.0, 10.0, 6000.0));
}

// ---------------------------------------------------------------- public API surface

test "README-advertised streaming blocks are exported" {
    _ = signal.core.MovingAverage;
    _ = signal.core.PeakDetector;
    _ = signal.core.Derivative;
    _ = signal.core.Squaring;
    _ = signal.core.BiquadCascade;
    _ = signal.core.Stage;
    _ = signal.spectral;
}
