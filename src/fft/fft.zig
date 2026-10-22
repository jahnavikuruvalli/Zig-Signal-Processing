const std = @import("std");

/// Complex sample type used by the FFT and the spectral estimators.
pub const Complex = std.math.Complex(f64);

pub fn isPowerOfTwo(n: usize) bool {
    return n != 0 and (n & (n - 1)) == 0;
}

/// Smallest power of two >= n (1 for n <= 1).
pub fn nextPowerOfTwo(n: usize) usize {
    if (n <= 1) return 1;
    return std.math.ceilPowerOfTwo(usize, n) catch unreachable;
}

/// In-place iterative radix-2 FFT: X[k] = sum_n x[n] e^{-j 2 pi k n / N}.
///
/// `buf.len` must be a power of two (a length of 1 is allowed), otherwise
/// `error.LengthNotPowerOfTwo` is returned. Does not allocate.
pub fn fft(buf: []Complex) !void {
    try transform(buf, -1.0);
}

/// In-place inverse FFT (includes the 1/N scaling).
pub fn ifft(buf: []Complex) !void {
    try transform(buf, 1.0);
    const inv = 1.0 / @as(f64, @floatFromInt(buf.len));
    for (buf) |*c| {
        c.re *= inv;
        c.im *= inv;
    }
}

fn transform(buf: []Complex, sign: f64) !void {
    const n = buf.len;
    if (!isPowerOfTwo(n)) return error.LengthNotPowerOfTwo;
    if (n == 1) return;

    // bit-reversal permutation
    var j: usize = 0;
    for (1..n) |i| {
        var bit = n >> 1;
        while (j & bit != 0) : (bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std.mem.swap(Complex, &buf[i], &buf[j]);
    }

    // butterflies; each twiddle factor is computed directly (not by
    // repeated multiplication) so rounding error does not accumulate
    var len: usize = 2;
    while (len <= n) : (len <<= 1) {
        const half = len / 2;
        for (0..half) |k| {
            const ang = sign * 2.0 * std.math.pi *
                @as(f64, @floatFromInt(k)) / @as(f64, @floatFromInt(len));
            const wr = @cos(ang);
            const wi = @sin(ang);
            var start: usize = 0;
            while (start < n) : (start += len) {
                const u = buf[start + k];
                const v = buf[start + k + half];
                const tr = v.re * wr - v.im * wi;
                const ti = v.re * wi + v.im * wr;
                buf[start + k] = .{ .re = u.re + tr, .im = u.im + ti };
                buf[start + k + half] = .{ .re = u.re - tr, .im = u.im - ti };
            }
        }
    }
}

/// FFT magnitude of a real-valued signal, written back into `data`.
///
/// - Length of `data` must be a power of two, otherwise
///   `error.LengthNotPowerOfTwo` is returned
/// - Allocates one temporary complex buffer
/// - For power spectra use the estimators in `signal.spectral` instead
pub fn fftInPlace(allocator: std.mem.Allocator, data: []f64) !void {
    const n = data.len;
    if (n == 0) return;
    if (!isPowerOfTwo(n)) return error.LengthNotPowerOfTwo;

    const buf = try allocator.alloc(Complex, n);
    defer allocator.free(buf);

    for (data, 0..) |val, i| buf[i] = .{ .re = val, .im = 0.0 };
    try fft(buf);
    for (buf, 0..) |c, i| data[i] = std.math.hypot(c.re, c.im);
}

test "FFT impulse response produces flat spectrum" {
    const allocator = std.testing.allocator;

    const data = try allocator.alloc(f64, 4);
    defer allocator.free(data);

    // Impulse signal
    data[0] = 1.0;
    data[1] = 0.0;
    data[2] = 0.0;
    data[3] = 0.0;

    try fftInPlace(allocator, data);

    // FFT magnitude of impulse should be flat
    for (data) |v| {
        try std.testing.expectApproxEqAbs(1.0, v, 1e-6);
    }
}

test "FFT of zero signal is zero" {
    const allocator = std.testing.allocator;

    const data = try allocator.alloc(f64, 8);
    defer allocator.free(data);

    @memset(data, 0.0);

    try fftInPlace(allocator, data);

    for (data) |v| {
        try std.testing.expectApproxEqAbs(0.0, v, 1e-12);
    }
}

test "FFT magnitude is symmetric for real input" {
    const allocator = std.testing.allocator;

    const N = 8;
    const data = try allocator.alloc(f64, N);

    defer allocator.free(data);

    // Simple real signal
    for (data, 0..) |*v, i| {
        v.* = @floatFromInt(i);
    }

    try fftInPlace(allocator, data);

    for (1..N / 2) |k| {
        try std.testing.expectApproxEqAbs(
            data[k],
            data[N - k],
            1e-6,
        );
    }
}

test "FFT rejects non power-of-two lengths" {
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(f64, 6);
    defer allocator.free(data);
    @memset(data, 1.0);
    try std.testing.expectError(error.LengthNotPowerOfTwo, fftInPlace(allocator, data));
}

test "FFT of a pure tone peaks in the right bin" {
    const allocator = std.testing.allocator;
    const N = 64;
    const k0 = 5; // 5 cycles over the window
    const data = try allocator.alloc(f64, N);
    defer allocator.free(data);
    for (data, 0..) |*v, i| {
        v.* = std.math.sin(2.0 * std.math.pi * k0 * @as(f64, @floatFromInt(i)) / N);
    }
    try fftInPlace(allocator, data);
    // magnitude N/2 at bin k0, ~0 elsewhere in the lower half
    try std.testing.expectApproxEqAbs(@as(f64, N) / 2.0, data[k0], 1e-9);
    for (0..N / 2) |k| {
        if (k != k0) try std.testing.expectApproxEqAbs(0.0, data[k], 1e-9);
    }
}

test "fft matches a direct O(N^2) DFT on random-looking data" {
    const allocator = std.testing.allocator;
    const N = 32;
    var prng = std.Random.DefaultPrng.init(7);
    const rand = prng.random();

    const x = try allocator.alloc(Complex, N);
    defer allocator.free(x);
    const y = try allocator.alloc(Complex, N);
    defer allocator.free(y);
    for (x, y) |*a, *b| {
        a.* = .{ .re = rand.float(f64) - 0.5, .im = rand.float(f64) - 0.5 };
        b.* = a.*;
    }
    try fft(y);

    for (0..N) |k| {
        var re: f64 = 0.0;
        var im: f64 = 0.0;
        for (0..N) |n| {
            const ang = -2.0 * std.math.pi * @as(f64, @floatFromInt(k * n % N)) / N;
            re += x[n].re * @cos(ang) - x[n].im * @sin(ang);
            im += x[n].re * @sin(ang) + x[n].im * @cos(ang);
        }
        try std.testing.expectApproxEqAbs(re, y[k].re, 1e-12);
        try std.testing.expectApproxEqAbs(im, y[k].im, 1e-12);
    }
}

test "ifft(fft(x)) returns x" {
    const allocator = std.testing.allocator;
    const N = 64;
    const x = try allocator.alloc(Complex, N);
    defer allocator.free(x);
    const orig = try allocator.alloc(Complex, N);
    defer allocator.free(orig);
    for (x, orig, 0..) |*a, *b, i| {
        const t: f64 = @floatFromInt(i);
        a.* = .{ .re = @sin(0.3 * t) + 0.1 * t, .im = @cos(0.7 * t) };
        b.* = a.*;
    }
    try fft(x);
    try ifft(x);
    for (x, orig) |a, b| {
        try std.testing.expectApproxEqAbs(b.re, a.re, 1e-12);
        try std.testing.expectApproxEqAbs(b.im, a.im, 1e-12);
    }
}

test "fft rejects bad lengths, accepts length 1, helpers" {
    var empty: [0]Complex = .{};
    try std.testing.expectError(error.LengthNotPowerOfTwo, fft(&empty));
    var six: [6]Complex = undefined;
    try std.testing.expectError(error.LengthNotPowerOfTwo, fft(&six));
    var one = [_]Complex{.{ .re = 3.0, .im = -1.0 }};
    try fft(&one);
    try std.testing.expectEqual(@as(f64, 3.0), one[0].re);

    try std.testing.expect(isPowerOfTwo(1) and isPowerOfTwo(1024));
    try std.testing.expect(!isPowerOfTwo(0) and !isPowerOfTwo(12));
    try std.testing.expectEqual(@as(usize, 1), nextPowerOfTwo(0));
    try std.testing.expectEqual(@as(usize, 128), nextPowerOfTwo(100));
    try std.testing.expectEqual(@as(usize, 128), nextPowerOfTwo(128));
}

test "Parseval: sum |x|^2 == (1/N) sum |X|^2" {
    const allocator = std.testing.allocator;
    const N = 128;
    const x = try allocator.alloc(Complex, N);
    defer allocator.free(x);
    var e_time: f64 = 0.0;
    for (x, 0..) |*a, i| {
        const t: f64 = @floatFromInt(i);
        a.* = .{ .re = @sin(0.21 * t) * @cos(0.05 * t), .im = 0.0 };
        e_time += a.re * a.re;
    }
    try fft(x);
    var e_freq: f64 = 0.0;
    for (x) |a| e_freq += a.re * a.re + a.im * a.im;
    try std.testing.expectApproxEqAbs(e_time, e_freq / N, 1e-10);
}
