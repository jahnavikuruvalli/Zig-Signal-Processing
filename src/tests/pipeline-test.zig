const std = @import("std");
const Pipeline = @import("../core/pipeline.zig").Pipeline;
const Stage = @import("../core/pipeline.zig").Stage;

// simple gain block
const Gain = struct {
    g: f32,
    pub fn process(self: *Gain, x: f32) f32 {
        return self.g * x;
    }
};

fn gainAdapter(ctx: *anyopaque, x: f32) f32 {
    const g: *Gain = @ptrCast(@alignCast(ctx));
    return g.process(x);
}

test "pipeline chains stages" {
    var g1 = Gain{ .g = 2.0 };
    var g2 = Gain{ .g = 0.5 };

    var stages = [_]Stage{
        .{ .ctx = &g1, .func = gainAdapter },
        .{ .ctx = &g2, .func = gainAdapter },
    };

    var pipe = Pipeline.init(&stages);

    const y = pipe.process(4.0);

    // 4 * 2 * 0.5 = 4
    try std.testing.expect(y == 4.0);
}
