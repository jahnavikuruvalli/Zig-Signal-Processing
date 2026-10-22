const std = @import("std");

/// Gaussian white noise with standard deviation `sigma`.
/// Deterministic: the same `seed` always yields the same samples.
pub fn gaussian(
    allocator: std.mem.Allocator,
    n: usize,
    sigma: f64,
    seed: u64,
) ![]f64 {
    const out = try allocator.alloc(f64, n);
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();
    for (out) |*v| v.* = sigma * rand.floatNorm(f64);
    return out;
}

test "gaussian noise is reproducible and roughly N(0, sigma^2)" {
    const allocator = std.testing.allocator;
    const a = try gaussian(allocator, 20000, 2.0, 42);
    defer allocator.free(a);
    const b = try gaussian(allocator, 20000, 2.0, 42);
    defer allocator.free(b);
    try std.testing.expectEqualSlices(f64, a, b);

    var mean: f64 = 0;
    for (a) |v| mean += v;
    mean /= 20000.0;
    var variance: f64 = 0;
    for (a) |v| variance += (v - mean) * (v - mean);
    variance /= 20000.0;
    try std.testing.expectApproxEqAbs(0.0, mean, 0.06);
    try std.testing.expectApproxEqAbs(4.0, variance, 0.2);
}
