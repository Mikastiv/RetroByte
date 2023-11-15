const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    switch (target.getOsTag()) {
        .emscripten => {
            const emsdk = try std.process.getEnvVarOwned(b.allocator, "EMSDK");
            defer b.allocator.free(emsdk);
            const emsdk_inc = try std.mem.join(b.allocator, "/", &.{ emsdk, "upstream/emscripten/cache/sysroot/include" });
            defer b.allocator.free(emsdk_inc);

            const lib = b.addStaticLibrary(.{
                .name = "retrobyte",
                .root_source_file = .{ .path = "src/main.zig" },
                .target = target,
                .optimize = optimize,
            });

            lib.linkLibC();
            lib.addIncludePath(.{ .cwd_relative = emsdk_inc });
            lib.addIncludePath(.{ .path = "include" });
            b.installArtifact(lib);
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
