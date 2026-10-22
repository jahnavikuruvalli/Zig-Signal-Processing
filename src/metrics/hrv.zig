const std = @import("std");

/// Compute RR intervals (in milliseconds) from detected peak indices.
///
/// Returns an error if fewer than two peaks are provided.
/// Caller owns the returned slice.
pub fn rrIntervals(
    allocator: std.mem.Allocator,
    peaks: []const usize,
    fs: f64,
) ![]f64 {
    if (peaks.len < 2)
        return error.NotEnoughIntervals;

    const rr = try allocator.alloc(f64, peaks.len - 1);

    for (1..peaks.len) |i| {
        const diff_samples = peaks[i] - peaks[i - 1];
        rr[i - 1] = (@as(f64, @floatFromInt(diff_samples)) / fs) * 1000.0;
    }

    return rr;
}

/// Compute the arithmetic mean of a slice (0 for an empty slice).
fn mean(data: []const f64) f64 {
    if (data.len == 0) return 0.0;
    var sum: f64 = 0.0;
    for (data) |v| sum += v;
    return sum / @as(f64, @floatFromInt(data.len));
}

/// Standard deviation of NN (RR) intervals (SDNN).
///
/// Units: milliseconds. Returns NaN (undefined) with fewer than two intervals.
pub fn sdnn(rr: []const f64) f64 {
    if (rr.len < 2) return std.math.nan(f64);
    const mu = mean(rr);

    var sum_sq: f64 = 0.0;
    for (rr) |v| {
        const d = v - mu;
        sum_sq += d * d;
    }

    return std.math.sqrt(sum_sq / @as(f64, @floatFromInt(rr.len - 1)));
}

/// Root mean square of successive differences (RMSSD).
///
/// Units: milliseconds. Returns NaN (undefined) with fewer than two intervals.
pub fn rmssd(rr: []const f64) f64 {
    if (rr.len < 2) return std.math.nan(f64);
    var sum_sq: f64 = 0.0;

    for (1..rr.len) |i| {
        const diff = rr[i] - rr[i - 1];
        sum_sq += diff * diff;
    }

    return std.math.sqrt(sum_sq / @as(f64, @floatFromInt(rr.len - 1)));
}

/// Percentage of successive RR differences greater than 50 ms (pNN50).
///
/// Units: percentage. Returns NaN (undefined) with fewer than two intervals.
pub fn pnn50(rr: []const f64) f64 {
    if (rr.len < 2) return std.math.nan(f64);
    var count: usize = 0;

    for (1..rr.len) |i| {
        if (@abs(rr[i] - rr[i - 1]) > 50.0) {
            count += 1;
        }
    }

    return (@as(f64, @floatFromInt(count)) /
        @as(f64, @floatFromInt(rr.len - 1))) * 100.0;
}

/// Common time-domain heart rate variability metrics.
pub const HRV = struct {
    sdnn: f64,
    rmssd: f64,
    pnn50: f64,
};

/// Compute standard time-domain HRV metrics from detected peaks.
///
/// Needs at least three peaks (two RR intervals); otherwise returns
/// `error.NotEnoughIntervals`.
pub fn computeHRV(
    allocator: std.mem.Allocator,
    peaks: []const usize,
    fs: f64,
) !HRV {
    if (peaks.len < 3) return error.NotEnoughIntervals;

    const rr = try rrIntervals(allocator, peaks, fs);
    defer allocator.free(rr);

    return HRV{
        .sdnn = sdnn(rr),
        .rmssd = rmssd(rr),
        .pnn50 = pnn50(rr),
    };
}

test "HRV of perfectly regular beats is zero variability" {
    const peaks = [_]usize{ 0, 250, 500, 750 };
    const hrv = try computeHRV(std.testing.allocator, &peaks, 250.0);
    try std.testing.expectApproxEqAbs(0.0, hrv.sdnn, 1e-9);
    try std.testing.expectApproxEqAbs(0.0, hrv.rmssd, 1e-9);
    try std.testing.expectApproxEqAbs(0.0, hrv.pnn50, 1e-9);
}

test "HRV known values" {
    // RR = 1000, 1100, 1000 ms at fs = 1000
    const peaks = [_]usize{ 0, 1000, 2100, 3100 };
    const hrv = try computeHRV(std.testing.allocator, &peaks, 1000.0);
    // mean 1033.33, sdnn = sqrt(((-33.33)^2*2 + 66.67^2)/2) = 57.735
    try std.testing.expectApproxEqAbs(57.735, hrv.sdnn, 1e-2);
    // rmssd = sqrt((100^2 + 100^2)/2) = 100
    try std.testing.expectApproxEqAbs(100.0, hrv.rmssd, 1e-9);
    // both successive differences (100 ms) exceed 50 ms
    try std.testing.expectApproxEqAbs(100.0, hrv.pnn50, 1e-9);
}

test "HRV with too few peaks returns an error" {
    const peaks = [_]usize{ 0, 250 };
    try std.testing.expectError(
        error.NotEnoughIntervals,
        computeHRV(std.testing.allocator, &peaks, 250.0),
    );
}

test "metrics are NaN (undefined) for fewer than two intervals" {
    const one = [_]f64{800.0};
    const none = [_]f64{};
    try std.testing.expect(std.math.isNan(sdnn(&one)));
    try std.testing.expect(std.math.isNan(rmssd(&one)));
    try std.testing.expect(std.math.isNan(pnn50(&one)));
    try std.testing.expect(std.math.isNan(pnn50(&none)));
}

test "HRV from irregular peaks" {
    // RR = 1000, 1000, 1200 ms at fs = 250
    const peaks = [_]usize{ 0, 250, 500, 800 };
    const hrv = try computeHRV(std.testing.allocator, &peaks, 250.0);
    try std.testing.expectApproxEqAbs(115.47, hrv.sdnn, 1e-2);
    try std.testing.expectApproxEqAbs(141.42, hrv.rmssd, 1e-2);
    try std.testing.expectApproxEqAbs(50.0, hrv.pnn50, 1e-9);
}
