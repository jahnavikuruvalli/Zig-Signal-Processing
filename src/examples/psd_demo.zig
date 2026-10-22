//! PSD demo: estimates the power spectral density of the same noisy signal
//! with every method in `signal.spectral` and writes two CSV files:
//!
//!   psd_signal.csv  - the input samples (index,x)
//!   psd_output.csv  - freq,periodogram,modified,bartlett,welch,yule_walker,burg
//!
//! Plot with:  python3 plot_psd.py        Verify with:  python3 verify_psd.py
//!
//! Test signal: 50 Hz tone (amplitude 1) + 120 Hz tone (amplitude 0.5)
//! + Gaussian white noise (sigma = 0.5), sampled at 1000 Hz.

const std = @import("std");
const builtin = @import("builtin");
const signal = @import("signal");
const sp = signal.spectral;

pub const fs: f64 = 1000.0;
pub const n: usize = 4096;
pub const nfft: usize = 4096;

/// Zig 0.16+ moved file I/O behind `std.Io` and changed the signature of
/// `main`. Everything except the final file writes is version independent.
const new_io = builtin.zig_version.order(.{ .major = 0, .minor = 16, .patch = 0 }) != .lt;

pub const main = if (new_io) mainNew else mainOld;

const Csv = struct {
    signal_csv: []u8,
    psd_csv: []u8,

    fn deinit(self: Csv, allocator: std.mem.Allocator) void {
        allocator.free(self.signal_csv);
        allocator.free(self.psd_csv);
    }
};

fn mainOld() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const csv = try run(allocator);
    defer csv.deinit(allocator);

    const sig_file = try std.fs.cwd().createFile("psd_signal.csv", .{});
    defer sig_file.close();
    try sig_file.writeAll(csv.signal_csv);

    const out_file = try std.fs.cwd().createFile("psd_output.csv", .{});
    defer out_file.close();
    try out_file.writeAll(csv.psd_csv);

    std.debug.print("\nWrote psd_signal.csv and psd_output.csv\n", .{});
}

fn mainNew(init: std.process.Init) !void {
    const allocator = init.gpa;

    const csv = try run(allocator);
    defer csv.deinit(allocator);

    const sig_file = try std.Io.Dir.cwd().createFile(init.io, "psd_signal.csv", .{});
    defer sig_file.close(init.io);
    try sig_file.writeStreamingAll(init.io, csv.signal_csv);

    const out_file = try std.Io.Dir.cwd().createFile(init.io, "psd_output.csv", .{});
    defer out_file.close(init.io);
    try out_file.writeStreamingAll(init.io, csv.psd_csv);

    std.debug.print("\nWrote psd_signal.csv and psd_output.csv\n", .{});
}

/// Build the test signal, run every estimator, print a summary and return
/// both CSV files as text (caller frees via `Csv.deinit`).
fn run(allocator: std.mem.Allocator) !Csv {
    // ---- build the test signal ------------------------------------------
    const noise = try signal.signals.noise.gaussian(allocator, n, 0.5, 2024);
    defer allocator.free(noise);
    const x = try allocator.alloc(f64, n);
    defer allocator.free(x);
    for (x, 0..) |*v, i| {
        const t = @as(f64, @floatFromInt(i)) / fs;
        v.* = 1.0 * @sin(2.0 * std.math.pi * 50.0 * t) +
            0.5 * @sin(2.0 * std.math.pi * 120.0 * t) + noise[i];
    }

    // ---- estimate the PSD with every method (same nfft => same freq grid)
    var per = try sp.periodogram(allocator, x, .{ .fs = fs, .nfft = nfft });
    defer per.deinit();
    var mod = try sp.modifiedPeriodogram(allocator, x, .hann, .{ .fs = fs, .nfft = nfft });
    defer mod.deinit();
    var bar = try sp.bartlett(allocator, x, 512, .{ .fs = fs, .nfft = nfft });
    defer bar.deinit();
    var wel = try sp.welch(allocator, x, 512, 256, .hann, .{ .fs = fs, .nfft = nfft });
    defer wel.deinit();
    var yw = try sp.yuleWalker(allocator, x, 16, .{ .fs = fs, .nfft = nfft });
    defer yw.deinit();
    var bg = try sp.burg(allocator, x, 16, .{ .fs = fs, .nfft = nfft });
    defer bg.deinit();

    // ---- console summary -------------------------------------------------
    std.debug.print("Strongest frequency found by each method (true tones: 50 Hz and 120 Hz)\n", .{});
    std.debug.print("  periodogram          {d:8.3} Hz\n", .{per.peakFrequency()});
    std.debug.print("  modified (hann)      {d:8.3} Hz\n", .{mod.peakFrequency()});
    std.debug.print("  bartlett (L=512)     {d:8.3} Hz\n", .{bar.peakFrequency()});
    std.debug.print("  welch (L=512, 50%)   {d:8.3} Hz\n", .{wel.peakFrequency()});
    std.debug.print("  yule-walker (p=16)   {d:8.3} Hz\n", .{yw.peakFrequency()});
    std.debug.print("  burg (p=16)          {d:8.3} Hz\n", .{bg.peakFrequency()});

    // ---- CSV text --------------------------------------------------------
    var sig_csv: std.ArrayList(u8) = .empty;
    errdefer sig_csv.deinit(allocator);
    try sig_csv.appendSlice(allocator, "index,x\n");
    for (x, 0..) |v, i| try sig_csv.print(allocator, "{d},{d}\n", .{ i, v });

    var psd_csv: std.ArrayList(u8) = .empty;
    errdefer psd_csv.deinit(allocator);
    try psd_csv.appendSlice(allocator, "freq,periodogram,modified,bartlett,welch,yule_walker,burg\n");
    for (per.freqs, 0..) |f, k| {
        try psd_csv.print(allocator, "{d},{d},{d},{d},{d},{d},{d}\n", .{
            f, per.power[k], mod.power[k], bar.power[k], wel.power[k], yw.power[k], bg.power[k],
        });
    }

    const signal_text = try sig_csv.toOwnedSlice(allocator);
    errdefer allocator.free(signal_text);
    const psd_text = try psd_csv.toOwnedSlice(allocator);

    return .{ .signal_csv = signal_text, .psd_csv = psd_text };
}
