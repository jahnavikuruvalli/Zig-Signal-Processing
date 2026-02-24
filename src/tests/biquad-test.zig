const std = @import("std");
const Biquad = @import("../core/biquad.zig").Biquad;

test "biquad zero input produces zero output" {
    var filter = Biquad.init(
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
    );

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const y = filter.process(0.0);
        try std.testing.expect(y == 0.0);
    }
}
