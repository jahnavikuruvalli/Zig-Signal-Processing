//! Test runner for zig-signal-processing
//!
//! Importing a file inside a `test` block makes Zig run every `test` in it.
//! List every source file here so no test (and no function) is silently
//! skipped. Works across Zig versions.

const std = @import("std");
const signal = @import("signal.zig");

test "public API compiles" {
    _ = signal;
}

test {
    // library sources (inline tests)
    _ = @import("fft/fft.zig");
    _ = @import("detection/peak_detection.zig");
    _ = @import("metrics/hrv.zig");
    _ = @import("filters/first-order.zig");
    _ = @import("filters/butterworth.zig");
    _ = @import("filters/filtfilt.zig");
    _ = @import("signals/sine.zig");
    _ = @import("signals/noisy-peaks.zig");
    _ = @import("signals/synthetic-ecg.zig");
    _ = @import("signals/noise.zig");
    _ = @import("spectral/window.zig");
    _ = @import("spectral/psd.zig");
    _ = @import("spectral/nonparametric.zig");
    _ = @import("spectral/parametric.zig");
    _ = @import("spectral/spectral.zig");
    _ = @import("core/biquad.zig");
    _ = @import("core/bandpass.zig");
    _ = @import("core/derivative.zig");
    _ = @import("core/moving-average.zig");
    _ = @import("core/peak-detector.zig");
    _ = @import("core/pipeline.zig");
    _ = @import("core/square.zig");
    _ = @import("design/onepole.zig");

    // dedicated test files
    _ = @import("tests/biquad-test.zig");
    _ = @import("tests/bandpass-test.zig");
    _ = @import("tests/derivative-test.zig");
    _ = @import("tests/square-test.zig");
    _ = @import("tests/moving-average-test.zig");
    _ = @import("tests/peak-detector-test.zig");
    _ = @import("tests/pipeline-test.zig");
    _ = @import("tests/stream-demo-test.zig");
    _ = @import("tests/onepole-test.zig");
    _ = @import("tests/design-to-filter-test.zig");
    _ = @import("tests/public-api-test.zig");
    _ = @import("tests/spectral-test.zig");
    _ = @import("tests/regression-test.zig");
    _ = @import("tests/spectral-test.zig");
    _ = @import("tests/regression-test.zig");

    // spectral estimation
    _ = @import("spectral/spectral.zig");
    _ = @import("spectral/window.zig");
    _ = @import("spectral/psd.zig");
    _ = @import("spectral/nonparametric.zig");
    _ = @import("spectral/parametric.zig");
    _ = @import("signals/noise.zig");
}
