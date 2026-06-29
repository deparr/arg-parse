const std = @import("std");
const builtin = @import("builtin");

const ParseType = struct {
    arg: enum {
        int,
        float,
        string,
        flag,
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
};

const ArgFieldType = struct {
    name: []const u8,
    type: ParseType,
};

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

    return struct {
        pub const Result = ParseResult(T);
        pub fn parse(args: []const [:0]const u8) !Result {
            var options: T = .{};
            var i: usize = 1;
            while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (!std.mem.startsWith(u8, arg, "--")) continue;
                if (arg.len == 2) {
                    break;
                }

                var arg_name = arg[2..];
                const skipped = arg_name[0] == '/';
                const quick_bool_negate = arg_name[0] == '!';

                if (skipped or quick_bool_negate)
                    arg_name = arg[3..];

                inline for (fields) |field| {
                    if (strcmp(arg_name, field.name) and !skipped) {
                        if (i + 1 >= args.len) {
                            return error.ExpectedValue;
                        }
                        const val = args[i + 1];
                        @field(options, field.name) = blk: switch (field.type.arg) {
                            .int => {
                                i += 1;
                                break :blk try parseInt(val, field.type.backing);
                            },
                            .float => {
                                i += 1;
                                break :blk try parseFloat(val, field.type.backing);
                            },
                            .flag => {
                                if (quick_bool_negate)
                                    break :blk false;
                                i += 1;
                                break :blk try parseBool(val);
                            },
                            .string => val,
                        };
                    }
                }
            }

            return Result{ .success = true, .options = options };
        }
    };
}

fn ParseResult(comptime T: type) type {
    return struct { success: bool, options: T };
}

// TODO this silently returns false for garbage values
fn parseBool(val: [:0]const u8) !bool {
    if (strcmp(val, "true") or strcmp(val, "yes") or strcmp(val, "1")) {
        return true;
    } else if (strcmp(val, "false") or strcmp(val, "no") or strcmp(val, "0")) {
        return false;
    }
    return error.InvalidBool;
}

fn parseInt(val: [:0]const u8, int_type: type) !int_type {
    return std.fmt.parseInt(int_type, val, 0);
}

fn parseFloat(val: [:0]const u8, float_type: type) !float_type {
    return std.fmt.parseFloat(float_type, val);
}

fn strcmp(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
