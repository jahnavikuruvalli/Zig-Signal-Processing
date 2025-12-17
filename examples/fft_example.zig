const std = @import("std");
const fft = @import("fft");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const signal = try allocator.alloc(std.math.Complex(f64), 8);
    defer allocator.free(signal);

    for (signal, 0..) |*v, i| {
        v.* = .{ .re = @floatFromInt(i), .im = 0.0 };
    }

    fft.fft(signal);

    for (signal) |v| {
        std.debug.print("{d:.3} + {d:.3}i\n", .{ v.re, v.im });
    }
}
