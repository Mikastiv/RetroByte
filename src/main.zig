const std = @import("std");
const c = @import("c.zig");
const builtin = @import("builtin");
const SDLContext = @import("SDLContext.zig");
const Gameboy = @import("Gameboy.zig");

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

    Gameboy.step();
    std.time.sleep(std.time.ns_per_ms * 250);

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

pub fn main() !u8 {
    const stderr = std.io.getStdErr().writer();

    var sdl = try SDLContext.init("RetroByte", 800, 600);
    try sdl.setDrawColor(0, 0, 0);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);

    if (args.len != 2) {
        try stderr.print("usage: {s} <rom file>\n", .{args[0]});
        return 1;
    }

    try Gameboy.init(allocator, args[1]);

    if (builtin.os.tag == .emscripten) {
        c.emscripten_set_main_loop_arg(emscriptenLoopWrapper, @ptrCast(&sdl), 0, 1);
    } else {
        while (running) {
            try runLoop(&sdl);
        }
    }

    return 0;
}

test {
    _ = @import("cpu.zig");
    _ = @import("registers.zig");
}
