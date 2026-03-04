const std = @import("std");

pub const SineOsc = struct {
    phase: f32 = 0.0,
    phase_inc: f32,

    pub fn init(freq: f32, fs: f32) SineOsc {
        return .{
            .phase_inc = 2.0 * std.math.pi * freq / fs,
        };
    }

    pub fn next(self: *SineOsc) f32 {
        const y = std.math.sin(self.phase);
        self.phase += self.phase_inc;

        // wrap phase (important in long runs)
        if (self.phase > 2.0 * std.math.pi)
            self.phase -= 2.0 * std.math.pi;

        return y;
    }
};
