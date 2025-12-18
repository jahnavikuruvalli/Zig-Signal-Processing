const std = @import("std");

/// Generate a signal with periodic peaks + noise
pub fn noisyPeaks(
    allocator: std.mem.Allocator,
    fs: f64,
    duration: f64,
    peak_interval: f64,
    noise_level: f64,
) ![]f64 {
    const n_samples = @as(usize, @intFromFloat(duration * fs));
    var out = try allocator.alloc(f64, n_samples);
    @memset(out, 0.0);

    const peak_samples = @as(usize, @intFromFloat(peak_interval * fs));

    // Add peaks
    var i: usize = 0;
    while (i < n_samples) : (i += peak_samples) {
        if (i < n_samples) {
            out[i] = 1.0;
        }
    }

    // Add noise
    var prng = std.rand.DefaultPrng.init(0xdeadbeef);
    const rand = prng.random();

    for (0..n_samples) |k| {
        out[k] += noise_level * (rand.float(f64) - 0.5);
    }

    return out;
}
