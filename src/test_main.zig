const std = @import("std");
const flag = @import("lib.zig");

const Flags = struct {
    path: []const u8 = "something",
    count: u32 = 0,
    verbose: bool,
    advanced: bool = true,
    mode: enum {
        Debug,
        ReleaseSafe,
        ReleaseFast,
        ReleaseSmall,
    } = .Debug,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var flags = Flags{ .verbose = false };
    const result = try flag.Parser(Flags).parse(args, &flags, .{
        .collect_positional = true,
        .arena = init.arena.allocator(),
    });

    std.debug.print(
        \\path: {s}
        \\count: {d}
        \\verbose: {}
        \\advanced: {}
        \\mode: {t}
        \\
        \\
    , .{
        result.flags.path,
        result.flags.count,
        result.flags.verbose,
        result.flags.advanced,
        result.flags.mode,
    });

    for (result.positional) |pos| {
        std.debug.print("{s}\n", .{ pos });
    }
}
