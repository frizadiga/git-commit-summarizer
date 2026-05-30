const std = @import("std");
const child_util = @import("child_util.zig");

fn errPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [0x400]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buf);
    const w = &writer.interface;
    try w.print(fmt, args);
    try w.flush();
}

pub fn run(io: std.Io, gpa: std.mem.Allocator, prompt: []const u8, env_map: ?*const std.process.Environ.Map) ![]u8 {
    const llm_bin = if (env_map) |em|
        if (em.get("LLM_MAIN_ENTRY_BIN")) |val|
            try gpa.dupe(u8, val)
        else {
            try errPrint(io, "Error: LLM_MAIN_ENTRY_BIN not set. Run: source .env\n", .{});
            return error.LlmBinNotSet;
        }
    else {
        try errPrint(io, "Error: LLM_MAIN_ENTRY_BIN not set. Run: source .env\n", .{});
        return error.LlmBinNotSet;
    };
    defer gpa.free(llm_bin);

    var child = try std.process.spawn(io, .{
        .argv = &.{llm_bin},
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
        .environ_map = env_map,
    });

    try std.Io.File.writeStreamingAll(child.stdin.?, io, prompt);
    child.stdin.?.close(io);
    child.stdin = null;

    const stdout = try child_util.readChildOutput(io, gpa, &child);
    errdefer gpa.free(stdout);

    const stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term = try child.wait(io);

    switch (term) {
        .exited => |code| {
            if (code != 0) {
                try errPrint(io, "LLM exited with code {d}: {s}\n", .{ code, stderr });
                gpa.free(stdout);
                return error.LlmFailed;
            }
        },
        else => {
            try errPrint(io, "LLM process failed: {s}\n", .{stderr});
            gpa.free(stdout);
            return error.LlmFailed;
        },
    }

    return stdout;
}
