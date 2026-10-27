# Zig-Signal-Processing

A lightweight, dependency-free **streaming digital signal processing (DSP) library written in Zig**.

This library focuses on **clarity, correctness, and composability**. Instead of large black-box algorithms, it provides small, stateful building blocks that can be combined into real-time processing pipelines for embedded systems, audio, sensors, and biomedical signals.

The project is designed to behave like real firmware:

- sample-by-sample processing
- explicit internal state
- deterministic execution
- no hidden allocations

---

## Philosophy

Most DSP student projects operate on full arrays of data:

```
input[] -> process -> output[]
```

Real devices do not work that way.

Sensors produce **one sample at a time**. Firmware must respond immediately:

```
new sample -> update system state -> output result
```

Zig‑Signal‑Processing implements DSP as a collection of **state machines evolving over time**, not batch math utilities.

---

## Current Capabilities

### Streaming DSP Primitives

- Direct Form II Transposed biquad filter
- Cascaded filter chains
- Numerical derivative (slope detector)
- Nonlinear energy (squaring)
- Moving window integrator (O(1) circular buffer)
- Adaptive peak detector (refractory period, adaptive threshold)

All primitives operate sample‑by‑sample:

```
const y = filter.process(x);
```

### Generic Processing Pipeline

Arbitrary processing stages can be chained at runtime:

```
var stages = [_]signal.core.Stage{
    .{ .ctx = &filter, .func = filterAdapter },
    .{ .ctx = &derivative, .func = derivativeAdapter },
};

var pipe = signal.core.Pipeline.init(&stages);
const y = pipe.process(x);
```

This allows construction of domain‑specific systems (ECG, audio envelope, motion detection) without modifying the library.

### Filter Design (Coefficient Generation)

- **First-order low-pass filter** via bilinear transform
- **Butterworth bandpass filter** (second-order) via bilinear transform with frequency pre-warping — returns digital IIR coefficients suitable for zero-phase filtering
- **filtfilt (zero-phase filtering)** — forward–backward IIR filtering that eliminates phase distortion, equivalent in spirit to `scipy.signal.filtfilt`. Both ends of the record are extended by odd reflection to suppress start-up transients, and invalid cutoffs return `error.InvalidCutoff`

```
const signal = @import("signal");

var lp = signal.lowpass(200.0, 10.0);
const y = lp.process(x);

const coeffs = signal.filters.butterworth.butterworthBandpass(fs, low, high);
const filtered = try signal.filters.filtfilt.filtfilt(allocator, input, fs, low, high);
```

No manual coefficient handling required for the one-pole case; Butterworth/filtfilt operate on full buffers rather than sample-by-sample, since zero-phase filtering inherently requires a forward and backward pass.

### Fast Fourier Transform

- Radix-2 FFT and inverse FFT on complex buffers (`fft`, `ifft`)
- `fftInPlace` turns a real signal into its magnitude spectrum
- Lengths must be powers of two; anything else returns an error instead of silently wrong output
- Verified against a naive DFT, the inverse transform, impulse response, zero-signal, and symmetry properties

```
try signal.fft.fft(complex_buffer);          // forward, in place
try signal.fft.ifft(complex_buffer);         // inverse (includes 1/N)
try signal.fft.fftInPlace(allocator, data);  // real input -> magnitude
```

### Heart Rate Variability (HRV) Metrics

Time-domain HRV metrics computed from detected peaks:

- **SDNN** — standard deviation of NN (RR) intervals
- **RMSSD** — root mean square of successive differences
- **pNN50** — percentage of successive RR differences exceeding 50ms

```
const hrv = try signal.metrics.computeHRV(allocator, peaks, fs);
// hrv.sdnn, hrv.rmssd, hrv.pnn50
```

### Peak Detection

- Derivative → squaring → moving-average energy pipeline (Pan-Tompkins-style) for robust peak/R-wave detection on noisy signals
- Streaming `core.PeakDetector` for sample-by-sample use

### Spectral Analysis (PSD estimation)

Whole-record power spectral density estimators in `signal.spectral`. Unlike the streaming blocks they take an allocator explicitly and return a `Psd` that you `deinit()` when finished.

| Method | Function |
| --- | --- |
| Periodogram | `spectral.periodogram(allocator, x, opts)` |
| Modified periodogram (windowed) | `spectral.modifiedPeriodogram(allocator, x, .hann, opts)` |
| Bartlett (averaged, non-overlapping segments) | `spectral.bartlett(allocator, x, segment_len, opts)` |
| Welch (averaged, overlapping, windowed segments) | `spectral.welch(allocator, x, segment_len, overlap, .hann, opts)` |
| Yule-Walker (autoregressive) | `spectral.yuleWalker(allocator, x, order, ar_opts)` |
| Burg (autoregressive) | `spectral.burg(allocator, x, order, ar_opts)` |

Supporting pieces:

- Window functions: `rectangular`, `bartlett`, `hann`, `hamming`, `blackman` (periodic or symmetric)
- Detrending: `none`, `constant`, `linear`
- Sample autocorrelation (biased / unbiased) and the Levinson-Durbin recursion
- Inspectable AR models: `yuleWalkerModel` / `burgModel` return coefficients, reflection coefficients and noise variance; `arPsd` turns a model into a spectrum

```
const sp = signal.spectral;

var psd = try sp.welch(allocator, x, 512, 256, .hann, .{ .fs = 1000.0 });
defer psd.deinit();

// psd.freqs[k] is in Hz, psd.power[k] in (signal units)^2 / Hz
const f0 = psd.peakFrequency();
const power = psd.totalPower();   // integral of the PSD = signal power
```

Conventions:

- Results are one-sided power spectral *densities* by default (`.onesided = false` returns all bins).
- `nfft` must be a power of two and at least the segment length (zero-padding refines the frequency grid); if omitted it is chosen automatically.
- AR methods assume zero-mean data and remove the mean by default.
- Burg gives sharper peaks on short records; Yule-Walker with the default biased autocorrelation always yields a stable model.

All six estimators are checked against SciPy and statsmodels to about 1e-14 by `verify_psd.py` (see Testing).

---

## Project Structure

```
src/
├── core/        # Stateful streaming blocks (biquad, pipeline, peak detector, ...)
├── design/      # Filter coefficient generators (one-pole)
├── filters/     # First-order, Butterworth design, filtfilt zero-phase filtering
├── fft/         # Radix-2 FFT / inverse FFT
├── detection/   # Batch peak detection
├── metrics/     # HRV (SDNN, RMSSD, pNN50)
├── spectral/    # PSD estimation: windows, periodogram, Welch, Yule-Walker, Burg
├── signals/     # Synthetic signal generators (sine, noise, ECG, noisy peaks)
├── examples/    # Demonstrations (ECG, FFT, PSD)
├── tests/       # Unit tests
├── signal.zig   # Public API entry point
└── tests.zig    # Test runner
```

`signal.zig` is the only intended public entry point:

```zig
const signal = @import("signal");   // module name defined in build.zig

signal.fft.fft(...) / .ifft(...) / .fftInPlace(...)
signal.spectral.welch(...) / .periodogram(...) / .burg(...) / ...
signal.metrics.computeHRV(...)
signal.filters.butterworth.butterworthBandpass(...)
signal.filters.filtfilt.filtfilt(...)
signal.detection.detectPeaksFromSignal(...)
signal.core.Biquad / Pipeline / MovingAverage / PeakDetector / ...
signal.lowpass(...)
```

---

## Usage

Add the library to another project. In your `build.zig.zon` add this package as a dependency (`zig fetch --save <url-or-path>` does it for you), then in your `build.zig`:

```
const dep = b.dependency("zig_signal", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("signal", dep.module("signal"));
```

and import it:

```
const signal = @import("signal");
```

Create a filter:

```
var lp = signal.lowpass(100.0, 5.0);
```

Process streaming samples:

```
const y = lp.process(sample);
```

Run an ECG pipeline end-to-end (bandpass → filtfilt → peak detection → HRV):

```
const coeffs = signal.filters.butterworth.butterworthBandpass(fs, 0.5, 40.0);
const clean = try signal.filters.filtfilt.filtfilt(allocator, ecg_raw, fs, 0.5, 40.0);
const peaks = try signal.detection.detectPeaksFromSignal(allocator, clean, fs);
const hrv = try signal.metrics.computeHRV(allocator, peaks, fs);
```

See `src/examples/ecg_demo.zig`, `src/examples/fft_example.zig` and `src/examples/psd_demo.zig` for full runnable examples.

---

## Testing

Requires Zig 0.15 or newer (verified on 0.15.2 and 0.17.0).

```
zig build test      # run every unit test
zig build           # compile all example programs into zig-out/bin
zig build run-fft   # FFT example
zig build run-ecg   # ECG filtering + R-peak detection -> ecg_output.csv
zig build run-psd   # PSD demo -> psd_signal.csv, psd_output.csv
```

Optional Python helpers (`pip install numpy scipy pandas matplotlib`; add `statsmodels` for one extra cross-check):

```
python3 plot_ecg.py     # plot ecg_output.csv
python3 plot_psd.py     # plot psd_output.csv
python3 verify_psd.py   # compare the PSD output (run `zig build run-psd` first) with SciPy
```

### Testing Approach

- behavior-based validation
- deterministic synthetic signals
- stability and convergence checks
- streaming execution verification
- FFT correctness checks (naive DFT, inverse, impulse response, zero-signal, symmetry)
- spectral estimators checked for Parseval's relation, known tone frequencies, variance reduction and exact AR-model recovery
- regression tests for previously hidden bugs, and a cross-check of the PSD estimators against SciPy/statsmodels

---

## Design Goals

- No external DSP dependencies
- No hidden heap allocations in streaming primitives (batch operations like FFT/filtfilt allocate explicitly via the caller's allocator)
- Deterministic execution
- Composable processing blocks
- Embedded-friendly architecture
- Clear separation of:
  - coefficient design
  - signal processing
  - application logic

---

## Status

**Version:** v2.2 (spectral estimation: periodogram, modified periodogram, Bartlett, Welch, Yule-Walker, Burg)
**Zig:** 0.15+ (tested on 0.15.2 and 0.17.0)
**License:** MIT

---

## Roadmap

Planned extensions:

- Fixed-point Q15/Q31 filters
- Higher-order Butterworth filter cascades (4th/6th order)
- Further spectral estimators (multitaper, AR order selection, covariance methods)
- Event-driven processing outputs
- Real-time signal analysis pipelines
- Microcontroller integration examples

---

## Author

Developed as a learning-first DSP systems project focused on building transparent, reusable, and firmware-grade signal-processing components in Zig.
