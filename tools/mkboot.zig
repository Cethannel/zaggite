const std = @import("std");

const usage =
    \\Usage: ./mkboot disk.img bootloader.bin
;

const SECTOR_SIZE = 512;

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len < 3) {
        std.debug.print("Did not get enough args\n", .{});
        std.debug.print("{s}\n", .{usage});
        return error.TooFewArgs;
    }

    const disk_image_filename = args[1];
    const bootloader_filename = args[2];

    var disk_image_file = try std.fs.cwd().openFile(
        disk_image_filename,
        std.fs.File.OpenFlags{
            .mode = .read_only,
        },
    );

    var data: [SECTOR_SIZE]u8 = undefined;

    var second_stage_sector: usize = 0;

    for (0..10 * 1024 * 1024) |sec| {
        std.log.info("Checking sector: {}", .{sec});
        if (try disk_image_file.readAll(&data) < 2) {
            std.log.err("Failed to find magic bytes", .{});
            return error.NoMagicBytes;
        }

        if (data[0] == 0xF4 and data[1] == 0x1C) {
            std.debug.print("Found MAGIC_BYTES @ sector {}", .{sec});
            second_stage_sector = sec;
            break;
        }
    }

    var bootloader_file = try std.fs.cwd().openFile(
        bootloader_filename,
        std.fs.File.OpenFlags{
            .mode = .read_only,
        },
    );
    defer bootloader_file.close();

    disk_image_file.close();

    disk_image_file = try std.fs.cwd().openFile(
        disk_image_filename,
        std.fs.File.OpenFlags{
            .mode = .write_only,
        },
    );
    defer disk_image_file.close();

    const copy_amount = 0x1C0;

    std.debug.assert( //
        try bootloader_file.copyRangeAll(0, disk_image_file, 0, copy_amount) == copy_amount //
    );
}
