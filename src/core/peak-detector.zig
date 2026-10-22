const std = @import("std");

pub const PeakEvent = struct {
    detected: bool,
    value: f32,
};

/// Streaming peak detector with a refractory period and an adaptive
/// threshold.
///
/// The threshold sits a fixed fraction (`threshold_fraction`) of the way
/// from a `floor` up to a running estimate of recent peak heights, so peaks
/// of similar size keep being detected indefinitely while small bumps are
/// rejected. With the default floor of 0 this is simply
/// `threshold = fraction * peak_level`. For signals whose baseline is
/// negative use `initWithFloor` with a value just above the baseline noise.
pub const PeakDetector = struct {
    /// Current detection threshold (derived from `floor` and `peak_level`).
    threshold: f32,
    /// Lowest value a peak may have (and the initial threshold).
    floor: f32,
    /// Running estimate of typical peak height (valid once `has_peak`).
    peak_level: f32 = 0.0,
    has_peak: bool = false,
    /// Threshold as a fraction of the way from `floor` to `peak_level`.
    threshold_fraction: f32 = 0.5,

    last: f32,
    rising: bool = false,

    refractory: usize,
    since_peak: usize,

    candidate: f32 = -std.math.inf(f32),

    pub fn init(refractory_samples: usize) PeakDetector {
        return initWithFloor(refractory_samples, 0.0);
    }

    /// Like `init`, for signals with a baseline other than zero: only
    /// local maxima above `floor` can be reported.
    pub fn initWithFloor(refractory_samples: usize, floor: f32) PeakDetector {
        return .{
            .threshold = floor,
            .floor = floor,
            .last = floor,
            .refractory = refractory_samples,
            // Start "outside" the refractory period so that a peak right
            // at the beginning of the stream is not suppressed.
            .since_peak = refractory_samples +| 1,
        };
    }

    pub fn reset(self: *PeakDetector) void {
        const fraction = self.threshold_fraction;
        self.* = initWithFloor(self.refractory, self.floor);
        self.threshold_fraction = fraction;
    }

    pub fn process(self: *PeakDetector, x: f32) PeakEvent {
        self.since_peak +|= 1;

        var event = PeakEvent{ .detected = false, .value = 0.0 };

        if (x > self.last) {
            // rising edge: remember the highest value seen so far
            self.rising = true;
            if (x > self.candidate)
                self.candidate = x;
        } else {
            // the signal stopped rising: the previous sample was a peak
            if (self.rising and
                self.candidate > self.threshold and
                self.since_peak > self.refractory)
            {
                event.detected = true;
                event.value = self.candidate;

                // update running peak estimate and the threshold from it
                self.peak_level = if (self.has_peak)
                    0.875 * self.peak_level + 0.125 * self.candidate
                else
                    self.candidate;
                self.has_peak = true;
                self.threshold = self.floor +
                    self.threshold_fraction * (self.peak_level - self.floor);

                self.since_peak = 0;
            }

            self.rising = false;
            self.candidate = -std.math.inf(f32);
        }

        self.last = x;
        return event;
    }
};

test "adaptive threshold keeps detecting equal-height peaks forever" {
    var pd = PeakDetector.init(5);
    var detected: usize = 0;
    var i: usize = 0;
    while (i < 300) : (i += 1) {
        const h: f32 = if (i % 2 == 0) 5.0 else 4.9;
        for ([_]f32{ 0, 0, h * 0.4, h, h * 0.4, 0, 0, 0, 0 }) |x| {
            if (pd.process(x).detected) detected += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 300), detected);
}

test "small noise bumps between large peaks are rejected" {
    var pd = PeakDetector.init(2);
    var detected: usize = 0;
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        // big peak (10), then a tiny bump (0.5) after the refractory period
        for ([_]f32{ 0, 5, 10, 5, 0, 0, 0, 0.5, 0, 0, 0 }) |x| {
            if (pd.process(x).detected) detected += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 50), detected);
}

test "negative baseline works with a floor" {
    var pd = PeakDetector.initWithFloor(5, -6.0);
    var count: usize = 0;
    const sig = [_]f32{ -9, -9, -8, -5, -8, -9, -9, -9, -9, -9, -9, -8, -4, -8, -9 };
    for (sig) |x| {
        if (pd.process(x).detected) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count);
}
