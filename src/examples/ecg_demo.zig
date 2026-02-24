const std = @import("std");
const signal = @import("signal");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const fs = 250.0;
    const duration = 4.0;
    const heart_rate = 60.0;

    // Generate synthetic ECG
    const ecg = try signal.signals.synthetic_ecg.syntheticECG(
        allocator,
        fs,
        duration,
        heart_rate,
    );
    defer allocator.free(ecg);

    // Filter ECG
    const filtered = try signal.filters.filtfilt.filtfilt(
        allocator,
        ecg,
        fs,
        0.5,
        40.0,
    );
    defer allocator.free(filtered);

    // Detect peaks
    const peaks = try signal.detection.detectPeaksFromSignal(
        allocator,
        filtered,
        fs,
    );
    defer allocator.free(peaks);

    // Write CSV
    const file = try std.fs.cwd().createFile("ecg_output.csv", .{});
    defer file.close();

    // Write CSV header
    try file.writeAll("index,raw,filtered,peak\n");

    var line_buf: [128]u8 = undefined;

    for (filtered, 0..) |v, i| {
        var is_peak: u8 = 0;
        for (peaks) |p| {
            if (p == i) {
                is_peak = 1;
                break;
            }
        }

        const line = try std.fmt.bufPrint(
            &line_buf,
            "{d},{d},{d},{d}\n",
            .{ i, ecg[i], v, is_peak },
        );

        try file.writeAll(line);
    }
}
