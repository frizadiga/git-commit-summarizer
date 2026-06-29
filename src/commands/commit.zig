const std = @import("std");
const git = @import("../git.zig");
const llm = @import("../llm.zig");
const interactive = @import("../interactive.zig");
const io_util = @import("../io_util.zig");
const child_util = @import("../child_util.zig");

pub fn run(init: std.process.Init, arg_it: *std.process.Args.Iterator) !void {
    const gpa = init.gpa;
    const io = init.io;
    const environ_map = init.environ_map;

    // Git add
    try git.add(io, gpa);

    // Holy word check
    try checkHolyWords(io, gpa, environ_map);

    // Build user message from remaining args
    var user_msg: std.ArrayList(u8) = .empty;
    defer user_msg.deinit(gpa);

    var first = true;
    while (arg_it.next()) |arg| {
        if (!first) try user_msg.append(gpa, ' ');
        first = false;
        try user_msg.appendSlice(gpa, arg);
    }

    // Get git diff
    const git_diff = try git.diff(io, gpa);
    defer gpa.free(git_diff);

    // Compose prompt
    const prompt = try std.fmt.allocPrint(gpa,
        \\create git commit message
        \\
        \\user_suggested_msg:
        \\{s}
        \\
        \\git diff:
        \\{s}
        \\
        \\requirements:
        \\- summarize the changes in the git diff
        \\- use the `Conventional Commit` format
        \\- use 50/72 rule
        \\- use present tense
        \\- use imperative mood
        \\- use concise and clear language
        \\- if user suggests a message exist then use it as a base of nuance in the commit message title
        \\- only respond with the commit message, do not add any other text or symbols
        \\  eg:
        \\  - do not add in the begining of output ```md
        \\
    , .{ user_msg.items, git_diff });
    defer gpa.free(prompt);

    // Run LLM
    const response = try llm.run(io, gpa, prompt, environ_map);
    defer gpa.free(response);

    const trimmed = std.mem.trimEnd(u8, response, " \n\r\t");

    // Confirm
    const confirmed = interactive.confirm(io, "Use the following commit message?", trimmed) catch |err| switch (err) {
        error.EditRequested => {
            const edited = try interactive.editMessage(io, gpa, environ_map, trimmed);
            if (edited) |msg| {
                defer gpa.free(msg);
                try git.commit(io, gpa, std.mem.trimEnd(u8, msg, " \n\r\t"));
                return;
            } else {
                try io_util.errPrint(io, "Aborted.\n", .{});
                std.process.exit(1);
            }
        },
        else => return err,
    };

    if (!confirmed) {
        try io_util.errPrint(io, "Aborted.\n", .{});
        std.process.exit(1);
    }

    try git.commit(io, gpa, trimmed);
}

fn checkHolyWords(io: std.Io, gpa: std.mem.Allocator, environ_map: *const std.process.Environ.Map) !void {
    const enable = if (environ_map.get("ENABLE_HOLY_WORD_CHECK")) |val|
        try gpa.dupe(u8, val)
    else
        return;
    defer gpa.free(enable);

    if (!std.mem.eql(u8, enable, "1")) return;

    const holy_words_env = if (environ_map.get("HOLY_WORDS")) |val|
        try gpa.dupe(u8, val)
    else
        return;
    defer gpa.free(holy_words_env);

    var holy_words_list: std.ArrayList([]const u8) = .empty;
    defer holy_words_list.deinit(gpa);

    var iter = std.mem.splitScalar(u8, holy_words_env, ',');
    while (iter.next()) |word| {
        const trimmed = std.mem.trim(u8, word, " ");
        if (trimmed.len > 0) {
            try holy_words_list.append(gpa, try gpa.dupe(u8, trimmed));
        }
    }
    defer {
        for (holy_words_list.items) |w| gpa.free(w);
    }

    const holy_words = holy_words_list.items;

    const file_list = try gitDiffNameOnly(io, gpa) orelse return;
    defer gpa.free(file_list);

    var found_any = false;
    var lines = std.mem.splitScalar(u8, file_list, '\n');
    while (lines.next()) |filepath| {
        if (filepath.len == 0) continue;

        const file_diff = try gitFileDiff(io, gpa, filepath) orelse continue;
        defer gpa.free(file_diff);

        if (!hasHolyWordsInDiff(file_diff, holy_words)) continue;

        if (!found_any) {
            try io_util.errPrint(io, "Holy word check failed:\n", .{});
            found_any = true;
        }

        try io_util.errPrint(io, "  file: {s}\n", .{filepath});
        printMatchingLines(io, gpa, filepath, holy_words) catch {};
    }

    if (found_any) {
        std.process.exit(1);
    }
}

fn gitDiffNameOnly(io: std.Io, gpa: std.mem.Allocator) !?[]u8 {
    var child = try std.process.spawn(io, .{
        .argv = &.{ "git", "--no-pager", "diff", "HEAD", "--name-only", "./" },
        .stdout = .pipe,
        .stderr = .pipe,
    });

    const stdout = try child_util.readChildOutput(io, gpa, &child);
    errdefer gpa.free(stdout);

    const stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term = try child.wait(io);
    if (term.exited != 0) return null;
    return stdout;
}

fn gitFileDiff(io: std.Io, gpa: std.mem.Allocator, filepath: []const u8) !?[]u8 {
    var child = try std.process.spawn(io, .{
        .argv = &.{ "git", "--no-pager", "diff", "HEAD", filepath },
        .stdout = .pipe,
        .stderr = .pipe,
    });

    const stdout = try child_util.readChildOutput(io, gpa, &child);
    errdefer gpa.free(stdout);

    const stderr = try child_util.readChildError(io, gpa, &child);
    defer gpa.free(stderr);

    const term = try child.wait(io);
    if (term.exited != 0) return null;
    return stdout;
}

fn hasHolyWordsInDiff(diff: []const u8, holy_words: []const []const u8) bool {
    var lines = std.mem.splitScalar(u8, diff, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (line[0] != '+') continue;
        if (std.mem.startsWith(u8, line, "+++")) continue;

        const content = line[1..];
        if (containsDevPattern(content)) return true;
        for (holy_words) |word| {
            if (containsWord(content, word)) return true;
        }
    }
    return false;
}

fn containsWord(s: []const u8, word: []const u8) bool {
    var i: usize = 0;
    while (i + word.len <= s.len) {
        if (asciiCaseInsensitiveEql(s[i..i + word.len], word)) {
            const prev_good = i == 0 or !isWordChar(s[i - 1]);
            const next_good = i + word.len == s.len or !isWordChar(s[i + word.len]);
            if (prev_good and next_good) return true;
        }
        i += 1;
    }
    return false;
}

fn containsDevPattern(s: []const u8) bool {
    if (s.len < 5) return false;
    var i: usize = 0;
    while (i + 5 <= s.len) {
        if (asciiCaseInsensitiveEql(s[i..i + 5], "@DEV:")) return true;
        i += 1;
    }
    return false;
}

fn isWordChar(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
        else => false,
    };
}

fn asciiCaseInsensitiveEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ac, bc| {
        if (asciiToLower(ac) != asciiToLower(bc)) return false;
    }
    return true;
}

fn asciiToLower(c: u8) u8 {
    return switch (c) {
        'A'...'Z' => c + 32,
        else => c,
    };
}

fn printMatchingLines(io: std.Io, gpa: std.mem.Allocator, filepath: []const u8, holy_words: []const []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const content = cwd.readFileAlloc(io, filepath, gpa, .limited(1024 * 1024)) catch |err| {
        try io_util.errPrint(io, "    (unable to read file: {})\n", .{err});
        return;
    };
    defer gpa.free(content);

    var line_num: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        line_num += 1;
        if (containsDevPattern(line)) {
            try io_util.errPrint(io, "    {d}: {s}\n", .{ line_num, line });
            continue;
        }
        for (holy_words) |word| {
            if (containsWord(line, word)) {
                try io_util.errPrint(io, "    {d}: {s}\n", .{ line_num, line });
                break;
            }
        }
    }
}
