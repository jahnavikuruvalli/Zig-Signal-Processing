const std = @import("std");
const Biquad = @import("../core/biquad.zig").Biquad;
const Cascade = @import("../core/bandpass.zig").BiquadCascade;

test "cascade passes zero input" {
    var stages = [_]Biquad{
        Biquad.init(1, 0, 0, 0, 0),
        Biquad.init(1, 0, 0, 0, 0),
    };

    var filter = Cascade.init(&stages);

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        try std.testing.expect(filter.process(0.0) == 0.0);
    }
}
