const std = @import("std");
const c = @import("c.zig");
const builtin = @import("builtin");
const SDLContext = @import("SDLContext.zig");
const Gameboy = @import("Gameboy.zig");

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
var frame = Gameboy.Frame{};
var rng = std.rand.DefaultPrng.init(0);

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

    for (&frame.pixels) |*p| {
        p.* = rng.random().int(u8);
    }

    try sdl.clearFramebuffer();
    try sdl.copyToBackbuffer(&frame);
    try sdl.renderCopy();
    sdl.renderPresent();
}

fn emscriptenLoopWrapper(arg: ?*anyopaque) callconv(.C) void {
    std.debug.assert(arg != null);
    const sdl: *SDLContext = @ptrCast(@alignCast(arg.?));

    runLoop(sdl) catch @panic("loop error");
}

pub fn main() !void {
    var sdl = try SDLContext.init("RetroByte", 800, 600);

    if (builtin.os.tag == .emscripten) {
        // defer sdl.deinit();

        sdl.setDrawColor(0, 0, 0) catch return;

        c.emscripten_set_main_loop_arg(emscriptenLoopWrapper, @ptrCast(&sdl), 0, 1);
    } else {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        _ = allocator;

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
