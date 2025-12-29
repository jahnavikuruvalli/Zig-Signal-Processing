const std = @import("std");

fn iirFilter(
    allocator: std.mem.Allocator,
    input: []f64,
    b: [3]f64,
    a: [3]f64,
) ![]f64 {
    var y = try allocator.alloc(f64, input.len);
    std.mem.set(f64, y, 0.0);

    for (0..input.len) |n| {
        y[n] += b[0] * input[n];

        if (n >= 1) {
            y[n] += b[1] * input[n - 1];
            y[n] -= a[1] * y[n - 1];
        }
        if (n >= 2) {
            y[n] += b[2] * input[n - 2];
            y[n] -= a[2] * y[n - 2];
        }
    }

    return y;
}
