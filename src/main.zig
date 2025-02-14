const std = @import("std");

const Zmd = @import("zmd").Zmd;
const fragments = @import("zmd").html.DefaultFragments;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var zmd = Zmd.init(allocator);
    defer zmd.deinit();

    try zmd.parse(
        \\# Header
        \\## Sub-header
        \\### Sub-sub-header
        \\
        \\some text in **bold** and _italic_
        \\
        \\a paragraph
        \\
        \\```zig
        \\some code
        \\```
        \\some more text with a `code` fragment
    );

    const html = try zmd.toHtml(fragments);
    defer allocator.free(html);

    std.debug.print("{s}\n", .{html});
}
