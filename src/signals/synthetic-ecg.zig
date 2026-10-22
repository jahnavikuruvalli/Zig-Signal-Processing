const std = @import("std");

/// Generate a very simple synthetic ECG-like waveform.
/// Caller owns the returned slice.
pub fn syntheticECG(
    allocator: std.mem.Allocator,
    fs: f64,
    duration: f64,
    heart_rate: f64,
) ![]f64 {
    const n_samples = @as(usize, @intFromFloat(duration * fs));

    const rr = 60.0 / heart_rate; // seconds
    const rr_samples = @as(usize, @intFromFloat(rr * fs));
    if (rr_samples == 0) return error.InvalidHeartRate;

    const out = try allocator.alloc(f64, n_samples);
    @memset(out, 0.0);

    var i: usize = 0;
    while (i < n_samples) : (i += rr_samples) {
        out[i] = 1.0; // R peak
        if (i >= 2) out[i - 2] = 0.2; // P
        if (i + 3 < n_samples) out[i + 3] = 0.4; // T
    }

    return out;
}

test "syntheticECG has one R peak per beat" {
    const a = std.testing.allocator;
    const x = try syntheticECG(a, 100.0, 3.0, 60.0);
    defer a.free(x);
    try std.testing.expectEqual(@as(usize, 300), x.len);
    try std.testing.expectEqual(@as(f64, 1.0), x[0]);
    try std.testing.expectEqual(@as(f64, 1.0), x[100]);
    try std.testing.expectEqual(@as(f64, 1.0), x[200]);
    try std.testing.expectError(error.InvalidHeartRate, syntheticECG(a, 100.0, 3.0, 100000.0));
}
