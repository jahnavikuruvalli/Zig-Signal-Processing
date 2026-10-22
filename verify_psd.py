#!/usr/bin/env python3
"""
Cross-check the Zig PSD estimators against independent reference implementations.

    zig build run-psd          # writes psd_signal.csv and psd_output.csv
    python3 verify_psd.py

Requires:  pip install numpy scipy        (statsmodels is optional: pip install statsmodels)
Exit code 0 = everything agrees, 1 = a mismatch was found.
"""
import sys
import numpy as np
from scipy import signal as ss
from scipy.linalg import solve_toeplitz

FS, NFFT = 1000.0, 4096          # must match src/examples/psd_demo.zig
YW_ORDER = BURG_ORDER = 16

x = np.loadtxt("psd_signal.csv", delimiter=",", skiprows=1)[:, 1]
out = np.genfromtxt("psd_output.csv", delimiter=",", names=True)


def one_sided_ar(var, a):
    """sigma^2 / (fs |A(f)|^2), one-sided, A(z) = 1 + a1 z^-1 + ..."""
    A = np.fft.rfft(np.r_[1.0, a], NFFT)
    p = var / (FS * np.abs(A) ** 2)
    p[1:-1] *= 2.0
    return p


def burg_reference(x, order):
    """Burg straight from the definition: after each order, recompute the
    forward/backward prediction errors by FIR-filtering with the current
    polynomial (independent of the lattice recursion used in the Zig code)."""
    x = x - x.mean()
    a = np.array([1.0])
    var = np.mean(x ** 2)
    for m in range(1, order + 1):
        # forward error f[n] = sum_k a_k x[n-k]; backward b[n] = sum_k a_k x[n-m+k]
        f = np.convolve(x, a)[: len(x)]                  # f[n]
        b = np.convolve(x, a[::-1])[: len(x)]            # b[n] = sum a_k x[n-m+1+k]... see below
        # With a of length m (orders 0..m-1), a[::-1] convolution gives
        # b_{m-1}[n] = sum_{k=0}^{m-1} a_k x[n-(m-1)+k]  (backward error of order m-1 at time n)
        fm = f[m:]               # f_{m-1}[n],   n = m..N-1
        bm = b[m - 1:-1]         # b_{m-1}[n-1], n = m..N-1
        k = -2.0 * np.dot(fm, bm) / (np.dot(fm, fm) + np.dot(bm, bm))
        a = np.r_[a, 0.0] + k * np.r_[0.0, a[::-1]]
        var *= 1.0 - k * k
    return a[1:], var


def compare(name, got, ref, rtol=1e-6):
    err = np.max(np.abs(got - ref) / (np.abs(ref) + 1e-30))
    ok = err < rtol
    print(f"  {'PASS' if ok else 'FAIL'}  {name:<22} max relative error = {err:.2e}")
    return ok


results = []
print("Non-parametric (reference: scipy.signal)")
f, ref = ss.periodogram(x, FS, window="boxcar", nfft=NFFT, detrend=False, scaling="density")
results.append(compare("frequency axis", out["freq"], f))
results.append(compare("periodogram", out["periodogram"], ref))
_, ref = ss.periodogram(x, FS, window="hann", nfft=NFFT, detrend=False, scaling="density")
results.append(compare("modified (hann)", out["modified"], ref))
_, ref = ss.welch(x, FS, window="boxcar", nperseg=512, noverlap=0, nfft=NFFT, detrend=False)
results.append(compare("bartlett (512)", out["bartlett"], ref))
_, ref = ss.welch(x, FS, window="hann", nperseg=512, noverlap=256, nfft=NFFT, detrend=False)
results.append(compare("welch (512, 50%)", out["welch"], ref))

print("Parametric (reference: Toeplitz solve / independent Burg / statsmodels)")
xm = x - x.mean()
r = np.array([np.dot(xm[k:], xm[: len(xm) - k]) / len(xm) for k in range(YW_ORDER + 1)])
a_yw = -solve_toeplitz(r[:-1], r[1:])                  # R a' = r  ->  a = -a'
var_yw = r[0] + np.dot(a_yw, r[1:])
results.append(compare("yule-walker", out["yule_walker"], one_sided_ar(var_yw, a_yw)))

a_b, var_b = burg_reference(x, BURG_ORDER)
results.append(compare("burg (own reference)", out["burg"], one_sided_ar(var_b, a_b)))

try:
    from statsmodels.regression.linear_model import burg as sm_burg, yule_walker as sm_yw
    # statsmodels' Burg uses a slightly different noise-variance estimator
    # (~0.04 % here), so compare the spectral *shape*: identical coefficients
    # give a PSD that differs only by one constant factor.
    rho, sig2 = sm_burg(x, order=BURG_ORDER, demean=True)
    ref = one_sided_ar(sig2, -rho)
    ref *= np.mean(out["burg"] / ref)
    results.append(compare("burg shape (statsm.)", out["burg"], ref))
    rho, sigma = sm_yw(x, order=YW_ORDER, method="mle", demean=True, result_object=False)
    results.append(compare("yule-walker (statsm.)", out["yule_walker"], one_sided_ar(sigma ** 2, -rho)))
except ImportError:
    print("  (statsmodels not installed - skipping that extra check)")

print()
if all(results):
    print("ALL CHECKS PASSED")
    sys.exit(0)
print("MISMATCH FOUND")
sys.exit(1)
