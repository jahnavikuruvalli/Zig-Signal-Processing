const std = @import("std");

/// Generate a signal with periodic peaks + noise.
/// Caller owns the returned slice.
pub fn noisyPeaks(
    allocator: std.mem.Allocator,
    fs: f64,
    duration: f64,
    peak_interval: f64,
    noise_level: f64,
) ![]f64 {
    if (!(fs > 0.0 and std.math.isFinite(fs))) return error.InvalidParameter;
    if (!(duration >= 0.0 and std.math.isFinite(duration))) return error.InvalidParameter;
    if (!(peak_interval >= 0.0 and std.math.isFinite(peak_interval))) return error.InvalidParameter;

    const n_f = duration * fs;
    const p_f = peak_interval * fs;
    if (!(n_f < 4.0e9 and p_f < 4.0e9)) return error.InvalidParameter;
    const n_samples = @as(usize, @intFromFloat(n_f));
    const peak_samples = @as(usize, @intFromFloat(p_f));
    if (peak_samples == 0) return error.InvalidPeakInterval;

    const out = try allocator.alloc(f64, n_samples);
    @memset(out, 0.0);

    // Add peaks
    var i: usize = 0;
    while (i < n_samples) : (i += peak_samples) {
        out[i] = 1.0;
    }

    // Add deterministic noise (fixed seed => reproducible)
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const rand = prng.random();

    for (0..n_samples) |k| {
        out[k] += noise_level * (rand.float(f64) - 0.5);
    }

    return out;
}

test "noisyPeaks places peaks and rejects a zero interval" {
    const a = std.testing.allocator;
    const x = try noisyPeaks(a, 100.0, 1.0, 0.5, 0.0);
    defer a.free(x);
    try std.testing.expectEqual(@as(usize, 100), x.len);
    try std.testing.expectEqual(@as(f64, 1.0), x[0]);
    try std.testing.expectEqual(@as(f64, 1.0), x[50]);
    try std.testing.expectError(error.InvalidPeakInterval, noisyPeaks(a, 100.0, 1.0, 0.0, 0.0));
}
