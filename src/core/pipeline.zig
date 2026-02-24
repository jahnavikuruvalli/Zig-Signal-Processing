pub const StageFn = fn (ctx: *anyopaque, x: f32) f32;

pub const Stage = struct {
    ctx: *anyopaque,
    func: StageFn,
};

pub const Pipeline = struct {
    stages: []Stage,

    pub fn init(stages: []Stage) Pipeline {
        return .{ .stages = stages };
    }

    pub fn process(self: *Pipeline, x: f32) f32 {
        var y = x;
        for (self.stages) |s| {
            y = s.func(s.ctx, y);
        }
        return y;
    }
};
