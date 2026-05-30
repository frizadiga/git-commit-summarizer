const std = @import("std");
const Io = std.Io;

/// Print formatted text to stdout using the Io interface
pub fn print(io: Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [0x400]u8 = undefined;
    var writer = Io.File.stdout().writer(io, &buf);
    const w = &writer.interface;
    try w.print(fmt, args);
    try w.flush();
}

/// Print formatted text to stderr using the Io interface
pub fn errPrint(io: Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [0x400]u8 = undefined;
    var writer = Io.File.stderr().writer(io, &buf);
    const w = &writer.interface;
    try w.print(fmt, args);
    try w.flush();
}

/// Read a line from stdin up to newline or EOF
pub fn readLine(buffer: []u8) !?[]u8 {
    var i: usize = 0;
    while (i < buffer.len) {
        var byte: [1]u8 = undefined;
        const n = try std.posix.read(std.posix.STDIN_FILENO, &byte);
        if (n == 0) {
            if (i == 0) return null;
            return buffer[0..i];
        }
        if (byte[0] == '\n') {
            return buffer[0..i];
        }
        buffer[i] = byte[0];
        i += 1;
    }
    return buffer[0..i];
}
