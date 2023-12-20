const std = @import("std");
const sep_str = std.fs.path.sep_str;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const output_disassembly = b.option(bool, "disassemble", "print instructions to stderr") orelse false;
    const build_options = b.addOptions();
    build_options.addOption(bool, "disassemble", output_disassembly);

    switch (target.getOsTag()) {
        .emscripten => {
            // get emscripten sdk path
            const emsdk = b.env_map.get("EMSDK") orelse return error.EMSDKEnvNotSet;
            const emsdk_inc = b.pathJoin(&.{ emsdk, "upstream/emscripten/cache/sysroot/include" });

            const lib = b.addStaticLibrary(.{
                .name = "retrobyte",
                .root_source_file = .{ .path = "src/main.zig" },
                .link_libc = true,
                .target = target,
                .optimize = optimize,
            });

            lib.addIncludePath(.{ .cwd_relative = emsdk_inc });

            // create cached static lib to link with emcc
            const wf = b.addWriteFiles();
            const lib_bin = wf.addCopyFile(lib.getEmittedBin(), lib.out_lib_filename);

            // create wasm output folder inside .prefix folder
            const wasm_dir = b.getInstallPath(.{ .custom = "wasm" }, "");
            std.fs.cwd().makePath(wasm_dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };

            // emcc link command
            const emcc_output = b.pathJoin(&.{ wasm_dir, "retrobyte.html" });
            const emcc = b.addSystemCommand(&.{"emcc"});
            emcc.addFileArg(lib_bin);
            emcc.addArgs(&.{ "-s", "USE_SDL=2" });
            emcc.addArgs(&.{ "-s", "STACK_SIZE=1048576" }); // 1MB stack size
            emcc.addArgs(&.{ "-o", emcc_output });

            b.getInstallStep().dependOn(&emcc.step);

            // emrun as the run step
            const emrun = b.addSystemCommand(&.{ "emrun", emcc_output });
            emrun.step.dependOn(&emcc.step);
            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&emrun.step);
        },
        else => {
            const exe = b.addExecutable(.{
                .name = "retrobyte",
                .root_source_file = .{ .path = "src/main.zig" },
                .target = target,
                .optimize = optimize,
            });

            if (target.getOsTag() == .linux) {
                exe.linkSystemLibrary("SDL2");
                exe.linkLibC();
            } else {
                const sdl2_dep = b.dependency("SDL2", .{
                    .target = target,
                    .optimize = .ReleaseFast,
                });
                const sdl2 = sdl2_dep.artifact("SDL2");

                exe.linkLibrary(sdl2);
            }

            exe.addOptions("options", build_options);
            b.installArtifact(exe);

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);
        },
    }

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
