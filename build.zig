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
        .os_tag = .uefi,
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

    //const asmCommand = b.addSystemCommand(&.{"nasm"});

    //asmCommand.addArgs(&.{ "-f", "elf32" });
    //const startout = asmCommand.addPrefixedOutputFileArg("-o", "start.o");
    //asmCommand.addFileArg(b.path("src/start.asm"));

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "zaggite",
        .root_module = exe_mod,
        .use_lld = false,
    });

    //exe.step.dependOn(&asmCommand.step);

    //exe.linker_script = b.path("src/linker.ld");
    //exe.addObjectFile(startout);

    b.installArtifact(exe);
}
