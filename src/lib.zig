const std = @import("std");
const builtin = @import("builtin");

pub const ParseError = error{
    ExpectedValue,
    InvalidEnumVariant,
    InvalidNumber,
    InvalidBool,
    MissingAllocator,
} || std.mem.Allocator.Error;

const ParseType = struct {
    arg: enum {
        int,
        float,
        string,
        flag,
        @"enum",
    },
    backing: type,

    fn from(T: type) ParseType {
        return switch (@typeInfo(T)) {
            .int => .{
                .arg = .int,
                .backing = T,
            },
            .float => .{
                .arg = .float,
                .backing = T,
            },
            .bool => .{
                .arg = .flag,
                .backing = T,
            },
            .@"enum" => |e| blk: {
                if (!e.is_exhaustive)
                    @compileError("Non-exhaustive enums are not supported");
                break :blk .{
                    .arg = .@"enum",
                    .backing = T,
                };
            },
            .pointer => |p| blk: {
                const child = @typeInfo(p.child);
                switch (child) {
                    .int => |int| {
                        const signed = int.signedness == .signed;
                        if (int.bits != 8 or signed)
                            @compileError("Unsupported array type");

                        break :blk .{
                            .arg = .string,
                            .backing = []const u8,
                        };
                    },
                    else => @compileError("Unsupported array type (u8 only): " ++ @tagName(child)),
                }
            },
            else => |t| @compileError("Unable to parse arg type: " ++ @tagName(t)),
        };
    }

    fn string(self: ParseType) []const u8 {
        return switch (self.arg) {
            .int => blk: {
                const info = @typeInfo(self.backing).int;
                const sign = if (info.signedness == .signed) "i" else "u";
                break :blk std.fmt.comptimePrint("{s}{d}", .{ sign, info.bits });
            },
            .float => blk: {
                const info = @typeInfo(self.backing).float;
                break :blk std.fmt.comptimePrint("f{d}", .{info.bits});
            },
            .@"enum" => blk: {
                const info = @typeInfo(self.backing).@"enum";
                var variants_str: [:0]const u8 = "enum[";
                for (info.fields, 0..) |e, i| {
                    variants_str = variants_str ++ e.name ++ if (i < info.fields.len - 1) " " else "";
                }
                variants_str = variants_str ++ "]";
                break :blk variants_str;
            },
            .flag => "bool",
            .string => "string",
        };
    }
};

const ArgFieldType = struct {
    name: []const u8,
    type: ParseType,
};

pub const ParseOptions = struct {
    generate_help: bool = true,
    short_bools: bool = true,
    collect_positional: bool = false,
    arena: ?std.mem.Allocator = null,
};

fn helpMessage(comptime fields: []const ArgFieldType, comptime T: type) []const u8 {
    var result: []const u8 = "";
    const type_info = @typeInfo(T);
    // TOOD: there's gotta be a better way to do this
    inline for (fields) |field| {
        result = result ++ std.fmt.comptimePrint("  --{s} {s} ", .{ field.name, field.type.string() });
        inline for(type_info.@"struct".fields) |field2| {
            if (strcmp(field2.name, field.name)) {
                const fmt = if (field.type.arg == .string) ": \"{s}\"\n" else ": {}\n";
                result = result ++ std.fmt.comptimePrint(fmt, .{field2.defaultValue().?});
            }
        }
    }
    result = result ++
        \\
        \\
        ++ std.fmt.comptimePrint("build:{t}\n", .{ builtin.mode })
    ;
    return result;
}

pub fn Parser(comptime T: type) type {
    const type_info = @typeInfo(T);
    const struct_info = switch (type_info) {
        .@"struct" => |s| s,
        else => @compileError("Arg parse type must be a struct, got " ++ @tagName(type_info)),
    };

    if (struct_info.is_tuple)
        @compileError("Arg parse struct must not be a tuple");

    comptime var fields: [struct_info.fields.len]ArgFieldType = undefined;
    inline for (struct_info.fields, 0..) |field, i| {
        if (field.default_value_ptr == null)
            @compileError("Arg parse struct field has no default value: " ++ field.name);

        fields[i] = .{
            .name = field.name[0..],
            .type = .from(field.type),
        };
    }
    const help_message = helpMessage(&fields, T);

    return struct {
        pub const Result = ParseResult(T);
        pub fn parse(args: []const [:0]const u8, options: ParseOptions) ParseError!Result {
            var flags: T = .{};
            var i: usize = 1;

            var positionals = std.ArrayList([]const u8).empty;
            if (options.collect_positional) {
                if (options.arena == null) {
                    return error.MissingAllocator;
                } else {
                    positionals = try .initCapacity(options.arena.?, args.len);
                }
            }

            arg_loop: while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (!std.mem.startsWith(u8, arg, "--")) {
                    positionals.appendAssumeCapacity(arg);
                    continue;
                }
                if (arg.len == 2) {
                    break;
                }

                var arg_name = arg[2..];
                // TODO not sure if I like this being here instead of handled by the caller
                if (options.generate_help and strcmp(arg_name, "help")) {
                    showHelpAndExit(args[0]);
                }
                const skipped = arg_name[0] == '/';
                if (skipped)
                    arg_name = arg_name[1..];
                const bool_negate = options.short_bools and arg_name[0] == '!';
                if (bool_negate)
                    arg_name = arg_name[1..];

                inline for (fields) |field| {
                    if (strcmp(arg_name, field.name)) {
                        const arg_value = blk: {
                            if (options.short_bools and field.type.arg == .flag) {
                                break :blk !bool_negate;
                            } else {
                                if (i + 1 >= args.len)
                                    return error.ExpectedValue;
                                const val = args[i + 1];
                                i += 1;
                                break :blk switch (field.type.arg) {
                                    .int => try parseInt(val, field.type.backing),
                                    .float => try parseFloat(val, field.type.backing),
                                    .@"enum" => try parseEnum(val, field.type.backing),
                                    .flag => try parseBool(val),
                                    .string => val,
                                };
                            }
                        };
                        if (!skipped)
                            @field(flags, field.name) = arg_value;

                        continue :arg_loop;
                    }
                }

                if (options.collect_positional) {
                    positionals.appendAssumeCapacity(arg);
                }
            }

            if (i < args.len) {
                for (args[i..]) |pos_arg| {
                    positionals.appendAssumeCapacity(pos_arg);
                }
            }

            return Result{
                .flags = flags,
                .positional = if (options.collect_positional) try positionals.toOwnedSlice(options.arena.?) else &.{},
            };
        }

        pub fn showHelpAndExit(bin_path: [:0]const u8) noreturn {
            // TODO do I really need to use proper stderr?
            std.debug.print("Usage of {s}:\n{s}", .{ bin_path, help_message });
            std.process.exit(0);
        }
    };
}

// TODO more useful error reporting
fn ParseResult(comptime T: type) type {
    return struct { flags: T, positional: []const []const u8 };
}

fn parseBool(val: [:0]const u8) !bool {
    if (strcmp(val, "true") or strcmp(val, "yes") or strcmp(val, "1")) {
        return true;
    } else if (strcmp(val, "false") or strcmp(val, "no") or strcmp(val, "0")) {
        return false;
    }
    return error.InvalidBool;
}

fn parseInt(val: [:0]const u8, int_type: type) !int_type {
    return std.fmt.parseInt(int_type, val, 0) catch error.InvalidNumber;
}

fn parseFloat(val: [:0]const u8, float_type: type) !float_type {
    return std.fmt.parseFloat(float_type, val) catch error.InvalidNumber;
}

fn parseEnum(val: [:0]const u8, enum_type: type) !enum_type {
    return std.meta.stringToEnum(enum_type, val) orelse error.InvalidEnumVariant;
}

fn strcmp(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
