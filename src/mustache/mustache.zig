const std = @import("std");

pub const ValueType = enum {
    null,
    bool,
    int,
    float,
    string,
    slice,
    object,
};

pub const Value = union(ValueType) {
    null: null,
    bool: bool,
    int: i64,
    float: f64,
    string: []const u8,
    slice: []const Value,
    object: std.HashMap([]const u8, Value),
};

pub fn Template(comptime T: type) type {
    return struct {
        const Tag = struct {
            key: []const u8,
            start: usize,
            end: usize,

            fn len(self: @This()) usize {
                return self.end - self.start;
            }
        };

        allocator: std.mem.Allocator,
        template: []const u8,
        tags: std.ArrayList(Tag),

        const Self = @This();

        pub fn compile(allocator: std.mem.Allocator, template: []const u8) !Self {
            var tags = std.ArrayList(Tag).init(allocator);

            var i: usize = 0;
            while (i < template.len) {
                // Must maintain that all indexes are relative to template[0..] so add the offset indexOf checks from
                const tag_start = i + (std.mem.indexOf(u8, template[i..], "{{") orelse break);
                const tag_close_pair = tag_start + 2 + (std.mem.indexOf(u8, template[tag_start + 2 ..], "}}") orelse break);
                const tag_end = tag_close_pair + 2;
                defer i = tag_end;

                // TODO: check for special tag types here like {{#, {{/

                const tag_key = std.mem.trim(u8, template[tag_start + 2 .. tag_close_pair], &std.ascii.whitespace);

                // TODO: do compile-time field name checking

                try tags.append(.{ .key = tag_key, .start = tag_start, .end = tag_end });
            }

            return .{ .allocator = allocator, .template = template, .tags = tags };
        }

        pub fn deinit(self: Self) void {
            self.tags.deinit();
        }

        /// Returns a new string owned by the caller.
        pub fn render(self: Self, value: T) ![]u8 {
            var buffer = try self.allocator.dupe(u8, self.template);
            // var shift: usize = 0;

            for (self.tags.items) |tag| {
                // Render the tag, the difference in new length vs old length must be used to offset all other tag starts

                if (std.mem.eql(u8, tag.key, ".")) {
                    const tag_value = try std.fmt.allocPrint(self.allocator, "{any}", .{value});
                    defer self.allocator.free(tag_value);

                    // TODO: using mem.replace will not work when there are more of the same tag, unless you pass a slice of template after the current and concat them....
                    const part_to_replace = self.template[tag.start..tag.end]; // TODO: use buffer[..] here?
                    const new_buffer_size = std.mem.replacementSize(u8, self.template, part_to_replace, tag_value);
                    // shift += new_buffer_size - buffer.len; // Offset future tag rendering by this amount

                    // Allocate new string to replace tag
                    const new_buffer = try self.allocator.alloc(u8, new_buffer_size);
                    defer {
                        self.allocator.free(buffer);
                        buffer = new_buffer;
                    }

                    // FIXME: will replace every instance of this tag value... that may be good, or may be bad. dunno yet
                    _ = std.mem.replace(u8, self.template, part_to_replace, tag_value, new_buffer);
                }
            }

            return buffer;
        }
    };
}

pub const Error = error{
    InvalidPath,
    InvalidKey,
    InvalidIndex,
    InvalidValue,
    InvalidTemplate,
    InvalidPartial,
    InvalidBlock,
    InvalidHelper,
    InvalidEscape,
    InvalidUnescape,
    InvalidCompile,
    InvalidRender,
};

const expect = std.testing.expect;

test "template with single value" {
    const t = try Template(i64).compile(std.testing.allocator, "Hello, {{.}}!");
    defer t.deinit();
    const result = try t.render(12);
    defer std.testing.allocator.free(result);
    try expect(std.mem.eql(u8, result, "Hello, 12!"));
}
