const std = @import("std");
const Complex = std.math.Complex(f64);

/// Internal recursive FFT implementation.
/// This function operates in-place on a complex-valued buffer.
fn fftRecursive(allocator: std.mem.Allocator, signal: []Complex) !void {
    const n = signal.len;
    if (n <= 1) return;

    const even = try allocator.alloc(Complex, n / 2);
    const odd = try allocator.alloc(Complex, n / 2);
    defer allocator.free(even);
    defer allocator.free(odd);

    for (0..n / 2) |i| {
        even[i] = signal[i * 2];
        odd[i] = signal[i * 2 + 1];
    }

    try fftRecursive(allocator, even);
    try fftRecursive(allocator, odd);

    for (0..n / 2) |k| {
        const angle =
            -2.0 * std.math.pi *
            @as(f64, @floatFromInt(k)) /
            @as(f64, @floatFromInt(n));

        const twiddle = Complex{
            .re = std.math.cos(angle),
            .im = std.math.sin(angle),
        };

        const t = twiddle.mul(odd[k]);

        signal[k] = even[k].add(t);
        signal[k + n / 2] = even[k].sub(t);
    }
}

/// In-place FFT magnitude computation for real-valued input.
///
/// - Input: real-valued time-domain signal
/// - Output: magnitude spectrum (written back into `data`)
///
/// Notes:
/// - Length of `data` should be a power of two
/// - Allocates temporary buffers using the provided allocator
pub fn fftInPlace(allocator: std.mem.Allocator, data: []f64) !void {
    const n = data.len;

    const complex_buffer = try allocator.alloc(Complex, n);
    defer allocator.free(complex_buffer);

    for (data, 0..) |val, i| {
        complex_buffer[i] = Complex{ .re = val, .im = 0 };
    }

    try fftRecursive(allocator, complex_buffer);

    for (complex_buffer, 0..) |c, i| {
        data[i] = std.math.hypot(c.re, c.im);
    }
}

test "FFT impulse response produces flat spectrum" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var data = try allocator.alloc(f64, 4);
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = try allocator.alloc(f64, 8);
    defer allocator.free(data);

    @memset(data, 0.0);

    try fftInPlace(allocator, data);

    for (data) |v| {
        try std.testing.expectApproxEqAbs(0.0, v, 1e-12);
    }
}

test "FFT magnitude is symmetric for real input" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
