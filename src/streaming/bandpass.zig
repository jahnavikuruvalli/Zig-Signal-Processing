const std = @import("std");
const Biquad = @import("biquad.zig").Biquad;

pub const BiquadCascade = struct {
    stages: []Biquad,

    pub fn init(stages: []Biquad) BiquadCascade {
        return .{ .stages = stages };
    }

    pub fn reset(self: *BiquadCascade) void {
        for (self.stages) |*s| {
            s.reset();
        }
    }

    pub fn process(self: *BiquadCascade, x: f32) f32 {
        var y = x;
        for (self.stages) |*s| {
            y = s.process(y);
        }
        return y;
    }
};
