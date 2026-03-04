const std = @import("std");
const signal = @import("../signal.zig");

test "public API lowpass works" {
    var lp = signal.lowpass(100.0, 5.0);

    var y: f32 = 0;
    var i: usize = 0;
    while (i < 40) : (i += 1) {
        y = lp.process(1.0);
    }

    try std.testing.expect(y > 0.5 and y < 1.1);
}
