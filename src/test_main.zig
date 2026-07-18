const std = @import("std");
const flag = @import("lib.zig");

const Flags = struct {
    path: []const u8 = "something",
    count: u32 = 0,
    verbose: ?bool,
    advanced: bool = true,
    mode: enum {
        Debug,
        ReleaseSafe,
        ReleaseFast,
        ReleaseSmall,
    } = .Debug,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    var flags = Flags{ .verbose = false };
    const result = try flag.Parser(Flags).parse(arena, args, &flags, .{});

    std.debug.print(
        \\path: {s}
        \\count: {d}
        \\verbose: {}
        \\advanced: {}
        \\mode: {t}
        \\
        \\
    , .{
        flags.path,
        flags.count,
        flags.verbose,
        flags.advanced,
        flags.mode,
    });

    for (result.positional) |pos| {
        std.debug.print("{s}\n", .{pos});
    }
}
