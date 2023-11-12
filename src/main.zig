const std = @import("std");
const c = @import("c.zig");
const builtin = @import("builtin");

const SDLError = error{
    SDLInitFailed,
    SDLWindowCreationFailed,
    SDLRendererCreationFailed,
    SDLSetDrawColorFailed,
    SDLClearFramebufferFailed,
};

const SDLContext = struct {
    const Self = @This();

    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,

    fn init(
        window_title: [:0]const u8,
        window_width: u32,
        window_height: u32,
    ) SDLError!Self {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
            std.log.err("failed to initialize SDL: {s}", .{c.SDL_GetError()});
            return error.SDLInitFailed;
        }

        const window = c.SDL_CreateWindow(
            window_title,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            @intCast(window_width),
            @intCast(window_height),
            0,
        ) orelse {
            std.log.err("failed to create window: {s}", .{c.SDL_GetError()});
            return error.SDLWindowCreationFailed;
        };

        const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
            std.log.err("failed to create renderer: {s}", .{c.SDL_GetError()});
            return error.SDLRendererCreationFailed;
        };

        return .{
            .window = window,
            .renderer = renderer,
        };
    }

    fn deinit(self: Self) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    fn setDrawColor(self: Self) SDLError!void {
        if (c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE) < 0) {
            std.log.err("failed to set draw color: {s}", .{c.SDL_GetError()});
            return error.SDLSetDrawColorFailed;
        }
    }

    fn clearFramebuffer(self: Self) SDLError!void {
        if (c.SDL_RenderClear(self.renderer) < 0) {
            std.log.err("failed to clear framebuffer: {s}", .{c.SDL_GetError()});
            return error.SDLClearFramebufferFailed;
        }
    }
};

fn getRom(allocator: std.mem.Allocator) ![]const u8 {
    const stderr = std.io.getStdErr().writer();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        const basename = std.fs.path.basename(args[0]);
        try stderr.print("usage: {s} <ROM file>", .{basename});
        return error.NoArgGiven;
    }
    std.log.info("cartridge: {s} \n", .{args[1]});
    return &.{};
}

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const rom = getRom(allocator);
    _ = rom;
    const sdl = try SDLContext.init("RetroByte", 800, 600);
    defer {
        if (builtin.os.tag != .windows) sdl.deinit(); // No deinit on fucking windows because it's too slow. Later looser.
    }
    try sdl.setDrawColor();
    try run(sdl);
}

fn run(sdl: SDLContext) !void {
    var running = true;
    while (running) {
        try sdl.clearFramebuffer();
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
    }
    return 0;
}
