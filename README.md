# Zig Signal Processing

This repository contains common signal processing primitives implemented in **Zig**.

The goal of this project is to understand and implement core digital signal processing (DSP) algorithms from first principles, rather than relying on black-box libraries. The implementations here prioritize clarity and correctness over heavy optimization.

This repository is developed as a **supporting signal-processing core** for the **BioSense Prism** project, which focuses on biomedical signal analysis (ECG, EMG, and related signals). The code is kept modular so it can be reused independently of the main application.

---

## Currently Implemented

### Fast Fourier Transform (FFT)
- Recursive Cooley–Tukey FFT
- Complex-valued input and output
- Demonstrates frequency-domain transformation from time-domain signals


---

## Planned Additions

- Digital filters (Butterworth, band-pass, low-pass)
- Peak detection in noisy signals
- Time-domain metrics (e.g., SDNN, RMSSD)
- Signal generation utilities for testing

---

## Disclaimer

This repository is **not intended to replace optimized DSP libraries** such as FFTW or platform-specific implementations. It is primarily an educational and experimental codebase designed to deepen understanding of signal processing and low-level systems programming.

---

## Related Project

- **BioSense Prism** – Biomedical signal acquisition and analysis system


