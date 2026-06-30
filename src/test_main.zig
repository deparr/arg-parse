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
    const result = try arg_parse.Parser(Options).parse(args, .{});
    if (!result.success) {
        std.debug.print("failed to parse", .{});
        std.process.exit(1);
    }

    std.debug.print(
        \\path: {s}
        \\count: {d}
        \\verbose: {}
        \\advanced: {}
        \\mode: {t}
    , .{
        result.options.path,
        result.options.count,
        result.options.verbose,
        result.options.advanced,
        result.options.mode,
    });
}
