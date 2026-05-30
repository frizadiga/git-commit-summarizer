const std = @import("std");
const summarize = @import("commands/summarize.zig");
const commit = @import("commands/commit.zig");
const io_util = @import("io_util.zig");

pub fn main(init: std.process.Init) !void {
    const args = init.minimal.args;

    var arg_it = args.iterate();
    const argv0 = arg_it.next() orelse "git-summarize";

    const subcommand = arg_it.next() orelse {
        try io_util.errPrint(init.io, "Usage: {s} <summarize|commit> [args...]\n", .{argv0});
        std.process.exit(1);
    };

    if (std.mem.eql(u8, subcommand, "summarize")) {
        try summarize.run(init, &arg_it);
    } else if (std.mem.eql(u8, subcommand, "commit")) {
        try commit.run(init, &arg_it);
    } else {
        try io_util.errPrint(init.io, "Unknown subcommand: {s}\nUsage: {s} <summarize|commit> [args...]\n", .{ subcommand, argv0 });
        std.process.exit(1);
    }
}
