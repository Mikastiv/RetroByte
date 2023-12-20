const std = @import("std");
const cpu = @import("cpu.zig");
const rom = @import("rom.zig");
const debug = @import("debug.zig");
const bus = @import("bus.zig");
const joypad = @import("joypad.zig");
const timer = @import("timer.zig");
const ppu = @import("ppu.zig");
const dma = @import("dma.zig");

pub const screen_width = 160;
pub const screen_height = 144;

pub const Frame = struct {
    pixels: [size]u8,

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
        @memset(&self.pixels, 0);
    }
};

pub fn init(allocator: std.mem.Allocator, rom_filepath: []const u8) !void {
    const file = try std.fs.cwd().openFile(rom_filepath, .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    rom.init(bytes);
    cpu.init();
    bus.init();
    timer.init();
    joypad.init();
    debug.init();
    ppu.init();
    dma.init();

    time = try std.time.Timer.start();

    try rom.printHeader();
}

pub fn step() void {
    _ = cpu.step();
}

var time: std.time.Timer = undefined;
pub fn run(running: *const bool) void {
    time.reset();
    while (running.*) {
        const current = ppu.currentFrame();
        _ = cpu.step();
        // TODO: better timing code (windows sleep is not accurate)
        if (current != ppu.currentFrame()) {
            const elapsed_ns = time.read();
            const expected_ns = 16750419; // 59.7 fps
            if (expected_ns > elapsed_ns) std.time.sleep(expected_ns - elapsed_ns);
            time.reset();
        }
    }
}

pub fn frame() *const Frame {
    return ppu.currentFrame();
}
