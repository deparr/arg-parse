const std = @import("std");
const flags = @import("lib.zig");

const Flags = struct {
    path: []const u8 = "something",
    count: u32 = 0,
    verbose: bool = false,
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
    const result = try flags.Parser(Flags).parse(args, .{
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
