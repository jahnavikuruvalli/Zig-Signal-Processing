const std = @import("std");
const design = @import("../design/onepole.zig");
const Biquad = @import("../core/biquad.zig").Biquad;

test "designed filter actually filters" {
    const coeff = design.lowpass(100.0, 5.0);
    var filter = Biquad.fromOnePole(coeff);

    var y: f32 = 0;

    // step input
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        y = filter.process(1.0);
    }

    // low-pass should converge near 1 but not instantly
    try std.testing.expect(y > 0.5 and y < 1.1);
}
