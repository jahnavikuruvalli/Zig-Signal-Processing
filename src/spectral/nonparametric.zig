//! Classical (non-parametric) PSD estimators built on the FFT.
//!
//! All four are the same machine with different settings:
//!
//!   periodogram          1 segment = whole record, rectangular window
//!   modifiedPeriodogram  1 segment = whole record, any window
//!   bartlett             K non-overlapping segments, rectangular window
//!   welch                K (possibly overlapping) segments, any window
//!
//! For one segment of length L with window w and sample rate fs:
//!
//!   P[k] = |FFT(w .* x)[k]|^2 / (fs * sum(w^2))
//!
//! and the final estimate is the average of P over all K segments.
//! Zero-padding (nfft > L) interpolates the spectrum without changing the
//! normalisation. The caller owns the returned `Psd` and must `deinit()` it.

const std = @import("std");
const fft_mod = @import("../fft/fft.zig");
const window = @import("window.zig");
const psd = @import("psd.zig");

pub const Psd = psd.Psd;
pub const Options = psd.Options;
pub const Complex = psd.Complex;

/// Number of whole segments of `seg_len` that fit in `n` samples when
/// consecutive segments share `overlap` samples. Trailing samples that do
/// not fill a whole segment are ignored (same as scipy.signal.welch).
pub fn segmentCount(n: usize, seg_len: usize, overlap: usize) usize {
    if (seg_len == 0 or overlap >= seg_len or n < seg_len) return 0;
    return (n - seg_len) / (seg_len - overlap) + 1;
}

fn averaged(
    allocator: std.mem.Allocator,
    x: []const f64,
    seg_len: usize,
    overlap: usize,
    kind: window.Kind,
    o: Options,
) !Psd {
    try psd.validateFs(o.fs);
    if (seg_len < 2) return error.InvalidSegmentLength;
    if (overlap >= seg_len) return error.InvalidOverlap;
    if (x.len < seg_len) return error.InputTooShort;
    for (x) |v| if (!std.math.isFinite(v)) return error.NonFiniteInput;

    const nfft = try psd.resolveNfft(o.nfft, seg_len);
    const nbins = psd.binCount(nfft, o.onesided);

    const w = try window.generate(allocator, kind, seg_len, o.window_symmetry);
    defer allocator.free(w);
    const u = window.powerSum(w);

    const seg = try allocator.alloc(f64, seg_len);
    defer allocator.free(seg);
    const buf = try allocator.alloc(Complex, nfft);
    defer allocator.free(buf);

    const power = try allocator.alloc(f64, nbins);
    errdefer allocator.free(power);
    @memset(power, 0.0);

    const step = seg_len - overlap;
    var count: usize = 0;
    var start: usize = 0;
    while (start + seg_len <= x.len) : (start += step) {
        @memcpy(seg, x[start .. start + seg_len]);
        psd.detrendInPlace(seg, o.detrend);

        for (0..seg_len) |i| buf[i] = .{ .re = seg[i] * w[i], .im = 0.0 };
        @memset(buf[seg_len..], Complex{ .re = 0.0, .im = 0.0 });

        try fft_mod.fft(buf);

        for (0..nbins) |k| power[k] += buf[k].re * buf[k].re + buf[k].im * buf[k].im;
        count += 1;
    }

    const norm = 1.0 / (@as(f64, @floatFromInt(count)) * o.fs * u);
    for (power) |*p| p.* *= norm;
    if (o.onesided) psd.foldOneSided(power);

    const freqs = try psd.makeFreqs(allocator, nfft, nbins, o.fs);
    return Psd{ .allocator = allocator, .freqs = freqs, .power = power, .fs = o.fs };
}

/// Plain periodogram: |FFT(x)|^2 / (N * fs). Rectangular window, no averaging.
/// Simple, but the variance does not shrink as N grows.
pub fn periodogram(allocator: std.mem.Allocator, x: []const f64, o: Options) !Psd {
    if (x.len < 2) return error.InputTooShort;
    return averaged(allocator, x, x.len, 0, .rectangular, o);
}

/// Modified periodogram: the periodogram of `window .* x`, normalised by
/// the window power so the result stays an unbiased power density.
/// Trades a wider main lobe for much lower spectral leakage.
pub fn modifiedPeriodogram(
    allocator: std.mem.Allocator,
    x: []const f64,
    kind: window.Kind,
    o: Options,
) !Psd {
    if (x.len < 2) return error.InputTooShort;
    return averaged(allocator, x, x.len, 0, kind, o);
}

/// Bartlett's method: split x into non-overlapping segments of
/// `segment_len`, take the periodogram of each (rectangular window) and
/// average. Variance drops roughly by the number of segments K, at the
/// price of frequency resolution ~ fs / segment_len.
pub fn bartlett(
    allocator: std.mem.Allocator,
    x: []const f64,
    segment_len: usize,
    o: Options,
) !Psd {
    return averaged(allocator, x, segment_len, 0, .rectangular, o);
}

/// Welch's method: like Bartlett but segments may overlap and each is
/// windowed (modified periodogram). A typical choice is a Hann window with
/// 50 % overlap: `welch(a, x, 256, 128, .hann, .{ .fs = 1000 })`.
pub fn welch(
    allocator: std.mem.Allocator,
    x: []const f64,
    segment_len: usize,
    overlap: usize,
    kind: window.Kind,
    o: Options,
) !Psd {
    return averaged(allocator, x, segment_len, overlap, kind, o);
}
