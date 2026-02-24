const std = @import("std");
const MovingAverage = @import("moving-average.zig").MovingAverage;

test "moving average smooths signal" {
    var buf: [4]f32 = undefined;
    var ma = MovingAverage.init(&buf);

    _ = ma.process(0);
    _ = ma.process(0);
    _ = ma.process(0);
    const y = ma.process(4);

    // average of [0,0,0,4] = 1
    try std.testing.expectApproxEqAbs(1.0, y, 0.0001);
}

test "constant input remains constant" {
    var buf: [5]f32 = undefined;
    var ma = MovingAverage.init(&buf);

    var y: f32 = 0;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        y = ma.process(2.0);
    }

    try std.testing.expectApproxEqAbs(2.0, y, 0.0001);
}
