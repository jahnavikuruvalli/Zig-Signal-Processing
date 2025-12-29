const std = @import("std");

//First-order Low-pass
pub fn lowPass(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    cutoff: f64,
) ![]f64 {
    var output = try allocator.alloc(f64, input.len);

    const alpha =
        (2.0 * std.math.pi * cutoff) /
        ((2.0 * std.math.pi * cutoff) + fs);

    output[0] = input[0];

    for (1..input.len) |i| {
        output[i] = output[i - 1] + alpha * (input[i] - output[i - 1]);
    }

    return output;
}

//First-order High-pass
pub fn highPass(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    cutoff: f64,
) ![]f64 {
    var output = try allocator.alloc(f64, input.len);

    const alpha = fs / (fs + 2.0 * std.math.pi * cutoff);

    output[0] = input[0];

    for (1..input.len) |i| {
        output[i] = alpha * (output[i - 1] + input[i] - input[i - 1]);
    }

    return output;
}

//First-order Bandpass (HP → LP)
pub fn firstOrderBandPass(
    allocator: std.mem.Allocator,
    input: []f64,
    fs: f64,
    low: f64,
    high: f64,
) ![]f64 {
    const hp = try highPass(allocator, input, fs, low);
    defer allocator.free(hp);

    return lowPass(allocator, hp, fs, high);
}
