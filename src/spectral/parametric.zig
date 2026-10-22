//! Parametric (autoregressive) PSD estimators: Yule-Walker and Burg.
//!
//! Model: x[n] = -a1*x[n-1] - ... - ap*x[n-p] + e[n],  e ~ white, variance s2.
//! With A(z) = 1 + a1 z^-1 + ... + ap z^-p, the PSD is
//!
//!     P(f) = s2 / (fs * |A(e^{j 2 pi f / fs})|^2).
//!
//! (Same sign convention as MATLAB `aryule`/`arburg` and statsmodels' "rho"
//! flipped: our `coeffs[k]` is MATLAB's a(k+1).)
//!
//! Yule-Walker estimates the coefficients from the sample autocorrelation
//! (Levinson-Durbin recursion). Burg minimises forward + backward
//! prediction error directly on the data, which gives sharper peaks and
//! better behaviour on short records, and is guaranteed stable.
//!
//! AR methods assume zero-mean data: `ArOptions.detrend` defaults to
//! `.constant` (mean removal), unlike the non-parametric estimators.

const std = @import("std");
const fft_mod = @import("../fft/fft.zig");
const psd = @import("psd.zig");

pub const Psd = psd.Psd;
pub const Detrend = psd.Detrend;
pub const Complex = psd.Complex;

pub const AutocorrEstimator = enum {
    /// r[k] = (1/N) * sum x[n] x[n-k]. Always positive semi-definite, so
    /// the Yule-Walker model is always stable. Recommended.
    biased,
    /// r[k] = 1/(N-k) * sum ... Lower bias but the resulting Toeplitz matrix
    /// can lose positive-definiteness (Levinson may fail with
    /// `error.NotPositiveDefinite`).
    unbiased,
};

pub const ArOptions = struct {
    /// Sampling frequency in Hz.
    fs: f64 = 1.0,
    /// FFT length used to evaluate the AR spectrum (power of two,
    /// > model order). null = 1024.
    nfft: ?usize = null,
    /// Defaults to mean removal (AR models assume zero-mean data).
    detrend: Detrend = .constant,
    onesided: bool = true,
    /// Only used by Yule-Walker.
    autocorrelation: AutocorrEstimator = .biased,
};

pub const default_nfft: usize = 1024;

/// Fitted AR model. Caller owns it and must `deinit()`.
pub const ArModel = struct {
    allocator: std.mem.Allocator,
    /// a_1 .. a_p of A(z) = 1 + sum a_k z^-k (the leading 1 is implied).
    coeffs: []f64,
    /// Reflection (partial correlation) coefficients k_1 .. k_p.
    /// |k_i| < 1 for every i  <=>  the model is stable.
    reflection: []f64,
    /// Driving-noise variance s2 (final prediction-error power).
    variance: f64,

    pub fn order(self: ArModel) usize {
        return self.coeffs.len;
    }

    pub fn deinit(self: *ArModel) void {
        self.allocator.free(self.coeffs);
        self.allocator.free(self.reflection);
        self.* = undefined;
    }
};

/// Sample autocorrelation r[0..=max_lag] (length max_lag + 1). Caller frees.
pub fn autocorrelation(
    allocator: std.mem.Allocator,
    x: []const f64,
    max_lag: usize,
    estimator: AutocorrEstimator,
) ![]f64 {
    if (x.len == 0) return error.InputTooShort;
    if (max_lag >= x.len) return error.InvalidOrder;

    const r = try allocator.alloc(f64, max_lag + 1);
    const n = x.len;
    for (0..max_lag + 1) |k| {
        var acc: f64 = 0.0;
        for (k..n) |i| acc += x[i] * x[i - k];
        const denom: f64 = switch (estimator) {
            .biased => @floatFromInt(n),
            .unbiased => @floatFromInt(n - k),
        };
        r[k] = acc / denom;
    }
    return r;
}

/// Levinson-Durbin recursion: solve the Yule-Walker equations for an AR
/// model of order `r.len - 1` given autocorrelation `r[0..=p]`.
/// O(p^2) instead of the O(p^3) of a general linear solve.
pub fn levinsonDurbin(allocator: std.mem.Allocator, r: []const f64) !ArModel {
    if (r.len < 2) return error.InvalidOrder;
    const p = r.len - 1;
    if (!(r[0] > 0.0) or !std.math.isFinite(r[0])) return error.ZeroVariance;

    const a = try allocator.alloc(f64, p);
    errdefer allocator.free(a);
    const refl = try allocator.alloc(f64, p);
    errdefer allocator.free(refl);
    const tmp = try allocator.alloc(f64, p);
    defer allocator.free(tmp);
    @memset(a, 0.0);

    var e = r[0];
    for (1..p + 1) |m| {
        // acc = r[m] + sum_{i=1}^{m-1} a_i r[m-i]
        var acc = r[m];
        for (1..m) |i| acc += a[i - 1] * r[m - i];

        const k = -acc / e;

        // a_i <- a_i + k * a_{m-i}   (i = 1..m-1), a_m <- k
        for (1..m) |i| tmp[i - 1] = a[i - 1] + k * a[m - i - 1];
        for (1..m) |i| a[i - 1] = tmp[i - 1];
        a[m - 1] = k;
        refl[m - 1] = k;

        e *= (1.0 - k * k);
        if (!(e > 0.0)) return error.NotPositiveDefinite;
    }

    return ArModel{ .allocator = allocator, .coeffs = a, .reflection = refl, .variance = e };
}

fn checkOrder(order: usize, n: usize) !void {
    if (order < 1 or order >= n) return error.InvalidOrder;
}

/// Fit an AR(order) model with the Yule-Walker (autocorrelation) method.
pub fn yuleWalkerModel(
    allocator: std.mem.Allocator,
    x: []const f64,
    order: usize,
    o: ArOptions,
) !ArModel {
    try checkOrder(order, x.len);
    for (x) |v| if (!std.math.isFinite(v)) return error.NonFiniteInput;

    const work = try allocator.dupe(f64, x);
    defer allocator.free(work);
    psd.detrendInPlace(work, o.detrend);

    const r = try autocorrelation(allocator, work, order, o.autocorrelation);
    defer allocator.free(r);
    return levinsonDurbin(allocator, r);
}

/// Fit an AR(order) model with Burg's method.
///
/// For m = 1..p it picks the reflection coefficient k_m that minimises the
/// summed forward and backward prediction error power, then updates both
/// error sequences with the lattice recursions
///     f_m[n] = f_{m-1}[n] + k_m * b_{m-1}[n-1]
///     b_m[n] = b_{m-1}[n-1] + k_m * f_{m-1}[n]
/// and the polynomial with the Levinson step. Always |k_m| <= 1.
pub fn burgModel(
    allocator: std.mem.Allocator,
    x: []const f64,
    order: usize,
    o: ArOptions,
) !ArModel {
    const n = x.len;
    try checkOrder(order, n);
    for (x) |v| if (!std.math.isFinite(v)) return error.NonFiniteInput;

    const f = try allocator.dupe(f64, x);
    defer allocator.free(f);
    psd.detrendInPlace(f, o.detrend);
    const b = try allocator.dupe(f64, f);
    defer allocator.free(b);

    const a = try allocator.alloc(f64, order);
    errdefer allocator.free(a);
    const refl = try allocator.alloc(f64, order);
    errdefer allocator.free(refl);
    const tmp = try allocator.alloc(f64, order);
    defer allocator.free(tmp);
    @memset(a, 0.0);

    var e: f64 = 0.0;
    for (f) |v| e += v * v;
    e /= @as(f64, @floatFromInt(n));
    if (!(e > 0.0)) return error.ZeroVariance;

    for (1..order + 1) |m| {
        var num: f64 = 0.0;
        var den: f64 = 0.0;
        for (m..n) |i| {
            num += f[i] * b[i - 1];
            den += f[i] * f[i] + b[i - 1] * b[i - 1];
        }
        if (!(den > 0.0)) return error.ZeroVariance;
        const k = -2.0 * num / den;

        for (1..m) |i| tmp[i - 1] = a[i - 1] + k * a[m - i - 1];
        for (1..m) |i| a[i - 1] = tmp[i - 1];
        a[m - 1] = k;
        refl[m - 1] = k;

        // Update error sequences, highest index first so b[i-1] is still "old".
        var i = n - 1;
        while (i >= m) : (i -= 1) {
            const fi = f[i];
            f[i] = fi + k * b[i - 1];
            b[i] = b[i - 1] + k * fi;
        }

        e *= (1.0 - k * k);
    }

    return ArModel{ .allocator = allocator, .coeffs = a, .reflection = refl, .variance = e };
}

/// Evaluate the PSD of an AR model on an FFT grid.
pub fn arPsd(allocator: std.mem.Allocator, model: ArModel, o: ArOptions) !Psd {
    try psd.validateFs(o.fs);
    const nfft = try psd.resolveNfft(o.nfft orelse default_nfft, model.order() + 1);
    const nbins = psd.binCount(nfft, o.onesided);

    const buf = try allocator.alloc(Complex, nfft);
    defer allocator.free(buf);
    @memset(buf, Complex{ .re = 0.0, .im = 0.0 });
    buf[0].re = 1.0;
    for (model.coeffs, 0..) |c, i| buf[i + 1].re = c;
    try fft_mod.fft(buf); // buf[k] = A(e^{j 2 pi k / nfft})

    const power = try allocator.alloc(f64, nbins);
    errdefer allocator.free(power);
    for (0..nbins) |k| {
        const mag2 = buf[k].re * buf[k].re + buf[k].im * buf[k].im;
        power[k] = model.variance / (o.fs * mag2);
    }
    if (o.onesided) psd.foldOneSided(power);

    const freqs = try psd.makeFreqs(allocator, nfft, nbins, o.fs);
    return Psd{ .allocator = allocator, .freqs = freqs, .power = power, .fs = o.fs };
}

/// One call: Yule-Walker fit + PSD.
pub fn yuleWalker(allocator: std.mem.Allocator, x: []const f64, order: usize, o: ArOptions) !Psd {
    var model = try yuleWalkerModel(allocator, x, order, o);
    defer model.deinit();
    return arPsd(allocator, model, o);
}

/// One call: Burg fit + PSD.
pub fn burg(allocator: std.mem.Allocator, x: []const f64, order: usize, o: ArOptions) !Psd {
    var model = try burgModel(allocator, x, order, o);
    defer model.deinit();
    return arPsd(allocator, model, o);
}
