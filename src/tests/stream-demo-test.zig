const std = @import("std");
const SineOsc = @import("../examples/signal-source.zig").SineOsc;
const Biquad = @import("../core/biquad.zig").Biquad;
const Cascade = @import("../core/bandpass.zig").BiquadCascade;

test "streaming processing runs over time" {

    // 5 Hz signal sampled at 100 Hz
    var osc = SineOsc.init(5.0, 100.0);

    // simple smoothing filter (not real bandpass yet)
    var stages = [_]Biquad{
        Biquad.init(0.1, 0.0, 0.0, -0.9, 0.0),
    };

    var filter = Cascade.init(&stages);

    var energy: f32 = 0.0;

    var i: usize = 0;
    while (i < 500) : (i += 1) {
        const x = osc.next(); // sensor sample
        const y = filter.process(x); // firmware processing

        energy += @abs(y);
    }

    try std.testing.expect(energy > 0.0);
}
