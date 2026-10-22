//! Window functions for spectral analysis.
//!
//! All windows are returned as `f64` samples. Two symmetry conventions exist:
//!
//!   * `.symmetric` - w[0] == w[N-1]; the classic "filter design" window.
//!   * `.periodic`  - one period of a length-N DFT-even window; this is what
//!                    spectral estimators (Welch, etc.) normally want and is
//!                    the default in scipy / MATLAB `pwelch`.
//!
//! The "bartlett" window here is the triangular window with zero end points
//! (MATLAB `bartlett`). Do not confuse it with Bartlett's *method* of
//! averaging periodograms (see `nonparametric.bartlett`).

const std = @import("std");

pub const Kind = enum {
    rectangular,
    bartlett,
    hann,
    hamming,
    blackman,
};

pub const Symmetry = enum { periodic, symmetric };

/// Fill `out` with the chosen window.
pub fn fill(out: []f64, kind: Kind, symmetry: Symmetry) void {
    const n = out.len;
    if (n == 0) return;
    if (n == 1) {
        out[0] = 1.0;
        return;
    }

    const m: f64 = switch (symmetry) {
        .symmetric => @floatFromInt(n - 1),
        .periodic => @floatFromInt(n),
    };
    const two_pi = 2.0 * std.math.pi;

    for (out, 0..) |*w, i| {
        const x = @as(f64, @floatFromInt(i)) / m; // 0 .. 1
        w.* = switch (kind) {
            .rectangular => 1.0,
            .bartlett => 1.0 - @abs(2.0 * x - 1.0),
            .hann => 0.5 - 0.5 * @cos(two_pi * x),
            .hamming => 0.54 - 0.46 * @cos(two_pi * x),
            .blackman => 0.42 - 0.5 * @cos(two_pi * x) + 0.08 * @cos(2.0 * two_pi * x),
        };
    }
}

/// Allocate and return a window of length `n`. Caller frees.
pub fn generate(
    allocator: std.mem.Allocator,
    kind: Kind,
    n: usize,
    symmetry: Symmetry,
) ![]f64 {
    const out = try allocator.alloc(f64, n);
    fill(out, kind, symmetry);
    return out;
}

/// sum(w[n]^2). Used to normalise windowed periodograms so the PSD
/// has the correct units (power per Hz).
pub fn powerSum(w: []const f64) f64 {
    var acc: f64 = 0.0;
    for (w) |v| acc += v * v;
    return acc;
}

/// sum(w[n]). The "coherent gain" times N; used for amplitude spectra.
pub fn sum(w: []const f64) f64 {
    var acc: f64 = 0.0;
    for (w) |v| acc += v;
    return acc;
}

test "hann periodic length 4" {
    var w: [4]f64 = undefined;
    fill(&w, .hann, .periodic);
    const expected = [_]f64{ 0.0, 0.5, 1.0, 0.5 };
    for (expected, w) |e, v| try std.testing.expectApproxEqAbs(e, v, 1e-12);
}

test "hann symmetric length 5" {
    var w: [5]f64 = undefined;
    fill(&w, .hann, .symmetric);
    const expected = [_]f64{ 0.0, 0.5, 1.0, 0.5, 0.0 };
    for (expected, w) |e, v| try std.testing.expectApproxEqAbs(e, v, 1e-12);
}

test "bartlett (triangular) symmetric length 5" {
    var w: [5]f64 = undefined;
    fill(&w, .bartlett, .symmetric);
    const expected = [_]f64{ 0.0, 0.5, 1.0, 0.5, 0.0 };
    for (expected, w) |e, v| try std.testing.expectApproxEqAbs(e, v, 1e-12);
}

test "hamming symmetric length 5" {
    var w: [5]f64 = undefined;
    fill(&w, .hamming, .symmetric);
    // 0.54 - 0.46 cos(2 pi n / 4)
    const expected = [_]f64{ 0.08, 0.54, 1.0, 0.54, 0.08 };
    for (expected, w) |e, v| try std.testing.expectApproxEqAbs(e, v, 1e-12);
}

test "blackman symmetric length 5" {
    var w: [5]f64 = undefined;
    fill(&w, .blackman, .symmetric);
    const expected = [_]f64{ 0.0, 0.34, 1.0, 0.34, 0.0 };
    for (expected, w) |e, v| try std.testing.expectApproxEqAbs(e, v, 1e-12);
}

test "rectangular is all ones and degenerate lengths work" {
    var w: [8]f64 = undefined;
    fill(&w, .rectangular, .periodic);
    for (w) |v| try std.testing.expectEqual(@as(f64, 1.0), v);

    var one: [1]f64 = undefined;
    fill(&one, .hann, .periodic);
    try std.testing.expectEqual(@as(f64, 1.0), one[0]);

    var none: [0]f64 = undefined;
    fill(&none, .hann, .periodic);
}

test "powerSum and sum" {
    const w = [_]f64{ 1, 2, 3 };
    try std.testing.expectEqual(@as(f64, 14.0), powerSum(&w));
    try std.testing.expectEqual(@as(f64, 6.0), sum(&w));
}
