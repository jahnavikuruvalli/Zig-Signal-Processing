const std = @import("std");
const builtin = @import("builtin");
const signal = @import("signal");

/// Zig 0.16+ moved file I/O behind `std.Io` and changed the signature of
/// `main`. Everything except the final file write is version independent.
const new_io = builtin.zig_version.order(.{ .major = 0, .minor = 16, .patch = 0 }) != .lt;

pub const main = if (new_io) mainNew else mainOld;

fn mainOld() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const csv = try buildCsv(allocator);
    defer allocator.free(csv);

    const file = try std.fs.cwd().createFile("ecg_output.csv", .{});
    defer file.close();
    try file.writeAll(csv);
}

fn mainNew(init: std.process.Init) !void {
    const allocator = init.gpa;

    const csv = try buildCsv(allocator);
    defer allocator.free(csv);

    const file = try std.Io.Dir.cwd().createFile(init.io, "ecg_output.csv", .{});
    defer file.close(init.io);
    try file.writeStreamingAll(init.io, csv);
}

/// Generate a synthetic ECG, filter it, detect R-peaks and return the
/// results as CSV text (caller frees).
fn buildCsv(allocator: std.mem.Allocator) ![]u8 {
    const fs = 250.0;
    const duration = 4.0;
    const heart_rate = 60.0;

    const ecg = try signal.signals.synthetic_ecg.syntheticECG(allocator, fs, duration, heart_rate);
    defer allocator.free(ecg);

    const filtered = try signal.filters.filtfilt.filtfilt(allocator, ecg, fs, 0.5, 40.0);
    defer allocator.free(filtered);

    const peaks = try signal.detection.detectPeaksFromSignal(allocator, filtered, fs);
    defer allocator.free(peaks);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.appendSlice(allocator, "index,raw,filtered,peak\n");

    for (filtered, 0..) |v, i| {
        const is_peak: u8 = if (std.mem.indexOfScalar(usize, peaks, i) != null) 1 else 0;
        try out.print(allocator, "{d},{d},{d},{d}\n", .{ i, ecg[i], v, is_peak });
    }

    return out.toOwnedSlice(allocator);
}
