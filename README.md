# Zig-Signal-Processing

A lightweight, dependency-free **streaming digital signal processing (DSP) library written in Zig**.

This library focuses on **clarity, correctness, and composability**. Instead of large black-box algorithms, it provides small, stateful building blocks that can be combined into real-time processing pipelines for embedded systems, audio, sensors, and biomedical signals.

The project is designed to behave like real firmware:

* sample-by-sample processing
* explicit internal state
* deterministic execution
* no hidden allocations

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

* Direct Form II Transposed biquad filter
* Cascaded filter chains
* Numerical derivative (slope detector)
* Nonlinear energy (squaring)
* Moving window integrator (O(1) circular buffer)
* Adaptive peak detector

All primitives operate sample‑by‑sample:

```zig
const y = filter.process(x);
```

---

### Generic Processing Pipeline

Arbitrary processing stages can be chained at runtime:

```zig
var stages = [_]signal.core.Stage{
    .{ .ctx = &filter, .func = filterAdapter },
    .{ .ctx = &derivative, .func = derivativeAdapter },
};

var pipe = signal.core.Pipeline.init(&stages);
const y = pipe.process(x);
```

This allows construction of domain‑specific systems (ECG, audio envelope, motion detection) without modifying the library.

---

### Filter Design (Coefficient Generation)

Currently implemented:

* First‑order low‑pass filter via bilinear transform

Simple public API:

```zig
const signal = @import("signal.zig");

var lp = signal.lowpass(200.0, 10.0);
const y = lp.process(x);
```

No manual coefficient handling required.

---

## Project Structure

```
src/
├── core/        # Stateful DSP building blocks
├── design/      # Filter coefficient generators
├── examples/    # Demonstrations and signal sources
├── tests/       # Unit tests
├── signal.zig   # Public API entry point
└── tests.zig    # Test runner
```

`signal.zig` is the only intended public entry point.

---

## Usage

Import the library:

```zig
const signal = @import("signal.zig");
```

Create a filter:

```zig
var lp = signal.lowpass(100.0, 5.0);
```

Process streaming samples:

```zig
const y = lp.process(sample);
```

---

## Testing

Run all tests:

```bash
zig test src/tests.zig
```

### Testing Approach

* behavior-based validation
* deterministic synthetic signals
* stability and convergence checks
* streaming execution verification

---

## Design Goals

* No external DSP dependencies
* No hidden heap allocations
* Deterministic execution
* Composable processing blocks
* Embedded-friendly architecture
* Clear separation of:

  * coefficient design
  * signal processing
  * application logic

---

## Status

**Version:** v2.0 (streaming architecture rewrite)
**Zig:** 0.15+
**License:** MIT

---

## Roadmap

Planned extensions:

* Butterworth filter designer
* Fixed‑point Q15/Q31 filters
* Window functions and FFT utilities
* Event‑driven processing outputs
* Real‑time signal analysis pipelines
* Microcontroller integration examples

---

## Author

Developed as a learning‑first DSP systems project focused on building transparent, reusable, and firmware‑grade signal‑processing components in Zig.
