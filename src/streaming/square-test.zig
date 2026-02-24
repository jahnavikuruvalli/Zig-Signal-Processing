const std = @import("std");
const Squaring = @import("square.zig").Squaring;

test "square produces positive energy" {
    var s = Squaring{};

    try std.testing.expect(s.process(-3.0) == 9.0);
    try std.testing.expect(s.process(2.0) == 4.0);
}
