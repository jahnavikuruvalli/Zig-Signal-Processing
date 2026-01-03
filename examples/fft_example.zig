const std = @import("std");
const signal = @import("zig-signal");
const fft = signal.fft;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // FIXED: Changed 'var' to 'const'.
    // You can still modify the numbers inside the array.
    const data = try allocator.alloc(f64, 8);
    defer allocator.free(data);

    for (data, 0..) |*v, i| {
        v.* = @floatFromInt(i);
    }

    try fft.fftInPlace(allocator, data);

    for (data) |v| {
        std.debug.print("{d}\n", .{v});
    }
}
