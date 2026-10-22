//! Power spectral density (PSD) estimation.
//!
//! Non-parametric (FFT based):
//!   periodogram, modifiedPeriodogram, bartlett, welch
//! Parametric (autoregressive):
//!   yuleWalker, burg   (+ yuleWalkerModel, burgModel, levinsonDurbin, arPsd)
//! Helpers:
//!   window functions, detrending, autocorrelation, `Psd` result type.

pub const window = @import("window.zig");
pub const psd = @import("psd.zig");
pub const nonparametric = @import("nonparametric.zig");
pub const parametric = @import("parametric.zig");

// Result and option types
pub const Psd = psd.Psd;
pub const Options = psd.Options;
pub const Detrend = psd.Detrend;
pub const ArOptions = parametric.ArOptions;
pub const ArModel = parametric.ArModel;
pub const AutocorrEstimator = parametric.AutocorrEstimator;
pub const WindowKind = window.Kind;
pub const WindowSymmetry = window.Symmetry;

// Non-parametric estimators
pub const periodogram = nonparametric.periodogram;
pub const modifiedPeriodogram = nonparametric.modifiedPeriodogram;
pub const bartlett = nonparametric.bartlett;
pub const welch = nonparametric.welch;
pub const segmentCount = nonparametric.segmentCount;

// Parametric estimators
pub const yuleWalker = parametric.yuleWalker;
pub const burg = parametric.burg;
pub const yuleWalkerModel = parametric.yuleWalkerModel;
pub const burgModel = parametric.burgModel;
pub const levinsonDurbin = parametric.levinsonDurbin;
pub const arPsd = parametric.arPsd;
pub const autocorrelation = parametric.autocorrelation;
