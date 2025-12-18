# 🧠 Zig Signal Processing

A collection of **core digital signal processing (DSP) primitives** implemented in **Zig** ⚡  
Built from first principles with an emphasis on **clarity, correctness, and learning**.

This repository serves as a **modular signal-processing backbone** for the **BioSense Prism** project, which focuses on biomedical signal analysis such as **ECG** and **EMG**.  
The code is intentionally kept independent and reusable beyond the parent application.

---

## 🎯 Project Goals

- Understand DSP algorithms at a **mathematical and implementation level**
- Avoid black-box libraries in favor of **transparent, readable code**
- Explore DSP in a **systems-level language (Zig)**
- Build reusable primitives applicable to **biomedical signals**

---

## ✅ Currently Implemented

### 🔁 Fast Fourier Transform (FFT)
- Recursive **Cooley–Tukey FFT**
- Complex-valued input and output
- Converts **time-domain signals → frequency domain**
- Suitable for ECG/EMG spectral analysis

---

## 🛠️ Implemented Filters

### 🎚️ First-Order Filters
- Low-pass filter
- High-pass filter
- Band-pass filter (HPF → LPF cascade)

### 🧮 Butterworth Filters
- 2nd-order Butterworth band-pass filter
- Coefficient generation using bilinear transform
- Zero-phase filtering using forward-backward (`filtfilt`) IIR processing

These filters are designed with **biomedical frequency bands** in mind.

---

### ❤️ Time-Domain Variability Metrics
- RR interval computation
- SDNN
- RMSSD
- pNN50


---

## ⚠️ Disclaimer

This repository is **not intended to replace highly optimized DSP libraries** such as FFTW or platform-specific implementations.

---

## 🔗 Related Project

- **BioSense Prism** – Biomedical signal acquisition and analysis system  
  *(This repository provides the signal-processing core for BioSense Prism.)*


