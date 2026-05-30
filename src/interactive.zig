const std = @import("std");
const io_util = @import("io_util.zig");

pub fn confirm(io: std.Io, prompt_msg: []const u8, message: ?[]const u8) !bool {
    if (message) |msg| {
        try io_util.print(io, "Suggestion:\n", .{});
        try io_util.print(io, "```\n", .{});
        try io_util.print(io, "{s}\n", .{msg});
        try io_util.print(io, "```\n\n", .{});
    }

    var buf: [256]u8 = undefined;

    while (true) {
        try io_util.print(io, "{s} (y/e/N): ", .{prompt_msg});

        const line = try io_util.readLine(&buf);
        if (line == null) return false;

        const response = std.mem.trim(u8, line.?, " \r\n");

        if (response.len == 0) return false;

        const first = std.ascii.toLower(response[0]);
        if (first == 'y') {
            return true;
        } else if (first == 'e') {
            return error.EditRequested;
        } else {
            return false;
        }
    }
}

pub fn editMessage(io: std.Io, gpa: std.mem.Allocator, environ_map: *const std.process.Environ.Map, message: []const u8) !?[]u8 {
    const editor = if (environ_map.get("EDITOR")) |val|
        try gpa.dupe(u8, val)
    else if (environ_map.get("VISUAL")) |val|
        try gpa.dupe(u8, val)
    else
        try gpa.dupe(u8, "vim");
    defer gpa.free(editor);

    const tmp_dir = std.Io.Dir.cwd();

    // Create temp file
    var tmp_file = try tmp_dir.createFile(io, "git-summarize-msg.tmp", .{ .read = true });
    defer tmp_file.close(io);
    try std.Io.File.writeStreamingAll(tmp_file, io, message);

    // Open editor
    var child = try std.process.spawn(io, .{
        .argv = &.{ editor, "git-summarize-msg.tmp" },
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });
    const term = try child.wait(io);

    // Read back
    const edited = tmp_dir.readFileAlloc(io, "git-summarize-msg.tmp", gpa, .limited(1024 * 1024)) catch |err| {
        try tmp_dir.deleteFile(io, "git-summarize-msg.tmp");
        if (err == error.FileNotFound) {
            try io_util.errPrint(io, "Edit cancelled.\n", .{});
            return null;
        }
        return err;
    };

    try tmp_dir.deleteFile(io, "git-summarize-msg.tmp");

    switch (term) {
        .exited => |code| {
            if (code != 0) {
                gpa.free(edited);
                try io_util.errPrint(io, "Edit cancelled.\n", .{});
                return null;
            }
        },
        else => {
            gpa.free(edited);
            try io_util.errPrint(io, "Edit cancelled.\n", .{});
            return null;
        },
    }

    return edited;
}
