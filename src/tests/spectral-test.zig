//! Tests for the PSD estimators. They check mathematical properties
//! (Parseval, known peak locations, variance reduction, exact AR recovery)
//! rather than just "it runs".

const std = @import("std");
const signal = @import("../signal.zig");
const sp = signal.spectral;
const gaussian = signal.signals.noise.gaussian;

const alloc = std.testing.allocator;

fn meanSquare(x: []const f64) f64 {
    var a: f64 = 0;
    for (x) |v| a += v * v;
    return a / @as(f64, @floatFromInt(x.len));
}

fn sineWave(n: usize, f: f64, fs: f64, amp: f64) ![]f64 {
    const x = try alloc.alloc(f64, n);
    for (x, 0..) |*v, i| v.* = amp * @sin(2.0 * std.math.pi * f * @as(f64, @floatFromInt(i)) / fs);
    return x;
}

/// Mean and standard deviation of psd.power over bins [lo, hi).
fn stats(p: sp.Psd, lo: usize, hi: usize) struct { mean: f64, std: f64 } {
    var m: f64 = 0;
    for (p.power[lo..hi]) |v| m += v;
    m /= @as(f64, @floatFromInt(hi - lo));
    var s: f64 = 0;
    for (p.power[lo..hi]) |v| s += (v - m) * (v - m);
    s /= @as(f64, @floatFromInt(hi - lo));
    return .{ .mean = m, .std = @sqrt(s) };
}

/// AR(2): x[n] = 1.5 x[n-1] - 0.75 x[n-2] + e[n]   (so a1 = -1.5, a2 = 0.75)
/// Poles at radius sqrt(0.75), angle 30 degrees  =>  spectral peak at 1/12 cycles/sample.
fn ar2Process(n: usize, seed: u64) ![]f64 {
    const burn = 500;
    const e = try gaussian(alloc, n + burn, 1.0, seed);
    defer alloc.free(e);
    const full = try alloc.alloc(f64, n + burn);
    defer alloc.free(full);
    full[0] = e[0];
    full[1] = e[1] + 1.5 * full[0];
    for (2..n + burn) |i| full[i] = 1.5 * full[i - 1] - 0.75 * full[i - 2] + e[i];
    return alloc.dupe(f64, full[burn..]);
}

// ================================================================ non-parametric

test "periodogram satisfies Parseval (two-sided and one-sided)" {
    const x = try gaussian(alloc, 256, 1.0, 1);
    defer alloc.free(x);

    var two = try sp.periodogram(alloc, x, .{ .fs = 1000.0, .onesided = false });
    defer two.deinit();
    try std.testing.expectEqual(@as(usize, 256), two.power.len);
    try std.testing.expectApproxEqRel(meanSquare(x), two.totalPower(), 1e-10);

    var one = try sp.periodogram(alloc, x, .{ .fs = 1000.0 });
    defer one.deinit();
    try std.testing.expectEqual(@as(usize, 129), one.power.len);
    try std.testing.expectApproxEqRel(meanSquare(x), one.totalPower(), 1e-10);
}

test "periodogram of a bin-centred sine: correct frequency and power A^2/2" {
    const fs = 1000.0;
    const x = try sineWave(1024, 125.0, fs, 2.0); // bin 128 exactly
    defer alloc.free(x);

    var p = try sp.periodogram(alloc, x, .{ .fs = fs });
    defer p.deinit();

    try std.testing.expectEqual(@as(usize, 128), p.peakIndex());
    try std.testing.expectApproxEqAbs(125.0, p.peakFrequency(), 1e-9);
    // power in the peak bin = A^2/2 = 2.0
    try std.testing.expectApproxEqAbs(2.0, p.power[128] * p.binWidth(), 1e-9);
}

test "modified periodogram (hann) leaks far less than the plain periodogram" {
    const fs = 1000.0;
    const x = try sineWave(1024, 130.3, fs, 1.0); // not bin-centred -> leakage
    defer alloc.free(x);

    var rect = try sp.periodogram(alloc, x, .{ .fs = fs });
    defer rect.deinit();
    var hann = try sp.modifiedPeriodogram(alloc, x, .hann, .{ .fs = fs });
    defer hann.deinit();

    try std.testing.expect(@abs(hann.peakFrequency() - 130.3) <= hann.binWidth());
    // far from the tone (~300 Hz) the windowed estimate is at least 100x lower
    const k = 307; // 300 Hz
    try std.testing.expect(hann.power[k] * 100.0 < rect.power[k]);
    // yet total power is still A^2/2 = 0.5 thanks to the window-power normalisation
    try std.testing.expectApproxEqRel(0.5, hann.totalPower(), 0.02);
}

test "segmentCount" {
    try std.testing.expectEqual(@as(usize, 10), sp.segmentCount(1000, 100, 0));
    try std.testing.expectEqual(@as(usize, 19), sp.segmentCount(1000, 100, 50));
    try std.testing.expectEqual(@as(usize, 9), sp.segmentCount(999, 100, 0)); // remainder dropped
    try std.testing.expectEqual(@as(usize, 1), sp.segmentCount(100, 100, 50));
    try std.testing.expectEqual(@as(usize, 0), sp.segmentCount(99, 100, 0));
}

test "white noise: Bartlett and Welch average out the variance, mean stays at 2*sigma^2/fs" {
    // sigma^2 = 1, fs = 1  ->  one-sided density = 2 everywhere (except DC/Nyquist)
    const n = 4096;
    const x = try gaussian(alloc, n, 1.0, 7);
    defer alloc.free(x);

    var per = try sp.periodogram(alloc, x, .{});
    defer per.deinit();
    var bar = try sp.bartlett(alloc, x, 512, .{});
    defer bar.deinit();
    var wel = try sp.welch(alloc, x, 512, 256, .hann, .{});
    defer wel.deinit();

    const per_s = stats(per, 2, per.power.len - 2);
    const bar_s = stats(bar, 2, bar.power.len - 2);
    const wel_s = stats(wel, 2, wel.power.len - 2);

    // all unbiased
    try std.testing.expectApproxEqAbs(2.0, per_s.mean, 0.15);
    try std.testing.expectApproxEqAbs(2.0, bar_s.mean, 0.15);
    try std.testing.expectApproxEqAbs(2.0, wel_s.mean, 0.15);
    // raw periodogram: std ~ mean (chi-square, 2 dof). Averaging 8 segments: ~ mean/sqrt(8).
    try std.testing.expect(per_s.std > 1.5);
    try std.testing.expect(bar_s.std < 1.0);
    try std.testing.expect(wel_s.std < 1.0);
    // Welch total power equals the variance
    try std.testing.expectApproxEqRel(1.0, wel.totalPower(), 0.1);
}

test "bartlett with one whole-record segment equals the periodogram" {
    const x = try gaussian(alloc, 512, 1.0, 3);
    defer alloc.free(x);
    var a = try sp.periodogram(alloc, x, .{ .fs = 50.0 });
    defer a.deinit();
    var b = try sp.bartlett(alloc, x, 512, .{ .fs = 50.0 });
    defer b.deinit();
    for (a.power, b.power) |u, v| try std.testing.expectEqual(u, v);
}

test "welch with rectangular window and no overlap equals bartlett" {
    const x = try gaussian(alloc, 1024, 1.0, 9);
    defer alloc.free(x);
    var a = try sp.bartlett(alloc, x, 128, .{});
    defer a.deinit();
    var b = try sp.welch(alloc, x, 128, 0, .rectangular, .{});
    defer b.deinit();
    for (a.power, b.power) |u, v| try std.testing.expectEqual(u, v);
}

test "welch finds two tones at the right frequencies" {
    const fs = 1000.0;
    const n = 4096;
    const x = try sineWave(n, 50.0, fs, 1.0);
    defer alloc.free(x);
    const y = try sineWave(n, 120.0, fs, 0.5);
    defer alloc.free(y);
    const noise = try gaussian(alloc, n, 0.2, 11);
    defer alloc.free(noise);
    for (x, y, noise) |*a, b, c| a.* += b + c;

    var w = try sp.welch(alloc, x, 1024, 512, .hann, .{ .fs = fs });
    defer w.deinit();

    // strongest bin is 50 Hz; the 120 Hz tone (quarter the power) is a local max too
    try std.testing.expect(@abs(w.peakFrequency() - 50.0) <= w.binWidth());
    const k120: usize = @intFromFloat(@round(120.0 / w.binWidth()));
    try std.testing.expect(w.power[k120] > w.power[k120 - 8] * 20.0);
    try std.testing.expect(w.power[k120] > w.power[k120 + 8] * 20.0);
}

test "zero-padding via nfft refines the frequency grid but keeps the power" {
    const x = try gaussian(alloc, 256, 1.0, 5);
    defer alloc.free(x);
    var a = try sp.welch(alloc, x, 128, 64, .hann, .{ .fs = 100.0 });
    defer a.deinit();
    var b = try sp.welch(alloc, x, 128, 64, .hann, .{ .fs = 100.0, .nfft = 1024 });
    defer b.deinit();
    try std.testing.expectEqual(@as(usize, 65), a.power.len);
    try std.testing.expectEqual(@as(usize, 513), b.power.len);
    try std.testing.expectApproxEqAbs(100.0 / 1024.0, b.binWidth(), 1e-12);
    try std.testing.expectApproxEqRel(a.totalPower(), b.totalPower(), 1e-9);
    try std.testing.expectApproxEqAbs(50.0, b.freqs[b.freqs.len - 1], 1e-9);
}

test "detrend option removes a DC offset from the estimate" {
    const x = try gaussian(alloc, 1024, 1.0, 13);
    defer alloc.free(x);
    for (x) |*v| v.* += 100.0;
    var raw = try sp.periodogram(alloc, x, .{});
    defer raw.deinit();
    var dt = try sp.periodogram(alloc, x, .{ .detrend = .constant });
    defer dt.deinit();
    try std.testing.expect(raw.power[0] > 1000.0);
    try std.testing.expect(dt.power[0] < 20.0);
    try std.testing.expectApproxEqRel(1.0, dt.totalPower(), 0.1);
}

test "non-parametric estimators validate their inputs" {
    const x = try gaussian(alloc, 100, 1.0, 2);
    defer alloc.free(x);
    const e = std.testing.expectError;
    try e(error.InvalidSampleRate, sp.periodogram(alloc, x, .{ .fs = 0.0 }));
    try e(error.InvalidSampleRate, sp.periodogram(alloc, x, .{ .fs = -5.0 }));
    try e(error.InvalidFftLength, sp.periodogram(alloc, x, .{ .nfft = 100 })); // not power of two
    try e(error.InvalidFftLength, sp.periodogram(alloc, x, .{ .nfft = 64 })); // shorter than data
    try e(error.InvalidSegmentLength, sp.welch(alloc, x, 1, 0, .hann, .{}));
    try e(error.InvalidOverlap, sp.welch(alloc, x, 32, 32, .hann, .{}));
    try e(error.InputTooShort, sp.welch(alloc, x, 200, 0, .hann, .{}));
    const tiny = [_]f64{1.0};
    try e(error.InputTooShort, sp.periodogram(alloc, &tiny, .{}));
    var bad = [_]f64{ 1.0, std.math.nan(f64), 2.0, 3.0 };
    try e(error.NonFiniteInput, sp.periodogram(alloc, &bad, .{}));
}

// ================================================================ parametric

test "autocorrelation estimators" {
    const x = [_]f64{ 1, 2, 3, 4 };
    const rb = try sp.autocorrelation(alloc, &x, 2, .biased);
    defer alloc.free(rb);
    try std.testing.expectApproxEqAbs(30.0 / 4.0, rb[0], 1e-12);
    try std.testing.expectApproxEqAbs(20.0 / 4.0, rb[1], 1e-12);
    try std.testing.expectApproxEqAbs(11.0 / 4.0, rb[2], 1e-12);
    const ru = try sp.autocorrelation(alloc, &x, 2, .unbiased);
    defer alloc.free(ru);
    try std.testing.expectApproxEqAbs(30.0 / 4.0, ru[0], 1e-12);
    try std.testing.expectApproxEqAbs(20.0 / 3.0, ru[1], 1e-12);
    try std.testing.expectApproxEqAbs(11.0 / 2.0, ru[2], 1e-12);
}

test "levinson-durbin recovers an exact AR(1) model" {
    // x[n] = 0.9 x[n-1] + e[n], sigma^2 = 1  =>  r[k] = 0.9^k / (1 - 0.81)
    var r: [5]f64 = undefined;
    for (&r, 0..) |*v, k| v.* = std.math.pow(f64, 0.9, @floatFromInt(k)) / (1.0 - 0.81);
    var m = try sp.levinsonDurbin(alloc, &r);
    defer m.deinit();
    try std.testing.expectEqual(@as(usize, 4), m.order());
    try std.testing.expectApproxEqAbs(-0.9, m.coeffs[0], 1e-12);
    for (m.coeffs[1..]) |c| try std.testing.expectApproxEqAbs(0.0, c, 1e-12);
    try std.testing.expectApproxEqAbs(-0.9, m.reflection[0], 1e-12);
    try std.testing.expectApproxEqAbs(1.0, m.variance, 1e-12);

    // AR(1) PSD integrates to r[0] = 1/0.19
    var p = try sp.arPsd(alloc, m, .{ .nfft = 4096 });
    defer p.deinit();
    try std.testing.expectApproxEqRel(r[0], p.totalPower(), 0.01);
    // low-pass shape: the maximum is at DC (checked on the two-sided spectrum,
    // because the one-sided convention does not double the DC bin)
    var two = try sp.arPsd(alloc, m, .{ .nfft = 4096, .onesided = false });
    defer two.deinit();
    try std.testing.expectEqual(@as(usize, 0), two.peakIndex());
}

test "levinson-durbin on a known AR(2) autocorrelation" {
    // a1 = -1.5, a2 = 0.75, sigma^2 = 1.
    // Yule-Walker: r1 = 1.5 r0 - 0.75 r1  ->  r1 = 1.5/1.75 r0 ;  r2 = 1.5 r1 - 0.75 r0
    // r0 = sigma^2 / (1 + a1 r1/r0 + a2 r2/r0) with those ratios.
    const rho1 = 1.5 / 1.75;
    const rho2 = 1.5 * rho1 - 0.75;
    const r0 = 1.0 / (1.0 - 1.5 * rho1 + 0.75 * rho2); // r0 = s2 / (1 + a1 rho1 + a2 rho2)
    const r = [_]f64{ r0, rho1 * r0, rho2 * r0 };
    var m = try sp.levinsonDurbin(alloc, &r);
    defer m.deinit();
    try std.testing.expectApproxEqAbs(-1.5, m.coeffs[0], 1e-9);
    try std.testing.expectApproxEqAbs(0.75, m.coeffs[1], 1e-9);
    try std.testing.expectApproxEqAbs(1.0, m.variance, 1e-9);
}

test "yule-walker and burg recover AR(2) coefficients and noise variance" {
    const x = try ar2Process(8192, 21);
    defer alloc.free(x);

    var yw = try sp.yuleWalkerModel(alloc, x, 2, .{});
    defer yw.deinit();
    try std.testing.expectApproxEqAbs(-1.5, yw.coeffs[0], 0.05);
    try std.testing.expectApproxEqAbs(0.75, yw.coeffs[1], 0.05);
    try std.testing.expectApproxEqAbs(1.0, yw.variance, 0.1);

    var bg = try sp.burgModel(alloc, x, 2, .{});
    defer bg.deinit();
    try std.testing.expectApproxEqAbs(-1.5, bg.coeffs[0], 0.05);
    try std.testing.expectApproxEqAbs(0.75, bg.coeffs[1], 0.05);
    try std.testing.expectApproxEqAbs(1.0, bg.variance, 0.1);

    // both models are stable
    for (yw.reflection) |k| try std.testing.expect(@abs(k) < 1.0);
    for (bg.reflection) |k| try std.testing.expect(@abs(k) < 1.0);
}

test "AR spectra of the AR(2) process peak at 1/12 cycles per sample" {
    const x = try ar2Process(8192, 22);
    defer alloc.free(x);

    var yw = try sp.yuleWalker(alloc, x, 2, .{ .nfft = 2048 });
    defer yw.deinit();
    var bg = try sp.burg(alloc, x, 2, .{ .nfft = 2048 });
    defer bg.deinit();
    try std.testing.expectApproxEqAbs(1.0 / 12.0, yw.peakFrequency(), 0.005);
    try std.testing.expectApproxEqAbs(1.0 / 12.0, bg.peakFrequency(), 0.005);

    // and they agree with a long Welch estimate of the same data
    var wl = try sp.welch(alloc, x, 1024, 512, .hann, .{ .nfft = 2048 });
    defer wl.deinit();
    try std.testing.expectApproxEqAbs(1.0 / 12.0, wl.peakFrequency(), 0.005);
    try std.testing.expectApproxEqRel(wl.totalPower(), bg.totalPower(), 0.15);
}

test "burg resolves a sinusoid in noise on a short record" {
    const fs = 1000.0;
    const x = try sineWave(256, 100.0, fs, 1.0);
    defer alloc.free(x);
    const noise = try gaussian(alloc, 256, 0.3, 31);
    defer alloc.free(noise);
    for (x, noise) |*a, b| a.* += b;

    var bg = try sp.burg(alloc, x, 8, .{ .fs = fs, .nfft = 4096 });
    defer bg.deinit();
    var yw = try sp.yuleWalker(alloc, x, 8, .{ .fs = fs, .nfft = 4096 });
    defer yw.deinit();
    try std.testing.expectApproxEqAbs(100.0, bg.peakFrequency(), 2.0);
    try std.testing.expectApproxEqAbs(100.0, yw.peakFrequency(), 5.0);
}

test "unbiased autocorrelation option is accepted" {
    const x = try ar2Process(4096, 23);
    defer alloc.free(x);
    var m = try sp.yuleWalkerModel(alloc, x, 2, .{ .autocorrelation = .unbiased });
    defer m.deinit();
    try std.testing.expectApproxEqAbs(-1.5, m.coeffs[0], 0.06);
}

test "AR estimators handle DC offsets via the default mean removal" {
    const x = try ar2Process(4096, 24);
    defer alloc.free(x);
    for (x) |*v| v.* += 50.0;
    var m = try sp.burgModel(alloc, x, 2, .{});
    defer m.deinit();
    try std.testing.expectApproxEqAbs(-1.5, m.coeffs[0], 0.06);
}

test "AR estimators validate their inputs" {
    const x = try gaussian(alloc, 64, 1.0, 4);
    defer alloc.free(x);
    const e = std.testing.expectError;
    try e(error.InvalidOrder, sp.yuleWalkerModel(alloc, x, 0, .{}));
    try e(error.InvalidOrder, sp.burgModel(alloc, x, 0, .{}));
    try e(error.InvalidOrder, sp.yuleWalkerModel(alloc, x, 64, .{}));
    try e(error.InvalidOrder, sp.burgModel(alloc, x, 64, .{}));

    var flat = [_]f64{ 3, 3, 3, 3, 3, 3, 3, 3 };
    try e(error.ZeroVariance, sp.yuleWalkerModel(alloc, &flat, 2, .{}));
    try e(error.ZeroVariance, sp.burgModel(alloc, &flat, 2, .{}));

    try e(error.InvalidSampleRate, sp.yuleWalker(alloc, x, 4, .{ .fs = 0.0 }));
    try e(error.InvalidFftLength, sp.burg(alloc, x, 4, .{ .nfft = 1000 }));
    try e(error.InvalidFftLength, sp.burg(alloc, x, 8, .{ .nfft = 8 })); // nfft must exceed order

    var bad = [_]f64{ 1.0, 2.0, std.math.inf(f64), 4.0, 5.0 };
    try e(error.NonFiniteInput, sp.burgModel(alloc, &bad, 2, .{}));
}

test "one-sided and two-sided AR spectra carry the same total power" {
    const x = try ar2Process(2048, 25);
    defer alloc.free(x);
    var a = try sp.burg(alloc, x, 4, .{ .fs = 8.0 });
    defer a.deinit();
    var b = try sp.burg(alloc, x, 4, .{ .fs = 8.0, .onesided = false });
    defer b.deinit();
    try std.testing.expectEqual(@as(usize, 513), a.power.len);
    try std.testing.expectEqual(@as(usize, 1024), b.power.len);
    try std.testing.expectApproxEqRel(a.totalPower(), b.totalPower(), 1e-9);
}
