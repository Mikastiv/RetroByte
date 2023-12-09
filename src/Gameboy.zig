const std = @import("std");
const cpu = @import("cpu.zig");
const rom = @import("rom.zig");

pub const screen_width = 160;
pub const screen_height = 144;

pub const Frame = struct {
    pixels: [size]u8 = std.mem.zeroes([size]u8),

    pub const Color = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    pub const width = screen_width;
    pub const height = screen_height;
    pub const size = width * height * @sizeOf(Color);

    pub fn putPixel(self: *Frame, x: usize, y: usize, c: Color) void {
        comptime std.debug.assert(@sizeOf(Color) == 3);

        const index = (y * width * @sizeOf(Color)) + (x * @sizeOf(Color));
        self.pixels[index] = c.r;
        self.pixels[index + 1] = c.g;
        self.pixels[index + 2] = c.b;
    }

    pub fn clear(self: *Frame) void {
        self.pixels = std.mem.zeroes([size]u8);
    }
};

pub fn init(allocator: std.mem.Allocator, rom_filepath: []const u8) !void {
    const file = try std.fs.cwd().openFile(rom_filepath, .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    rom.init(bytes);
    cpu.init();

    try rom.printHeader();
}
