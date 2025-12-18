const std = @import("std");

/// Generate a very simple synthetic ECG-like waveform
pub fn syntheticECG(
    allocator: std.mem.Allocator,
    fs: f64,
    duration: f64,
    heart_rate: f64,
) ![]f64 {
    const n_samples = @as(usize, @intFromFloat(duration * fs));
    var out = try allocator.alloc(f64, n_samples);
    @memset(out, 0.0);

    const rr = 60.0 / heart_rate; // seconds
    const rr_samples = @as(usize, @intFromFloat(rr * fs));

    var i: usize = 0;
    while (i < n_samples) : (i += rr_samples) {
        if (i < n_samples) {
            out[i] = 1.0;               // R peak
            if (i > 2) out[i - 2] = 0.2; // P
            if (i + 3 < n_samples) out[i + 3] = 0.4; // T
        }
    }

    return out;
}
