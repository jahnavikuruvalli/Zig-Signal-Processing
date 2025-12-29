const std = @import("std");

//2nd-order Butterworth Bandpass

pub fn butterworthBandpass(
    fs: f64,
    low: f64,
    high: f64,
) struct { b: [3]f64, a: [3]f64 } {
    const w1 = std.math.tan(std.math.pi * low / fs);
    const w2 = std.math.tan(std.math.pi * high / fs);

    const bw = w2 - w1;
    const w0 = std.math.sqrt(w1 * w2);

    const norm = 1.0 / (1.0 + bw + w0 * w0);

    const b0 = bw * norm;
    const b1 = 0.0;
    const b2 = -bw * norm;

    const a0 = 1.0;
    const a1 = 2.0 * (w0 * w0 - 1.0) * norm;
    const a2 = (1.0 - bw + w0 * w0) * norm;

    return .{
        .b = .{ b0, b1, b2 },
        .a = .{ a0, a1, a2 },
    };
}
