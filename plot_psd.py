#!/usr/bin/env python3
"""
Plot the PSD estimates written by the Zig demo.

    zig build run-psd
    python3 plot_psd.py            # needs: pip install pandas matplotlib

Saves psd_plot.png and also opens a window.
"""
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("psd_output.csv")

fig, axes = plt.subplots(2, 1, figsize=(11, 8), sharex=True)

groups = [
    ("Non-parametric (FFT) estimators", ["periodogram", "modified", "bartlett", "welch"]),
    ("Parametric (autoregressive) estimators, order 16", ["yule_walker", "burg"]),
]
for ax, (title, cols) in zip(axes, groups):
    for c in cols:
        ax.semilogy(df["freq"], df[c], label=c, linewidth=1)
    ax.axvline(50, color="gray", linestyle=":", linewidth=0.8)
    ax.axvline(120, color="gray", linestyle=":", linewidth=0.8)
    ax.set_title(title + "  (dotted lines: true tones at 50 and 120 Hz)")
    ax.set_ylabel("PSD  [signal$^2$ / Hz]")
    ax.legend()
    ax.grid(True, which="both", alpha=0.3)

axes[-1].set_xlabel("Frequency [Hz]")
plt.tight_layout()
plt.savefig("psd_plot.png", dpi=130)
plt.show()
