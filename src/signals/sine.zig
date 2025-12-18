const std = @import("std");

/// Generate a sine wave signal
pub fn sine(
    allocator: std.mem.Allocator,
    freq: f64,
    fs: f64,
    duration: f64,
) ![]f64 {
    const n_samples = @as(usize, @intFromFloat(duration * fs));
    var out = try allocator.alloc(f64, n_samples);

    for (0..n_samples) |i| {
        const t = @as(f64, @floatFromInt(i)) / fs;
        out[i] = std.math.sin(2.0 * std.math.pi * freq * t);
    }

    return out;
}
