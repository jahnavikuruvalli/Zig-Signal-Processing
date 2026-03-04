const std = @import("std");

pub const MovingAverage = struct {
    buffer: []f32,
    index: usize = 0,
    sum: f32 = 0.0,
    filled: bool = false,

    pub fn init(buffer: []f32) MovingAverage {
        @memset(buffer, 0.0);
        return .{ .buffer = buffer };
    }

    pub fn reset(self: *MovingAverage) void {
        @memset(self.buffer, 0.0);
        self.index = 0;
        self.sum = 0.0;
        self.filled = false;
    }

    pub fn process(self: *MovingAverage, x: f32) f32 {
        // remove oldest value
        self.sum -= self.buffer[self.index];

        // insert new value
        self.buffer[self.index] = x;
        self.sum += x;

        self.index += 1;
        if (self.index >= self.buffer.len) {
            self.index = 0;
            self.filled = true;
        }

        const denom: f32 = if (self.filled)
            @floatFromInt(self.buffer.len)
        else
            @floatFromInt(self.index);

        if (denom == 0) return 0.0;
        return self.sum / denom;
    }
};
