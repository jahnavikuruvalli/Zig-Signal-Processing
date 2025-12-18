# 🧠 Zig Signal Processing

A collection of **core digital signal processing (DSP) primitives** implemented in **Zig** ⚡  
Built from first principles with an emphasis on **clarity, correctness, and reusability**.

This repository serves as a **modular signal-processing core** developed alongside the  
**BioSense Prism** project, which focuses on biomedical signal analysis (e.g., ECG, EMG).  
All components here are written to be **independent, testable, and reusable** beyond the parent application.

---

## 🎯 Project Philosophy

- Learn and implement DSP algorithms **from first principles**
- Avoid black-box libraries in favor of **transparent implementations**
- Explore signal processing in a **systems-level language (Zig)**
- Build a clean DSP pipeline suitable for **biomedical signals**

This repository prioritizes **understanding and correctness** over heavy optimization.

---

## 📁 Repository Structure

src/
├── fft/            # Frequency-domain transforms
├── filters/        # Digital filters (IIR, Butterworth, filtfilt)
├── detection/      # Peak detection algorithms
├── metrics/        # Time-domain variability metrics
├── signals/        # Synthetic test signal generators

---

## ✅ Implemented Components

### 🔁 Fast Fourier Transform (FFT)
- Recursive **Cooley–Tukey FFT**
- Complex-valued input and output
- Converts **time-domain → frequency-domain** signals
- Suitable for ECG/EMG spectral analysis

---

### 🎚️ Digital Filters
- First-order **low-pass**, **high-pass**, and **band-pass** filters
- 2nd-order **Butterworth band-pass** filter
- Zero-phase filtering using forward–backward IIR processing (`filtfilt`)

Designed with **biomedical frequency bands** in mind.

---

### 📍 Peak Detection
- Generic peak detection in noisy 1D signals
- Uses:
  - derivative
  - squaring
  - moving-average smoothing
  - adaptive thresholding
  - refractory period enforcement
- Suitable for ECG R-peak detection and similar event-based signals

---

### ❤️ Time-Domain Variability Metrics
- RR interval computation (milliseconds)
- **SDNN**
- **RMSSD**
- **pNN50**

These metrics are commonly used in heart-rate variability (HRV) analysis but are implemented here in a **general, signal-agnostic** form.

---

### 🧪 Synthetic Test Signals
- Sine wave generator (FFT and filter validation)
- Noisy peak signal (peak detection testing)
- Simple synthetic ECG-like waveform (end-to-end pipeline testing)

Synthetic signals allow **deterministic testing** without relying on real biomedical data.

---

## 🧰 Typical Pipeline

Synthetic / real signal
↓
Digital filtering
↓
Peak detection
↓
RR interval extraction
↓
Time-domain variability metrics

---

## ⚠️ Disclaimer

This repository is **not intended to replace highly optimized DSP libraries** such as FFTW or platform-specific implementations.

It is an **educational and experimental codebase** intended to:
- deepen understanding of DSP fundamentals
- explore biomedical signal processing concepts
- support applied research and prototyping

---

## 🔗 Related Project

- **BioSense Prism**  
  Biomedical signal acquisition and analysis system  
  *(This repository provides the signal-processing core for BioSense Prism.)*


