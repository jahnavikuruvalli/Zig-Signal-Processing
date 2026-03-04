const std = @import("std");
const design = @import("../design/onepole.zig");

test "lowpass coefficients stable" {
    const c = design.lowpass(100.0, 5.0);

    // stability condition |a1| < 1
    try std.testing.expect(@abs(c.a1) < 1.0);
}
