const std = @import("std");
const c = @import("c.zig");
const builtin = @import("builtin");
const SDLContext = @import("SDLContext.zig");
const Gameboy = @import("Gameboy.zig");
const Bus = @import("bus.zig").Bus;

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
    try sdl.setDrawColor(0, 0, 0);

    var gb = Gameboy{};
    var main_bus = Bus{ .main_bus = .{} };
    gb.init(&main_bus);

    if (builtin.os.tag == .emscripten) {
        c.emscripten_set_main_loop_arg(emscriptenLoopWrapper, @ptrCast(&sdl), 0, 1);
    } else {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();
        _ = allocator;

        while (running) {
            try runLoop(&sdl);
        }
    }
}

test {
    _ = @import("Cpu.zig");
    _ = @import("cpu/registers.zig");
}
