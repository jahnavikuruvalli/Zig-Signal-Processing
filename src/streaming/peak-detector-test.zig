const std = @import("std");
const PD = @import("peak-detector.zig").PeakDetector;

test "detect simple peaks" {
    var pd = PD.init(5);

    const signal = [_]f32{ 0, 0, 1, 3, 5, 3, 1, 0, 0, 0, 2, 6, 2, 0 };

    var count: usize = 0;

    for (signal) |x| {
        const e = pd.process(x);
        if (e.detected) count += 1;
    }

    try std.testing.expect(count == 2);
}
