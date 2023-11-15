const Self = @This();
const std = @import("std");
const c = @import("c.zig");
const Gameboy = @import("Gameboy.zig");

const SDLError = error{
    SDLInitFailed,
    SDLWindowCreationFailed,
    SDLRendererCreationFailed,
    SDLTextureCreationFailed,
    SDLSetDrawColorFailed,
    SDLClearFramebufferFailed,
    SDLTextureLockFailed,
    SDLRenderCopyFailed,
};

fn printSDLError(comptime caller: []const u8) void {
    std.log.err("fn {s}: {s}", .{ caller, c.SDL_GetError() });
}

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,
backbuffer: *c.SDL_Texture,

pub fn init(
    window_title: [:0]const u8,
    window_width: u32,
    window_height: u32,
) SDLError!Self {
    errdefer printSDLError(@src().fn_name);

    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0)
        return error.SDLInitFailed;

    const window = c.SDL_CreateWindow(
        window_title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        @intCast(window_width),
        @intCast(window_height),
        0,
    ) orelse {
        return error.SDLWindowCreationFailed;
    };

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        return error.SDLRendererCreationFailed;
    };

    const texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_RGB24,
        c.SDL_TEXTUREACCESS_STREAMING,
        Gameboy.screen_width,
        Gameboy.screen_height,
    ) orelse {
        return error.SDLTextureCreationFailed;
    };

    return .{
        .window = window,
        .renderer = renderer,
        .backbuffer = texture,
    };
}

pub fn deinit(self: Self) void {
    c.SDL_DestroyTexture(self.backbuffer);
    c.SDL_DestroyRenderer(self.renderer);
    c.SDL_DestroyWindow(self.window);
    c.SDL_Quit();
}

pub fn setDrawColor(self: Self, r: u8, g: u8, b: u8) SDLError!void {
    if (c.SDL_SetRenderDrawColor(self.renderer, r, g, b, c.SDL_ALPHA_OPAQUE) < 0) {
        printSDLError(@src().fn_name);
        return error.SDLSetDrawColorFailed;
    }
}

pub fn clearFramebuffer(self: Self) SDLError!void {
    if (c.SDL_RenderClear(self.renderer) < 0) {
        printSDLError(@src().fn_name);
        return error.SDLClearFramebufferFailed;
    }
}

pub fn copyToBackbuffer(self: Self, frame: *const Gameboy.Frame) !void {
    var pixel_ptr: ?*anyopaque = undefined;
    var pitch: c_int = undefined;
    if (c.SDL_LockTexture(self.backbuffer, null, &pixel_ptr, &pitch) < 0) {
        errdefer printSDLError(@src().fn_name);
        return error.SDLTextureLockFailed;
    }

    const ptr: [*]u8 = @ptrCast(pixel_ptr);
    const pixels = ptr[0..Gameboy.Frame.size];

    for (0..Gameboy.Frame.size) |i| {
        pixels[i] = frame.pixels[i];
    }

    c.SDL_UnlockTexture(self.backbuffer);
}

pub fn renderCopy(self: Self) SDLError!void {
    if (c.SDL_RenderCopy(self.renderer, self.backbuffer, null, null) < 0) {
        printSDLError(@src().fn_name);
        return error.SDLRenderCopyFailed;
    }
}

pub fn renderPresent(self: Self) void {
    c.SDL_RenderPresent(self.renderer);
}
