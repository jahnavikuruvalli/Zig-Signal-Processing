const std = @import("std");

/// O(1)-per-sample moving average over a caller-provided circular buffer.
pub const MovingAverage = struct {
    buffer: []f32,
    index: usize = 0,
    // f64 accumulator: avoids slow drift of the running sum in long runs
    sum: f64 = 0.0,
    filled: bool = false,

    /// `buffer` must be non-empty; its length is the window size.
    pub fn init(buffer: []f32) MovingAverage {
        std.debug.assert(buffer.len > 0);
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

        const denom: f64 = if (self.filled)
            @floatFromInt(self.buffer.len)
        else
            @floatFromInt(self.index);

        return @floatCast(self.sum / denom);
    }
};

test "no drift after a million samples" {
    var buf: [8]f32 = undefined;
    var ma = MovingAverage.init(&buf);
    var y: f32 = 0;
    var i: usize = 0;
    while (i < 1_000_000) : (i += 1) {
        // awkward non-representable value to provoke rounding error
        y = ma.process(0.1);
    }
    try std.testing.expectApproxEqAbs(0.1, y, 1e-6);
}
