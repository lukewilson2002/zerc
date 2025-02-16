const std = @import("std");
const Node = @import("zmd").Node;

pub const DefaultFragments = struct {
    pub fn root(allocator: std.mem.Allocator, node: Node) ![]const u8 {
        // Typically this would return a new string that gets deallocated,
        // but we don't want to generate an html document so we return a copy.
        return allocator.dupe(u8, node.content);
    }

    pub fn block(allocator: std.mem.Allocator, node: Node) ![]const u8 {
        const style = "font-family: Monospace;";

        return if (node.meta) |meta|
            std.fmt.allocPrint(allocator,
                \\<pre class="language-{s}" style="{s}"><code>{s}</code></pre>
            , .{ meta, style, node.content })
        else
            std.fmt.allocPrint(allocator,
                \\<pre style="{s}"><code>{s}</code></pre>
            , .{ style, node.content });
    }

    pub fn link(allocator: std.mem.Allocator, node: Node) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\<a href="{s}">{s}</a>
        , .{ node.href.?, node.title.? });
    }

    pub fn image(allocator: std.mem.Allocator, node: Node) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\<img src="{s}" title="{s}" />
        , .{ node.href.?, node.title.? });
    }

    pub const h1 = .{ "<h1>", "</h1>\n" };
    pub const h2 = .{ "<h2>", "</h2>\n" };
    pub const h3 = .{ "<h3>", "</h3>\n" };
    pub const h4 = .{ "<h4>", "</h4>\n" };
    pub const h5 = .{ "<h5>", "</h5>\n" };
    pub const h6 = .{ "<h6>", "</h6>\n" };
    pub const bold = .{ "<b>", "</b>" };
    pub const italic = .{ "<i>", "</i>" };
    pub const unordered_list = .{ "<ul>", "</ul>" };
    pub const ordered_list = .{ "<ol>", "</ol>" };
    pub const list_item = .{ "<li>", "</li>" };
    pub const code = .{ "<span style=\"font-family: Monospace\">", "</span>" };
    pub const paragraph = .{ "\n<p>", "</p>\n" };
    pub const default = .{ "", "" };
};
