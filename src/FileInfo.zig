const std = @import("std");
const heap = std.heap;
const log = std.log;
const fs = std.fs;
const mem = std.mem;
const meta = std.meta;
const Timestamp = @import("Timestamp.zig");

const Self = @This();
arena: *heap.ArenaAllocator,
name: []const u8,
kind: fs.File.Kind,
dir: []const u8,
mod_time: Timestamp,

pub fn getExt(self: Self) FileExtensions {
    const idx = mem.lastIndexOf(u8, self.name, ".") orelse return .unknown;
    if (idx == self.name.len - 1) return .unknown;
    const slice = self.name[idx + 1 ..];
    return meta.stringToEnum(FileExtensions, slice) orelse return .unknown;
}

pub fn init(allocator: std.mem.Allocator, file: fs.Dir.Entry, parent: []const u8) !Self {
    const arena = try allocator.create(heap.ArenaAllocator);
    arena.* = heap.ArenaAllocator.init(allocator);
    const arloc = arena.allocator();
    var timestamp = Timestamp.fromUnixMilli(std.time.milliTimestamp());
    if (file.kind == .file) {
        const full_file_path = try std.fmt.allocPrint(allocator, "{s}\\{s}", .{ parent, file.name });
        defer allocator.free(full_file_path);
        log.debug("Opening full file: {s}", .{full_file_path});
        const opened_file = try fs.openFileAbsolute(full_file_path, .{});
        defer opened_file.close();
        const metadata = try opened_file.metadata();
        const ts = @divFloor(metadata.modified(), 1_000_000);
        timestamp = Timestamp.fromUnixMilli(@intCast(ts));
    }
    return .{
        .arena = arena,
        .name = try arloc.dupe(u8, file.name),
        .kind = file.kind,
        .dir = try arloc.dupe(u8, parent),
        .mod_time = timestamp,
    };
}

pub fn deinit(self: Self) void {
    const allocator = self.arena.child_allocator;
    self.arena.deinit();
    allocator.destroy(self.arena);
}

pub const FileExtensions = enum {
    unknown,
    avif,
    bat,
    cs,
    csv,
    css,
    doc,
    docx,
    exe,
    gif,
    html,
    jpg,
    jpeg,
    json,
    jar,
    md,
    mkv,
    mov,
    mp3,
    mp4,
    msi,
    ogg,
    pdf,
    png,
    ppt,
    pptx,
    rar,
    svg,
    ttf,
    torrent,
    txt,
    wav,
    webm,
    webp,
    xml,
    xcf,
    yml,
    @"7z",
    otf,
    xlsx,
    xls,
    zig,
    zip,
};
