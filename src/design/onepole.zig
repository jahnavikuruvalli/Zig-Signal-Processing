const std = @import("std");

pub const OnePole = struct {
    b0: f32,
    b1: f32,
    a1: f32,
};

// RC low-pass using bilinear transform
pub fn lowpass(fs: f32, cutoff: f32) OnePole {
    const T = 1.0 / fs;
    const wc = 2.0 * std.math.pi * cutoff;

    // bilinear transform substitution
    const k = wc * T / 2.0;
    const norm = 1.0 / (1.0 + k);

    return .{
        .b0 = k * norm,
        .b1 = k * norm,
        .a1 = (k - 1.0) * norm,
    };
}
