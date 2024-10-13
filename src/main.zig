const std = @import("std");
const log = std.log;
const fs = std.fs;
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;
const Timestamp = @import("Timestamp.zig");
const FileInfo = @import("FileInfo.zig");

pub fn main() !void {
    const ts = Timestamp.fromUnixMilli(std.time.milliTimestamp());
    log.info("-- {d}.{d}.{d} --", .{ ts.year, ts.month, ts.day });
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    var list = std.ArrayList(FileInfo).init(allocator);
    defer list.deinit();

    _ = try readFiles(allocator, &list,
        \\D:\HDD Downloads
    );

    for (list.items) |file| {
        if (file.kind == .directory) {
            log.info("{s} -> {s}", .{ file.dir, file.name });
            continue;
        }
        log.info("name: {s}, dir: {s}, ts: {any}", .{ file.name, file.dir, file.mod_time });
    }

    arrangeFiles(allocator, &list);
}

const FolderWhitelist = [_][]const u8{
    "Folders",
    "Archives",
    "Audio",
    "Documents",
    "Executables",
    "GimpProjects",
    "Images",
    "Raw",
    "Code",
    "Sites",
    "Videos",
    "Fonts",
    "Torrents",
    "Other",
    "Save_webP",
};
fn arrangeFiles(allocator: mem.Allocator, list: *std.ArrayList(FileInfo)) void {
    var dir = fs.openDirAbsolute("D:\\HDD Downloads", .{ .iterate = true }) catch |err| {
        log.err("Could not open downloads folder!! ({})", .{err});
        std.time.sleep(5 * 1_000 * 1_000_000);
        return;
    };
    defer dir.close();

    files_loop: for (list.items) |file| {
        defer file.deinit();
        var dest: []const u8 = undefined;
        if (file.kind == .directory) {
            for (FolderWhitelist) |whitelisted_folder| {
                if (mem.eql(u8, file.name, whitelisted_folder)) {
                    continue :files_loop;
                }
            }
            dest = "Folders";
        } else {
            switch (file.getExt()) {
                .zip, .@"7z", .rar => dest = "Archives",
                .mp3, .wav, .ogg => dest = "Audio",
                .pdf, .doc, .docx, .ppt, .pptx => dest = "Documents",
                .exe, .msi, .jar, .bat => dest = "Executables",
                .xcf => dest = "GimpProjects",
                .jpg, .jpeg, .png, .gif, .webp, .avif, .svg => dest = "Images",
                .txt, .yml, .json, .csv, .xml => dest = "Raw",
                .cs, .zig => dest = "Code",
                .html, .css => dest = "Sites",
                .mp4, .mkv, .mov, .webm => dest = "Videos",
                .ttf, .otf => dest = "Fonts",
                .torrent => dest = "Torrents",
                .unknown => dest = "Other",
            }
        }

        var destDir = dir.openDir(dest, .{}) catch |err| {
            log.err("Category folder probably missing: {s} ({})", .{ dest, err });
            std.time.sleep(5 * 1_000 * 1_000_000);
            continue;
        };
        defer destDir.close();

        const monthDirPath = fmt.allocPrint(allocator, "{d}-{d}", .{ file.mod_time.year, file.mod_time.month }) catch {
            log.err("Allocation failed for file {s}", .{file.name});
            std.time.sleep(5 * 1_000 * 1_000_000);
            continue;
        };
        defer allocator.free(monthDirPath);

        var monthDir = destDir.openDir(monthDirPath, .{}) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied, error.BadPathName => blk: {
                break :blk destDir.makeOpenPath(monthDirPath, .{}) catch {
                    log.err("Could not make this month's directory ({s}) for {s}", .{ monthDirPath, file.name });
                    std.time.sleep(5 * 1_000 * 1_000_000);
                    @panic("");
                };
            },
            else => {
                log.err(
                    "Could not move file {s}: Destination directory could not be opened ({})",
                    .{ file.name, err },
                );
                std.time.sleep(5 * 1_000 * 1_000_000);
                continue;
            },
        };
        defer monthDir.close();

        log.info("Moving {s} from downloads to {s}\\{s}", .{ file.name, dest, monthDirPath });
        if (file.kind == .directory) {
            var dir_to_move = dir.openDir(file.name, .{ .iterate = true }) catch |err| {
                log.err("Could not open directory that needs moving {s} ({s})", .{ file.name, @errorName(err) });
                std.time.sleep(5 * 1_000 * 1_000_000);
                continue;
            };
            defer dir_to_move.close();
            var dir_in_monthDir = monthDir.makeOpenPath(file.name, .{}) catch |err| {
                log.err("Failed to create directory in monthDir {s} ({s})", .{ file.name, @errorName(err) });
                std.time.sleep(5 * 1_000 * 1_000_000);
                continue;
            };
            defer dir_in_monthDir.close();
            moveDir(allocator, dir_to_move, dir_in_monthDir) catch |err| {
                log.err("Failed to move directory {s} ({s})", .{ file.name, @errorName(err) });
                std.time.sleep(5 * 1_000 * 1_000_000);
                continue;
            };
        } else {
            copyFileRenameIfExists(allocator, dir, file.name, monthDir, file.name) catch |err| {
                log.err("Moving file failed ({s})", .{@errorName(err)});
                std.time.sleep(5 * 1_000 * 1_000_000);
                continue;
            };
        }
        dir.deleteTree(file.name) catch |err| {
            log.err("Delete file failed ({s})", .{@errorName(err)});
            std.time.sleep(5 * 1_000 * 1_000_000);
            continue;
        };
    }
}

fn moveDir(allocator: mem.Allocator, dir: fs.Dir, dest: fs.Dir) !void {
    var iterator = dir.iterate();
    while (try iterator.next()) |item| {
        if (item.kind == .directory) {
            var subDir = try dir.openDir(item.name, .{ .iterate = true });
            defer subDir.close();
            var subDestDir = try dest.makeOpenPath(item.name, .{});
            defer subDestDir.close();
            try moveDir(allocator, subDir, subDestDir);
            try dir.deleteTree(item.name);
            continue;
        }

        try copyFileRenameIfExists(allocator, dir, item.name, dest, item.name);
        try dir.deleteTree(item.name);
    }
}

fn copyFileRenameIfExists(
    allocator: mem.Allocator,
    srcDir: fs.Dir,
    srcFile: []const u8,
    destDir: fs.Dir,
    destFile: []const u8,
) !void {
    const exists = dup_check: {
        destDir.access(destFile, .{}) catch break :dup_check false;
        log.warn("copyFileRenameIfExists: file {s} exists in destDir", .{destFile});
        break :dup_check true;
    };
    if (!exists) {
        log.info("copyFileRenameIfExists: copying file {s} to destDir", .{destFile});
        try srcDir.copyFile(srcFile, destDir, destFile, .{});
        return;
    }

    var newName = try allocator.alloc(u8, destFile.len + 2);
    defer allocator.free(newName);
    @memcpy(newName[0..2], "d_");
    @memcpy(newName[2..], destFile);
    try copyFileRenameIfExists(allocator, srcDir, srcFile, destDir, newName);
}

fn readFiles(allocator: mem.Allocator, list: *std.ArrayList(FileInfo), path: []const u8) !usize {
    var read: usize = 0;
    var dir = try fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();
    var iterator = dir.iterate();
    while (try iterator.next()) |file| {
        const info = try FileInfo.init(allocator, file, path);
        try list.append(info);
        read += 1;
    }

    return read;
}
