const std = @import("std");

/// Generate a very simple synthetic ECG-like waveform.
///
/// Errors: `error.InvalidParameter` for non-positive or non-finite
/// arguments, `error.HeartRateTooHighForSampleRate` if one beat is shorter
/// than one sample.
/// Caller owns the returned slice.
pub fn syntheticECG(
    allocator: std.mem.Allocator,
    fs: f64,
    duration: f64,
    heart_rate: f64,
) ![]f64 {
    // Reject NaN, infinity, zero and negative values up front; converting
    // them to an integer would be illegal behaviour.
    if (!(fs > 0.0 and std.math.isFinite(fs))) return error.InvalidParameter;
    if (!(duration >= 0.0 and std.math.isFinite(duration))) return error.InvalidParameter;
    if (!(heart_rate > 0.0 and std.math.isFinite(heart_rate))) return error.InvalidParameter;

    const n_f = duration * fs;
    if (!(n_f < 4.0e9)) return error.InvalidParameter;
    const n_samples = @as(usize, @intFromFloat(n_f));

    const rr = 60.0 / heart_rate; // seconds
    const rr_f = rr * fs;
    if (!(rr_f < 4.0e9)) return error.InvalidParameter;
    const rr_samples = @as(usize, @intFromFloat(rr_f));
    if (rr_samples == 0) return error.HeartRateTooHighForSampleRate;

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

test "syntheticECG rejects invalid parameters" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 100.0, 3.0, 0.0));
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 100.0, 3.0, -60.0));
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 0.0, 3.0, 60.0));
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 100.0, std.math.nan(f64), 60.0));
}

test "syntheticECG has one R peak per beat" {
    const a = std.testing.allocator;
    const x = try syntheticECG(a, 100.0, 3.0, 60.0);
    defer a.free(x);
    try std.testing.expectEqual(@as(usize, 300), x.len);
    try std.testing.expectEqual(@as(f64, 1.0), x[0]);
    try std.testing.expectEqual(@as(f64, 1.0), x[100]);
    try std.testing.expectEqual(@as(f64, 1.0), x[200]);
    try std.testing.expectError(error.HeartRateTooHighForSampleRate, syntheticECG(a, 100.0, 3.0, 100000.0));
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 100.0, 3.0, 0.0));
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 100.0, 3.0, std.math.nan(f64)));
    try std.testing.expectError(error.InvalidParameter, syntheticECG(a, 0.0, 3.0, 60.0));
}
