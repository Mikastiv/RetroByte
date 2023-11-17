const std = @import("std");
const sep_str = std.fs.path.sep_str;

const emcc_output_dir = "wasm";
const emcc_output_file = "index.html";
const emcc_include_dir = "upstream/emscripten/cache/sysroot/include";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    switch (target.getOsTag()) {
        .emscripten => {
            const emsdk = b.env_map.get("EMSDK") orelse return error.EMSDKEnvNotSet;
            const emsdk_inc = b.pathJoin(&.{ emsdk, emcc_include_dir });

            const lib = b.addStaticLibrary(.{
                .name = "retrobyte",
                .root_source_file = .{ .path = "src/main.zig" },
                .link_libc = true,
                .target = target,
                .optimize = optimize,
            });

            lib.addIncludePath(.{ .cwd_relative = emsdk_inc });
            lib.addIncludePath(.{ .path = "include" });

            const wf = b.addWriteFiles();
            const lib_bin = wf.addCopyFile(lib.getEmittedBin(), lib.out_lib_filename);

            const wasm_dir = b.getInstallPath(.{ .custom = emcc_output_dir }, "");
            std.fs.cwd().makePath(wasm_dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };

            const emcc_output = b.pathJoin(&.{ wasm_dir, emcc_output_file });
            const emcc = b.addSystemCommand(&.{ "emcc", "-s", "USE_SDL=2", "-o", emcc_output });
            emcc.addFileArg(lib_bin);

            b.getInstallStep().dependOn(&emcc.step);

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

            const sdl2_dep = b.dependency("SDL2", .{
                .target = target,
                .optimize = optimize,
            });
            const sdl2 = sdl2_dep.artifact("SDL2");
            exe.linkLibrary(sdl2);

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
