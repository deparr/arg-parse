const std = @import("std");
const arg_parse = @import("arg_parse.zig");

const Options = struct {
    a: []const u8 = "something",
    b: u32 = 0,
    c: bool = false,
    d: bool = true,
};

const OptionsEnum = enum {
    a,
    b,
    c
};

const OptionsTuple = struct {
    u32,
    f32,
    bool,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const result = try arg_parse.Parser(Options).parse(args);
    if (!result.success) {
        std.debug.print("failed to parse", .{});
        std.process.exit(1);
    }

    std.debug.print("a:{s} b:{d} c:{} d:{}\n", .{ result.options.a, result.options.b, result.options.c, result.options.d });
}
