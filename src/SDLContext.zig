const Self = @This();
const std = @import("std");
const c = @import("c.zig");
const bus = @import("bus.zig");
const Gameboy = @import("Gameboy.zig");

const SDLError = error{
    SDLInitFailed,
    SDLWindowCreationFailed,
    SDLRendererCreationFailed,
    SDLTextureCreationFailed,
    SDLSetDrawColorFailed,
    SDLRenderClearFailed,
    SDLTextureLockFailed,
    SDLRenderCopyFailed,
    SDLSurfaceCreationFailed,
    SDLFillRectFailed,
    SDLTextureUpdateFailed,
};

fn printSDLError(comptime caller: []const u8) void {
    std.log.err("fn {s}: {s}", .{ caller, c.SDL_GetError() });
}

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,
texture: *c.SDL_Texture,

debug_window: *c.SDL_Window,
debug_renderer: *c.SDL_Renderer,
debug_texture: *c.SDL_Texture,
debug_surface: *c.SDL_Surface,

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

    const debug_window = c.SDL_CreateWindow(
        "Tiles debug",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        @intCast(window_width),
        @intCast(window_height),
        0,
    ) orelse {
        return error.SDLRendererCreationFailed;
    };

    const debug_renderer = c.SDL_CreateRenderer(debug_window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        return error.SDLRendererCreationFailed;
    };

    const debug_texture = c.SDL_CreateTexture(
        debug_renderer,
        c.SDL_PIXELFORMAT_RGB24,
        c.SDL_TEXTUREACCESS_STREAMING,
        16 * 8,
        24 * 8,
    ) orelse {
        return error.SDLTextureCreationFailed;
    };

    const debug_surface = c.SDL_CreateRGBSurface(0, 16 * 8, 24 * 8, 24, 0x00FF0000, 0x0000FF00, 0x000000FF, 0) orelse {
        return error.SDLSurfaceCreationFailed;
    };

    var x: i32 = undefined;
    var y: i32 = undefined;
    c.SDL_GetWindowPosition(window, &x, &y);
    c.SDL_SetWindowPosition(debug_window, x + @as(i32, @intCast(window_width)), y);

    if (c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE) < 0)
        return error.SDLRenderClearFailed;
    if (c.SDL_SetRenderDrawColor(debug_renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE) < 0)
        return error.SDLRenderClearFailed;

    return .{
        .window = window,
        .renderer = renderer,
        .texture = texture,
        .debug_window = debug_window,
        .debug_renderer = debug_renderer,
        .debug_texture = debug_texture,
        .debug_surface = debug_surface,
    };
}

pub fn deinit(self: Self) void {
    c.SDL_DestroyTexture(self.texture);
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
        return error.SDLRenderClearFailed;
    }
}

pub fn copyToBackbuffer(self: Self, frame: *const Gameboy.Frame) !void {
    var pixel_ptr: ?*anyopaque = undefined;
    var pitch: c_int = undefined;
    if (c.SDL_LockTexture(self.texture, null, &pixel_ptr, &pitch) < 0) {
        errdefer printSDLError(@src().fn_name);
        return error.SDLTextureLockFailed;
    }

    const ptr: [*]u8 = @ptrCast(pixel_ptr);
    const pixels = ptr[0..Gameboy.Frame.size];

    for (0..Gameboy.Frame.size) |i| {
        pixels[i] = frame.pixels[i];
    }

    c.SDL_UnlockTexture(self.texture);
}

pub fn renderCopy(self: Self) SDLError!void {
    if (c.SDL_RenderCopy(self.renderer, self.texture, null, null) < 0) {
        printSDLError(@src().fn_name);
        return error.SDLRenderCopyFailed;
    }
}

pub fn renderPresent(self: Self) void {
    c.SDL_RenderPresent(self.renderer);
}

const tile_colors = [4]u24{ 0xFFFFFF, 0xAAAAAA, 0x555555, 0x000000 };

fn displayTile(surface: *c.SDL_Surface, tile_num: u16, x: i32, y: i32) !void {
    var rect: c.SDL_Rect = undefined;
    rect.w = 1;
    rect.h = 1;

    var tile_y: u16 = 0;
    while (tile_y < 16) : (tile_y += 2) {
        var lo = bus.peek(0x8000 + (tile_num * 16) + tile_y);
        var hi = bus.peek(0x8000 + (tile_num * 16) + tile_y + 1);

        for (0..8) |bit| {
            const l: u2 = @intCast(lo & 1);
            const h: u2 = @intCast(hi & 1);
            const color = h << 1 | l;

            lo >>= 1;
            hi >>= 1;

            rect.x = x + (7 - @as(i32, @intCast(bit)));
            rect.y = y + @divTrunc(@as(i32, @intCast(tile_y)), 2);

            if (c.SDL_FillRect(surface, &rect, tile_colors[color]) < 0)
                return error.SDLFillRectFailed;
        }
    }
}

pub fn updateDebugWindow(self: Self) SDLError!void {
    var rect = c.SDL_Rect{ .x = 0, .y = 0, .w = self.debug_surface.w, .h = self.debug_surface.h };
    if (c.SDL_FillRect(self.debug_surface, &rect, 0x111111) < 0)
        return error.SDLFillRectFailed;

    const addr = 0x8000;
    _ = addr;

    var x_draw: i32 = 0;
    var y_draw: i32 = 0;
    var tile_num: u16 = 0;
    // 384 tiles, 24 x 16
    for (0..24) |y| {
        _ = y;
        for (0..16) |x| {
            _ = x;
            try displayTile(self.debug_surface, tile_num, x_draw, y_draw);
            // display tile
            x_draw += 8;
            tile_num += 1;
        }
        x_draw = 0;
        y_draw += 8;
    }
    if (c.SDL_UpdateTexture(self.debug_texture, null, self.debug_surface.pixels, self.debug_surface.pitch) < 0)
        return error.SDLTextureUpdateFailed;
    if (c.SDL_RenderClear(self.debug_renderer) < 0)
        return error.SDLRenderClearFailed;
    if (c.SDL_RenderCopy(self.debug_renderer, self.debug_texture, null, null) < 0)
        return error.SDLRenderCopyFailed;
    c.SDL_RenderPresent(self.debug_renderer);
}
