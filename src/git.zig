const std = @import("std");
const child_util = @import("child_util.zig");

fn errPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [0x400]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buf);
    const w = &writer.interface;
    try w.print(fmt, args);
    try w.flush();
}

fn outPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [0x400]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const w = &writer.interface;
    try w.print(fmt, args);
    try w.flush();
}

pub fn diff(io: std.Io, gpa: std.mem.Allocator) ![]u8 {
    // Try git diff HEAD first (compare against last commit)
    var child = try std.process.spawn(io, .{
        .argv = &.{ "git", "--no-pager", "diff", "HEAD" },
        .stdout = .pipe,
        .stderr = .pipe,
    });

    const stdout = try child_util.readChildOutput(io, gpa, &child);
    errdefer gpa.free(stdout);

    const stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term = try child.wait(io);

    switch (term) {
        .exited => |code| {
            if (code == 0) return stdout;
            // If HEAD doesn't exist (fresh repo), fall back to git diff without HEAD
            if (std.mem.indexOf(u8, stderr, "ambiguous argument 'HEAD'") != null or
                std.mem.indexOf(u8, stderr, "unknown revision") != null)
            {
                gpa.free(stdout);
                // stderr will be freed by defer, don't free it here
                return diffFallback(io, gpa);
            }
            try errPrint(io, "git diff failed: {s}\n", .{stderr});
            gpa.free(stdout);
            return error.GitDiffFailed;
        },
        else => {
            try errPrint(io, "git diff failed: {s}\n", .{stderr});
            gpa.free(stdout);
            return error.GitDiffFailed;
        },
    }
}

fn diffFallback(io: std.Io, gpa: std.mem.Allocator) ![]u8 {
    // In a fresh repo with no commits, try git diff --cached first (staged changes)
    // then fall back to git diff (unstaged changes)
    
    // Try --cached first
    var child = try std.process.spawn(io, .{
        .argv = &.{ "git", "--no-pager", "diff", "--cached" },
        .stdout = .pipe,
        .stderr = .pipe,
    });

    var stdout = try child_util.readChildOutput(io, gpa, &child);
    var stderr = try child_util.readChildError(io, gpa, &child);
    const term = try child.wait(io);

    switch (term) {
        .exited => |code| {
            if (code == 0 and stdout.len > 0) {
                gpa.free(stderr);
                return stdout;
            }
            // No staged changes or other issue, try unstaged
            gpa.free(stdout);
            gpa.free(stderr);
        },
        else => {
            gpa.free(stdout);
            gpa.free(stderr);
        },
    }

    // Fall back to git diff (unstaged)
    child = try std.process.spawn(io, .{
        .argv = &.{ "git", "--no-pager", "diff" },
        .stdout = .pipe,
        .stderr = .pipe,
    });

    stdout = try child_util.readChildOutput(io, gpa, &child);
    errdefer gpa.free(stdout);

    stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term2 = try child.wait(io);

    switch (term2) {
        .exited => |code| {
            if (code != 0) {
                try errPrint(io, "git diff failed: {s}\n", .{stderr});
                gpa.free(stdout);
                return error.GitDiffFailed;
            }
        },
        else => {
            try errPrint(io, "git diff failed: {s}\n", .{stderr});
            gpa.free(stdout);
            return error.GitDiffFailed;
        },
    }

    return stdout;
}

pub fn add(io: std.Io, gpa: std.mem.Allocator) !void {
    var child = try std.process.spawn(io, .{
        .argv = &.{"git", "add", "."},
        .stdout = .pipe,
        .stderr = .pipe,
    });

    const stdout = try child_util.readChildOutput(io, gpa, &child);
    defer gpa.free(stdout);

    const stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term = try child.wait(io);

    switch (term) {
        .exited => |code| {
            if (code != 0) {
                try errPrint(io, "git add failed: {s}\n", .{stderr});
                return error.GitAddFailed;
            }
        },
        else => {
            try errPrint(io, "git add failed: {s}\n", .{stderr});
            return error.GitAddFailed;
        },
    }
}

pub fn commit(io: std.Io, gpa: std.mem.Allocator, message: []const u8) !void {
    var child = try std.process.spawn(io, .{
        .argv = &.{ "git", "commit", "-m", message },
        .stdout = .pipe,
        .stderr = .pipe,
    });

    const stdout = try child_util.readChildOutput(io, gpa, &child);
    defer gpa.free(stdout);

    const stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term = try child.wait(io);

    switch (term) {
        .exited => |code| {
            if (code != 0) {
                try errPrint(io, "git commit failed: {s}\n", .{stderr});
                return error.GitCommitFailed;
            }
        },
        else => {
            try errPrint(io, "git commit failed: {s}\n", .{stderr});
            return error.GitCommitFailed;
        },
    }

    try outPrint(io, "Commit message added and committed successfully.\n", .{});
}
