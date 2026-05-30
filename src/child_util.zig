const std = @import("std");

/// Read all output from a child process stdout into an allocated string
pub fn readChildOutput(io: std.Io, gpa: std.mem.Allocator, child: *std.process.Child) ![]u8 {
    var buf: [4096]u8 = undefined;
    var stdout_reader = child.stdout.?.reader(io, &buf);
    var result: std.ArrayList(u8) = .empty;
    try stdout_reader.interface.appendRemainingUnlimited(gpa, &result);
    return result.toOwnedSlice(gpa);
}

/// Read all output from a child process stderr into an allocated string
pub fn readChildError(io: std.Io, gpa: std.mem.Allocator, child: *std.process.Child) ![]u8 {
    var buf: [4096]u8 = undefined;
    var stderr_reader = child.stderr.?.reader(io, &buf);
    var result: std.ArrayList(u8) = .empty;
    try stderr_reader.interface.appendRemainingUnlimited(gpa, &result);
    return result.toOwnedSlice(gpa);
}
