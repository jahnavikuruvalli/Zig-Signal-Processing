pub const Derivative = struct {
    prev: f32 = 0.0,
    initialized: bool = false,

    pub fn reset(self: *Derivative) void {
        self.prev = 0.0;
        self.initialized = false;
    }

    pub fn process(self: *Derivative, x: f32) f32 {
        if (!self.initialized) {
            self.prev = x;
            self.initialized = true;
            return 0.0; // no slope yet
        }

        const y = x - self.prev;
        self.prev = x;
        return y;
    }
};
