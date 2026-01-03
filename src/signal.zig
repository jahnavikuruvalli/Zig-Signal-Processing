//! zig-signal
//!
//! A lightweight, dependency-free signal processing library written in Zig.
//!
//! This file defines the **public API surface** of the library.
//! Users should import ONLY this module:
//!
//!     const signal = @import("zig-signal");
//!
//! All internal folder structure is intentionally hidden behind namespaces.

/// Core Modules
/// Fast Fourier Transform utilities
/// Usage: signal.fft.fft(...)
pub const fft = @import("fft/fft.zig");

/// Peak detection algorithms (ECG / generic)
/// Usage: signal.detection.detectPeaks(...)
pub const detection = @import("detection/peak_detection.zig");

/// Signal metrics (HRV, etc.)
/// Usage: signal.metrics.calculateHRV(...)
pub const metrics = @import("metrics/hrv.zig");

/// Digital filtering utilities
/// Usage: signal.filters.first_order.lowpass(...)
pub const filters = struct {
    pub const first_order = @import("filters/first-order.zig");
    pub const butterworth = @import("filters/butterworth.zig");
    pub const filtfilt = @import("filters/filtfilt.zig");
};

/// Synthetic signal generators (testing & demos)
/// Usage: signal.signals.sine.generate(...)
pub const signals = struct {
    pub const sine = @import("signals/sine.zig");
    pub const noisy_peaks = @import("signals/noisy-peaks.zig");
    pub const synthetic_ecg = @import("signals/synthetic-ecg.zig");
};
