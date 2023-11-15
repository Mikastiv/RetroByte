const std = @import("std");
const c = @import("c.zig");
const builtin = @import("builtin");
const SDLContext = @import("SDLContext.zig");

// fn getRom(allocator: std.mem.Allocator) ![]const u8 {
//     const stderr = std.io.getStdErr().writer();
//     const args = try std.process.argsAlloc(allocator);
//     defer std.process.argsFree(allocator, args);
//     if (args.len != 2) {
//         const basename = std.fs.path.basename(args[0]);
//         try stderr.print("usage: {s} <ROM file>", .{basename});
//         return error.NoArgGiven;
//     }
//     std.log.info("cartridge: {s} \n", .{args[1]});
//     return &.{};
// }

var running = true;

fn runLoop(sdl: *SDLContext) !void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => {
                running = false;
                break;
            },
            c.SDL_KEYDOWN => {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => {
                        running = false;
                        break;
                    },
                    else => {},
                }
            },
            else => {},
        }
    }

    try sdl.clearFramebuffer();
    try sdl.renderCopy();
    sdl.renderPresent();
}

fn emscriptenLoopWrapper(arg: ?*anyopaque) callconv(.C) void {
    std.debug.assert(arg != null);
    const sdl: *SDLContext = @ptrCast(@alignCast(arg.?));

    runLoop(sdl) catch @panic("loop error");
}

pub fn main() !void {
    if (builtin.os.tag == .emscripten) {
        var sdl = SDLContext.init("RetroByte", 800, 600) catch |err| {
            std.log.err("{s}", .{@errorName(err)});
            return;
        };
        // defer sdl.deinit();

        sdl.setDrawColor(0, 0, 0) catch return;

        c.emscripten_set_main_loop_arg(emscriptenLoopWrapper, @ptrCast(&sdl), 0, 1);
    } else {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        _ = allocator;

        var sdl = try SDLContext.init("RetroByte", 800, 600);
        defer {
            if (builtin.os.tag != .windows) sdl.deinit(); // No deinit on fucking windows because it's too slow. Later looser.
        }

        try sdl.setDrawColor(0, 0, 0);

        while (running) {
            try runLoop(&sdl);
        }
    }
}

test {
    _ = @import("Cpu.zig");
}
