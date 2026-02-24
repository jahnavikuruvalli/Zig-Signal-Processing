const std = @import("std");

pub const Biquad = struct {
    // Coefficients
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,

    // Internal state
    z1: f32 = 0.0,
    z2: f32 = 0.0,

    pub fn init(
        b0: f32,
        b1: f32,
        b2: f32,
        a1: f32,
        a2: f32,
    ) Biquad {
        return Biquad{
            .b0 = b0,
            .b1 = b1,
            .b2 = b2,
            .a1 = a1,
            .a2 = a2,
        };
    }

    pub fn reset(self: *Biquad) void {
        self.z1 = 0.0;
        self.z2 = 0.0;
    }

    pub fn process(self: *Biquad, x: f32) f32 {
        const y = self.b0 * x + self.z1;

        self.z1 = self.b1 * x - self.a1 * y + self.z2;
        self.z2 = self.b2 * x - self.a2 * y;

        return y;
    }
};
