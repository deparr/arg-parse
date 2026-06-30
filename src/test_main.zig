const std = @import("std");
const arg_parse = @import("arg_parse.zig");

const Options = struct {
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

const OptionsEnum = enum { a, b, c };

const OptionsTuple = struct {
    u32,
    f32,
    bool,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const result = try arg_parse.Parser(Options).parse(args, .{
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
