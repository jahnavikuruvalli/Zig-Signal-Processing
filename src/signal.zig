//! zig-signal
//!
//! A lightweight, dependency-free signal processing library written in Zig.
//!
//! This file defines the **public API surface** of the library.
//! Users should import ONLY this module. When used as a dependency
//! (see build.zig.zon / build.zig), the module is named `signal`:
//!
//!     const signal = @import("signal");
//!
//! All internal folder structure is intentionally hidden behind namespaces.

/// Fast Fourier Transform utilities
/// Usage: signal.fft.fftInPlace(...)
pub const fft = @import("fft/fft.zig");

/// Peak detection algorithms (ECG / generic)
/// Usage: signal.detection.detectPeaksFromSignal(...)
pub const detection = @import("detection/peak_detection.zig");

/// Signal metrics (HRV, etc.)
/// Usage: signal.metrics.computeHRV(...)
pub const metrics = @import("metrics/hrv.zig");

/// Batch (whole-array) digital filtering utilities
/// Usage: signal.filters.first_order.lowPass(...)
pub const filters = struct {
    pub const first_order = @import("filters/first-order.zig");
    pub const butterworth = @import("filters/butterworth.zig");
    pub const filtfilt = @import("filters/filtfilt.zig");
};

/// Synthetic signal generators (testing & demos)
/// Usage: signal.signals.sine.sine(...)
pub const signals = struct {
    pub const sine = @import("signals/sine.zig");
    pub const noisy_peaks = @import("signals/noisy-peaks.zig");
    pub const synthetic_ecg = @import("signals/synthetic-ecg.zig");
};

/// Streaming (sample-by-sample) building blocks
pub const core = struct {
    pub const Biquad = @import("core/biquad.zig").Biquad;
    pub const BiquadCascade = @import("core/bandpass.zig").BiquadCascade;
    pub const Derivative = @import("core/derivative.zig").Derivative;
    pub const MovingAverage = @import("core/moving-average.zig").MovingAverage;
    pub const PeakDetector = @import("core/peak-detector.zig").PeakDetector;
    pub const PeakEvent = @import("core/peak-detector.zig").PeakEvent;
    pub const Squaring = @import("core/square.zig").Squaring;
    pub const Pipeline = @import("core/pipeline.zig").Pipeline;
    pub const Stage = @import("core/pipeline.zig").Stage;
};

/// Filter coefficient design
pub const design = struct {
    pub const onepole = @import("design/onepole.zig");
};

/// Convenience: first-order streaming low-pass filter.
pub fn lowpass(fs: f32, cutoff: f32) core.Biquad {
    const coeff = design.onepole.lowpass(fs, cutoff);
    return core.Biquad.fromOnePole(coeff);
}
