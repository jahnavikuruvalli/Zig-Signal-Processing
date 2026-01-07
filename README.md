# Zig-Signal-Processing

A lightweight, dependency-free digital signal processing (DSP) library written in Zig.

This library provides **first-principles implementations** of common DSP algorithms with a focus on **clarity, correctness, and testability**, rather than black-box abstractions. It is particularly suited for **biomedical signal processing (e.g., ECG)** and as a foundation for **embedded or bare-metal DSP systems**.

---

## Demo

Synthetic ECG signal processed using a zero-phase Butterworth bandpass filter,
with R-peaks detected using an energy-based pipeline and refined to waveform maxima.

![ECG R-peak Detection Demo]([https://user-images.githubusercontent.com/240754959/532715665-54e4f74f-414d-44f8-b587-6ab470bc5c50.png])

---

## Motivation

Most student DSP projects:

- rely heavily on external libraries  
- hide important numerical and signal-processing details  
- are difficult to reuse or extend  

This project takes a different approach:

- Algorithms are implemented from scratch  
- Memory ownership is explicit via allocators  
- Tests reflect real physical and numerical behavior  
- Code is written to be readable, auditable, and extensible  

The goal is to build a **clean DSP core** that can later be reused in:

- embedded firmware  
- biomedical instrumentation  
- custom MCU or SoC projects  

---

## Features

### Frequency Domain
- Recursive Cooley–Tukey FFT
- In-place magnitude spectrum computation
- Verified using impulse, symmetry, and zero-input tests

### Digital Filtering
- First-order low-pass and high-pass IIR filters
- Second-order Butterworth bandpass filter design
- Zero-phase forward–backward filtering (`filtfilt`)

### Biomedical Signal Processing
- R-peak detection pipeline:
  - derivative
  - squaring
  - moving-average integration
  - adaptive thresholding
  - peak refinement to waveform maxima
- RR-interval extraction
- Time-domain HRV metrics:
  - SDNN
  - RMSSD
  - pNN50

### Signal Generators (for testing & validation)
- Sine waves
- Noisy peak signals
- Synthetic ECG waveform generator

---

## Project Structure

```

src/
├── fft/              # FFT implementation
├── filters/          # IIR filters, Butterworth, filtfilt
├── detection/        # Peak detection algorithms
├── metrics/          # HRV metrics
├── signals/          # Synthetic signal generators
├── signal.zig        # Public library entry point
└── tests.zig         # Test runner

````

`signal.zig` is the only intended public entry point.

---

## Usage

Import the library:

```zig
const signal = @import("signal.zig");
````

### FFT

```zig
try signal.fft.fftInPlace(allocator, data);
```

### Zero-phase Bandpass Filtering (ECG)

```zig
const filtered = try signal.filters.filtfilt.filtfilt(
    allocator,
    ecg,
    fs,
    0.5,
    40.0,
);
```

### R-Peak Detection

```zig
const peaks = try signal.detection.detectPeaksFromSignal(
    allocator,
    filtered,
    fs,
);
```

### HRV Metrics

```zig
const hrv = try signal.metrics.computeHRV(
    allocator,
    peaks,
    fs,
);
```

---

## Testing

All functionality is tested using Zig’s built-in test framework.

Run the complete test suite:

```bash
zig test src/tests.zig
```

### Testing Philosophy

* Tests validate behavior, not exact numerical equality
* Transient effects and numerical tolerances are respected
* Synthetic signals are used for deterministic validation
* Tests reflect real DSP system behavior, not idealized math

---

## Design Principles

* No external DSP libraries
* No hidden memory allocations
* Explicit allocator usage everywhere
* Clear separation between:

  * algorithm design
  * signal processing
  * domain-specific logic
* Tests are treated as first-class code

This library intentionally prioritizes **understanding and correctness over premature optimization**.

---

## Status

* **Version:** v0.1.0
* **Zig:** 0.15+
* **License:** MIT

This project is considered stable as a learning and foundation library and is intended to evolve toward embedded and biomedical applications.

---

## Future Directions

Planned or possible extensions include:

* fixed-point (Q15/Q31) DSP for microcontrollers
* padding-aware `filtfilt` implementation
* frequency-domain HRV metrics
* real-time streaming pipelines
* integration with custom MCU firmware

---

## Author

Developed as a foundational DSP and biomedical signal-processing project, with the goal of building reusable, transparent, and testable signal-processing code in Zig.

```
