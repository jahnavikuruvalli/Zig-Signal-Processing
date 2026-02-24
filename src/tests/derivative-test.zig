const std = @import("std");
const Derivative = @import("../core/derivative.zig").Derivative;

test "derivative detects change" {
    var d = Derivative{};

    _ = d.process(1.0); // first sample ignored
    const y = d.process(3.5);

    try std.testing.expect(y == 2.5);
}

test "constant signal has zero slope" {
    var d = Derivative{};

    _ = d.process(2.0);

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        try std.testing.expect(d.process(2.0) == 0.0);
    }
}
