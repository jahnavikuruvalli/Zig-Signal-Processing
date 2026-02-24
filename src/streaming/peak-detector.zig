pub const PeakEvent = struct {
    detected: bool,
    value: f32,
};

pub const PeakDetector = struct {
    threshold: f32 = 0.0,
    last: f32 = 0.0,
    rising: bool = false,

    refractory: usize,
    since_peak: usize = 0,

    candidate: f32 = 0.0,

    pub fn init(refractory_samples: usize) PeakDetector {
        return .{ .refractory = refractory_samples };
    }

    pub fn process(self: *PeakDetector, x: f32) PeakEvent {
        self.since_peak += 1;

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

                // update adaptive threshold
                self.threshold = 0.875 * self.threshold + 0.125 * self.candidate;

                self.since_peak = 0;
            }

            self.rising = false;
            self.candidate = 0.0;
        }

        self.last = x;
        return event;
    }
};
