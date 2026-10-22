const std = @import("std");

pub const PeakEvent = struct {
    detected: bool,
    value: f32,
};

/// Streaming peak detector with a refractory period and an adaptive
/// threshold.
///
/// The threshold is a fixed fraction (`threshold_fraction`) of a running
/// estimate of recent peak heights, so peaks of similar size keep being
/// detected indefinitely while small noise bumps are rejected.
pub const PeakDetector = struct {
    /// Current detection threshold (derived from `peak_level`).
    threshold: f32 = 0.0,
    /// Running estimate of typical peak height.
    peak_level: f32 = 0.0,
    /// Threshold as a fraction of `peak_level`.
    threshold_fraction: f32 = 0.5,

    last: f32 = 0.0,
    rising: bool = false,

    refractory: usize,
    since_peak: usize,

    candidate: f32 = 0.0,

    pub fn init(refractory_samples: usize) PeakDetector {
        return .{
            .refractory = refractory_samples,
            // Start "outside" the refractory period so that a peak right
            // at the beginning of the stream is not suppressed.
            .since_peak = refractory_samples +| 1,
        };
    }

    pub fn reset(self: *PeakDetector) void {
        self.* = PeakDetector.init(self.refractory);
    }

    pub fn process(self: *PeakDetector, x: f32) PeakEvent {
        self.since_peak +|= 1;

        var event = PeakEvent{ .detected = false, .value = 0.0 };

        // track rising edge
        if (x > self.last) {
            self.rising = true;
            if (x > self.candidate)
                self.candidate = x;
        } else {
            // peak reached
            if (self.rising and
                self.candidate > self.threshold and
                self.since_peak > self.refractory)
            {
                event.detected = true;
                event.value = self.candidate;

                // update running peak estimate and the threshold from it
                self.peak_level = if (self.peak_level == 0.0)
                    self.candidate
                else
                    0.875 * self.peak_level + 0.125 * self.candidate;
                self.threshold = self.threshold_fraction * self.peak_level;

                self.since_peak = 0;
            }

            self.rising = false;
            self.candidate = 0.0;
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
