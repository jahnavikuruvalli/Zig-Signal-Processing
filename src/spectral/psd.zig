//! Shared types and helpers for power spectral density (PSD) estimation.
//!
//! Conventions used by every estimator in `signal.spectral`:
//!
//!   * The result is a power spectral *density*, in (units of x)^2 per Hz.
//!     Integrating it over frequency gives signal power:
//!         sum(psd) * (fs / nfft)  ~=  mean(x^2)
//!   * `onesided = true` (default) returns bins 0 .. nfft/2 (0 Hz to Nyquist)
//!     with all bins except DC and Nyquist doubled, so that the total power
//!     is preserved. `onesided = false` returns all `nfft` bins.
//!   * `nfft` must be a power of two (the FFT is radix-2). If you do not
//!     give one, the smallest suitable power of two is used.
//!   * `fs` is the sampling rate in Hz (default 1.0, i.e. cycles/sample).

const std = @import("std");
const fft_mod = @import("../fft/fft.zig");

pub const Complex = fft_mod.Complex;

/// Pre-processing applied to every analysed segment before windowing.
pub const Detrend = enum {
    /// Use the data as-is.
    none,
    /// Subtract the mean (remove DC).
    constant,
    /// Subtract the least-squares straight line.
    linear,
};

/// Options shared by the non-parametric estimators.
pub const Options = struct {
    /// Sampling frequency in Hz.
    fs: f64 = 1.0,
    /// FFT length (power of two, >= segment length). null = automatic.
    nfft: ?usize = null,
    detrend: Detrend = .none,
    /// true: bins 0..nfft/2 with power folded in; false: all nfft bins.
    onesided: bool = true,
    /// Window symmetry for windowed estimators (ignored for rectangular).
    window_symmetry: @import("window.zig").Symmetry = .periodic,
};

/// A PSD estimate: `power[k]` is the density at frequency `freqs[k]` (Hz).
pub const Psd = struct {
    allocator: std.mem.Allocator,
    freqs: []f64,
    power: []f64,
    fs: f64,

    pub fn deinit(self: *Psd) void {
        self.allocator.free(self.freqs);
        self.allocator.free(self.power);
        self.* = undefined;
    }

    /// Spacing between bins in Hz.
    pub fn binWidth(self: Psd) f64 {
        if (self.freqs.len < 2) return 0.0;
        return self.freqs[1] - self.freqs[0];
    }

    /// Total power = integral of the PSD over the returned bins.
    pub fn totalPower(self: Psd) f64 {
        var acc: f64 = 0.0;
        for (self.power) |p| acc += p;
        return acc * self.binWidth();
    }

    /// Index of the bin with the largest power.
    pub fn peakIndex(self: Psd) usize {
        var best: usize = 0;
        for (self.power, 0..) |p, i| {
            if (p > self.power[best]) best = i;
        }
        return best;
    }

    /// Frequency (Hz) of the strongest bin.
    pub fn peakFrequency(self: Psd) f64 {
        return self.freqs[self.peakIndex()];
    }
};

/// Remove a constant or linear trend from `x` in place.
pub fn detrendInPlace(x: []f64, kind: Detrend) void {
    const n = x.len;
    if (n == 0 or kind == .none) return;

    const nf: f64 = @floatFromInt(n);
    var mean: f64 = 0.0;
    for (x) |v| mean += v;
    mean /= nf;

    if (kind == .constant or n < 2) {
        for (x) |*v| v.* -= mean;
        return;
    }

    // Least-squares line using centred time t_i = i - (n-1)/2.
    const t_mid = (nf - 1.0) / 2.0;
    var sxy: f64 = 0.0;
    var sxx: f64 = 0.0;
    for (x, 0..) |v, i| {
        const t = @as(f64, @floatFromInt(i)) - t_mid;
        sxy += t * v;
        sxx += t * t;
    }
    const slope = sxy / sxx;
    for (x, 0..) |*v, i| {
        const t = @as(f64, @floatFromInt(i)) - t_mid;
        v.* -= mean + slope * t;
    }
}

pub fn validateFs(fs: f64) !void {
    if (!(fs > 0.0) or !std.math.isFinite(fs)) return error.InvalidSampleRate;
}

/// Pick / validate the FFT length. `min_len` is the smallest allowed value.
pub fn resolveNfft(requested: ?usize, min_len: usize) !usize {
    if (requested) |n| {
        if (!fft_mod.isPowerOfTwo(n) or n < min_len or n < 2) return error.InvalidFftLength;
        return n;
    }
    return @max(2, fft_mod.nextPowerOfTwo(min_len));
}

pub fn binCount(nfft: usize, onesided: bool) usize {
    return if (onesided) nfft / 2 + 1 else nfft;
}

/// Double every bin except DC and Nyquist (one-sided spectrum convention).
pub fn foldOneSided(power: []f64) void {
    if (power.len < 3) return;
    for (power[1 .. power.len - 1]) |*p| p.* *= 2.0;
}

/// Allocate the frequency axis k * fs / nfft for k = 0 .. nbins-1.
pub fn makeFreqs(allocator: std.mem.Allocator, nfft: usize, nbins: usize, fs: f64) ![]f64 {
    const f = try allocator.alloc(f64, nbins);
    const df = fs / @as(f64, @floatFromInt(nfft));
    for (f, 0..) |*v, k| v.* = df * @as(f64, @floatFromInt(k));
    return f;
}

test "detrend constant" {
    var x = [_]f64{ 3, 5, 7 };
    detrendInPlace(&x, .constant);
    try std.testing.expectApproxEqAbs(-2.0, x[0], 1e-12);
    try std.testing.expectApproxEqAbs(0.0, x[1], 1e-12);
    try std.testing.expectApproxEqAbs(2.0, x[2], 1e-12);
}

test "detrend linear removes a ramp exactly" {
    var x: [10]f64 = undefined;
    for (&x, 0..) |*v, i| v.* = 4.0 + 2.5 * @as(f64, @floatFromInt(i));
    detrendInPlace(&x, .linear);
    for (x) |v| try std.testing.expectApproxEqAbs(0.0, v, 1e-10);
}

test "detrend none leaves data alone" {
    var x = [_]f64{ 1, 2, 3 };
    detrendInPlace(&x, .none);
    try std.testing.expectEqual(@as(f64, 2.0), x[1]);
}

test "resolveNfft" {
    try std.testing.expectEqual(@as(usize, 128), try resolveNfft(null, 100));
    try std.testing.expectEqual(@as(usize, 256), try resolveNfft(256, 100));
    try std.testing.expectError(error.InvalidFftLength, resolveNfft(100, 50)); // not pow2
    try std.testing.expectError(error.InvalidFftLength, resolveNfft(64, 100)); // too small
}
