const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .musl,
    });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = false,
        .code_model = .kernel,
    });

    const asmCommand = b.addSystemCommand(&.{"fasm"});

    asmCommand.addFileArg(b.path("src/bootloader.asm"));
    const bootloaderObjectFile = asmCommand.addOutputFileArg("bootloader.o");

    const bootloaderInstall = b.addInstallBinFile(bootloaderObjectFile, "bootloader.bin");
    b.default_step.dependOn(&bootloaderInstall.step);

    const ddCommand = b.addSystemCommand(&.{"dd"});
    ddCommand.addArgs(&.{"if=/dev/zero"});
    const diskImg = ddCommand.addPrefixedOutputFileArg("of=", "disk.img");
    ddCommand.addArgs(&.{ b.fmt("bs={}", .{1024 * 1024}), "count=10" });

    const fdiskCmd = b.addSystemCommand(&.{"fdisk"});
    fdiskCmd.stdin = .{
        .bytes = "g\nn p\n1\n2048\n+8M\nt\n1\nw\n",
    };
    fdiskCmd.addFileArg(diskImg);
    fdiskCmd.step.dependOn(&ddCommand.step);

    const partfs_new = b.dependency("partfs_new", .{});

    const partfs_new_step = b.addRunArtifact(partfs_new.artifact("partfs_new"));
    partfs_new_step.addFileArg(diskImg);
    const mntfile = partfs_new_step.addOutputFileArg("mntDir");
    partfs_new_step.addArg("-o");
    partfs_new_step.addArg("offset=512");

    partfs_new_step.step.dependOn(&fdiskCmd.step);

    // -s 2 -F 16 -n "EFI System" mntDir/p1
    const mkfs = b.addSystemCommand(&.{"mkfs.vfat"});
    mkfs.addArgs(&.{ "-F", "16", "-n", "EFI System" });
    mkfs.addFileArg(mntfile);
    mkfs.step.dependOn(&partfs_new_step.step);

    const funmount_step = b.addSystemCommand(&.{"fusermount"});
    funmount_step.addArg("-u");
    funmount_step.addFileArg(mntfile);

    const mount = b.addSystemCommand(&.{"tools/fusefatfs"});
    mount.addArgs(&.{ "-o", "rw+" });
    mount.addFileArg(mntfile);
    const imgDir = mount.addOutputDirectoryArg("img");
    mount.step.dependOn(&mkfs.step);
    mount.step.dependOn(&partfs_new_step.step);

    const umount_step = b.addSystemCommand(&.{"umount"});
    umount_step.addFileArg(imgDir);
    umount_step.step.dependOn(&mount.step);
    funmount_step.step.dependOn(&umount_step.step);

    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p" });
    const bootDir = imgDir.path(b, "BIOS/BOOT");
    mkdir.addDirectoryArg(bootDir);
    mkdir.addFileInput(imgDir);
    mkdir.step.dependOn(&mount.step);
    umount_step.step.dependOn(&mkdir.step);

    const copy = b.addSystemCommand(&.{"cp"});
    copy.addFileArg(b.path("second.bin"));
    copy.addFileArg(bootDir.path(b, "STAGE2.BIN"));
    copy.step.dependOn(&mkdir.step);
    umount_step.step.dependOn(&copy.step);

    const mkboot = b.addExecutable(.{
        .name = "mkboot",
        .root_source_file = b.path("tools/mkboot.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
    });

    const mkboot_step = b.addRunArtifact(mkboot);
    mkboot_step.addFileArg(diskImg);
    mkboot_step.addFileArg(bootloaderObjectFile);
    mkboot_step.step.dependOn(&fdiskCmd.step);
    mkboot_step.step.dependOn(&asmCommand.step);
    mkboot_step.step.dependOn(&umount_step.step);
    mkboot_step.step.dependOn(&funmount_step.step);
    mkboot_step.step.dependOn(&copy.step);

    const diskInstall = b.addInstallBinFile(diskImg, "disk.img");
    diskInstall.step.dependOn(&mkboot_step.step);
    b.default_step.dependOn(&diskInstall.step);
    b.default_step.dependOn(&fdiskCmd.step);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "zaggite",
        .root_module = exe_mod,
        .use_lld = false,
    });

    b.installArtifact(exe);
}
