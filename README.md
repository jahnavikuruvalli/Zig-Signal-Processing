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
- Adaptive peak detector

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
- **filtfilt (zero-phase filtering)** — forward–backward IIR filtering that eliminates phase distortion, equivalent in spirit to `scipy.signal.filtfilt`

```
const signal = @import("signal.zig");

var lp = signal.lowpass(200.0, 10.0);
const y = lp.process(x);

const coeffs = signal.filters.butterworth.butterworthBandpass(fs, low, high);
const filtered = try signal.filters.filtfilt.filtfilt(allocator, input, fs, low, high);
```

No manual coefficient handling required for the one-pole case; Butterworth/filtfilt operate on full buffers rather than sample-by-sample, since zero-phase filtering inherently requires a forward and backward pass.

### Fast Fourier Transform

- Recursive Cooley-Tukey FFT (radix-2, in-place magnitude spectrum)
- Operates on real-valued input, internally promoted to complex
- Verified against impulse response, zero-signal, and symmetry properties

```
try signal.fft.fftInPlace(allocator, data);
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

---

## Project Structure

```
src/
├── core/        # Stateful DSP building blocks (biquad, pipeline)
├── design/      # Filter coefficient generators (one-pole)
├── filters/     # Butterworth design + filtfilt zero-phase filtering
├── fft/         # Cooley-Tukey FFT
├── detection/   # Peak detection
├── metrics/     # HRV (SDNN, RMSSD, pNN50)
├── signals/     # Synthetic signal generators for testing/demos
├── examples/    # Demonstrations (ECG demo, FFT example)
├── tests/       # Unit tests
├── signal.zig   # Public API entry point
└── tests.zig    # Test runner
```

`signal.zig` is the only intended public entry point:

```zig
const signal = @import("zig-signal");

signal.fft.fftInPlace(...)
signal.metrics.computeHRV(...)
signal.filters.butterworth.butterworthBandpass(...)
signal.filters.filtfilt.filtfilt(...)
signal.detection.detectPeaks(...)
signal.core.Biquad / signal.core.Pipeline
signal.lowpass(...)
```

---

## Usage

Import the library:

```
const signal = @import("signal.zig");
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
const peaks = try signal.detection.detectPeaks(allocator, clean, fs);
const hrv = try signal.metrics.computeHRV(allocator, peaks, fs);
```

See `src/examples/ecg_demo.zig` and `src/examples/fft_example.zig` for full runnable examples.

---

## Testing

Run all tests:

```
zig test src/tests.zig
```

### Testing Approach

- behavior-based validation
- deterministic synthetic signals
- stability and convergence checks
- streaming execution verification
- FFT correctness checks (impulse response, zero-signal, symmetry)

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

**Version:** v2.1 (FFT, Butterworth, filtfilt, and HRV merged into the streaming architecture)
**Zig:** 0.15+
**License:** MIT

---

## Roadmap

Planned extensions:

- Fixed-point Q15/Q31 filters
- Higher-order Butterworth filter cascades (4th/6th order)
- Window functions for spectral leakage reduction
- Event-driven processing outputs
- Real-time signal analysis pipelines
- Microcontroller integration examples

---

## Author

Developed as a learning-first DSP systems project focused on building transparent, reusable, and firmware-grade signal-processing components in Zig.
