const std = @import("std");
const Zmd = @import("zmd").Zmd;
// const fragments = @import("zmd").html.DefaultFragments;
const fragments = @import("html_fragments.zig").DefaultFragments;
const default_style = @embedFile("style.css");

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.debug.print("error: you must provide a path to a root folder\n", .{});
        return error.InvalidArgs;
    }

    // using gpa for now, it detects data leaks and has already been helpful (but arenas don't require freeing?)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // root_path is the folder to copy from
    const root_path = std.mem.span(std.os.argv[1]);
    var root_dir = try std.fs.cwd().openDir(root_path, .{ .access_sub_paths = true, .iterate = true });
    defer root_dir.close();

    // self explanatory
    const out_path = "build";

    // Delete the build directory if it already exists, otherwise the user
    // may have removed content and the build would still contain the removed content.
    blk: {
        const stat = std.fs.cwd().statFile(out_path) catch break :blk;
        if (stat.kind != .directory) {
            std.debug.print("cannot create build directory, a non-directory file already exists with that name\n", .{});
            return error.CannotMakeBuildDir;
        }
        try std.fs.cwd().deleteTree(out_path);
    }

    var out_dir = try std.fs.cwd().makeOpenPath(out_path, .{});
    defer out_dir.close();

    var walker = try root_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        // Create string representations of the entry as a path relative to the CWD
        const src_rel_path = try std.fs.path.join(allocator, &[_][]const u8{ root_path, entry.path });
        const out_rel_path = try std.fs.path.join(allocator, &[_][]const u8{ out_path, entry.path });
        defer allocator.free(src_rel_path);
        defer allocator.free(out_rel_path);

        if (entry.kind == .directory) {
            std.debug.print("mkdir {s} -> {s}\n", .{ src_rel_path, out_rel_path });

            out_dir.makeDir(entry.path) catch |err| {
                if (err != error.PathAlreadyExists) {
                    return err;
                }
            };
            continue;
        }

        const ext = std.fs.path.extension(entry.basename);

        if (std.mem.eql(u8, ext, ".md")) {
            // TODO: could move this into a function for converting and writing markdown -> html file

            const out_rel_path_html = try replaceExt(allocator, out_rel_path, ".html", .{ .cur_ext = ext });
            defer allocator.free(out_rel_path_html);

            std.debug.print("md {s} -> {s}\n", .{ src_rel_path, out_rel_path_html });

            // FIXME: I have no idea what the max_bytes should be
            const contents = try root_dir.readFileAlloc(allocator, entry.path, std.math.maxInt(usize));
            defer allocator.free(contents);

            // Convert Markdown to HTML
            const html = try renderMarkdown(allocator, contents);
            defer allocator.free(html);

            // Create / overwrite existing file with HTML
            const path = try replaceExt(allocator, entry.path, ".html", .{ .cur_ext = ext });
            defer allocator.free(path);
            const file = try out_dir.createFile(path, .{});
            defer file.close();
            try file.writeAll(html);
        } else {
            // Copy any file that's not markdown
            std.debug.print("copy {s} -> {s}\n", .{ src_rel_path, out_rel_path });
            root_dir.copyFile(entry.path, out_dir, entry.path, .{}) catch |err| {
                std.debug.print("failed copying with error: {?}\n", .{err});
            };
        }
    }

    // Write defaults to build folder (todo: user overwrites in conf)
    std.debug.print("default style.css\n", .{});
    const css_file = try out_dir.createFile("style.css", .{});
    defer css_file.close();
    try css_file.writeAll(default_style);

    // Leaving this here for when we need to use stdout and we can't remember how the fuck to do it

    // stdout is for the actual output of your application.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
}

fn renderMarkdown(allocator: std.mem.Allocator, md: []const u8) ![]const u8 {
    var zmd = Zmd.init(allocator);
    defer zmd.deinit();
    try zmd.parse(md);

    const html = try zmd.toHtml(fragments);
    defer allocator.free(html);

    return try std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<meta charset="UTF-8">
        \\<link rel="stylesheet" href="/style.css">
        \\</head>
        \\<body>
        \\<main>{s}</main>
        \\</body>
        \\</html>
        \\
    , .{html});
}

/// Replaces a filename's extension. new_ext can be ".html" for example.
fn replaceExt(
    allocator: std.mem.Allocator,
    filename: []const u8,
    new_ext: []const u8,
    options: struct { cur_ext: []const u8 = "" }, // Specify the extension if you already know it.
) ![]u8 {
    var name: []const u8 = undefined;
    if (options.cur_ext.len > 0) {
        name = filename[0 .. filename.len - options.cur_ext.len];
    } else {
        const dot = std.mem.lastIndexOf(u8, filename, ".");
        if (dot) |index| {
            name = filename[0..index]; // Remove everything at and after the last dot
        }
    }
    return std.mem.concat(allocator, u8, &[_][]const u8{ name, new_ext });
}
