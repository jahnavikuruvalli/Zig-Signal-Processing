const std = @import("std");

fn fft(signal: []std.math.Complex(f64)) void {
    const n = signal.len;
    if (n <= 1) return;

    var even = std.heap.page_allocator.alloc(std.math.Complex(f64), n / 2) catch unreachable;
    var odd  = std.heap.page_allocator.alloc(std.math.Complex(f64), n / 2) catch unreachable;

    defer std.heap.page_allocator.free(even);
    defer std.heap.page_allocator.free(odd);

    for (0..n / 2) |i| {
        even[i] = signal[i * 2];
        odd[i]  = signal[i * 2 + 1];
    }

    fft(even);
    fft(odd);

    for (0..n / 2) |k| {
        const angle = -2.0 * std.math.pi * @as(f64, @floatFromInt(k)) / @as(f64, @floatFromInt(n));
        const twiddle = std.math.Complex(f64){
            .re = std.math.cos(angle),
            .im = std.math.sin(angle),
        };
        const t = twiddle.mul(odd[k]);

        signal[k] = even[k].add(t);
        signal[k + n / 2] = even[k].sub(t);
    }
}

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const signal = try allocator.alloc(std.math.Complex(f64), 8);
    defer allocator.free(signal);

    for (signal, 0..) |*v, i| {
        v.* = .{ .re = @floatFromInt(i), .im = 0.0 };
    }

    fft(signal);

    for (signal) |v| {
        std.debug.print("{d:.3} + {d:.3}i\n", .{ v.re, v.im });
    }
}

test "fft compiles and runs on simple input" {
    var allocator = std.heap.page_allocator;

    var signal = try allocator.alloc(std.math.Complex(f64), 8);
    defer allocator.free(signal);

    for (signal, 0..) |*v, i| {
        v.* = .{ .re = @floatFromInt(i), .im = 0.0 };
    }

    fft(signal);
}
