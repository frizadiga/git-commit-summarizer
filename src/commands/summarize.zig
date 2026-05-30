const std = @import("std");
const git = @import("../git.zig");
const llm = @import("../llm.zig");
const io_util = @import("../io_util.zig");

pub fn run(init: std.process.Init, arg_it: *std.process.Args.Iterator) !void {
    const gpa = init.gpa;
    const io = init.io;
    const environ_map = init.environ_map;

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

    // Trim trailing whitespace/newlines
    const trimmed = std.mem.trimEnd(u8, response, " \n\r\t");
    try io_util.print(io, "{s}\n", .{trimmed});
}
