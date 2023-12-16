const std = @import("std");

const colors = [4]u24{ 0xFFFFFF, 0xAAAAAA, 0x555555, 0x000000 };

const Control = packed union {
    bit: packed struct {
        bg_on: bool,
        obj_on: bool,
        obj_size: bool,
        bg_map: bool,
        bg_win_data: bool,
        win_on: bool,
        win_map: bool,
        lcd_on: bool,
    },
    raw: u8,

    fn objSize(self: @This()) u8 {
        return if (self.bit.obj_size) 16 else 8;
    }

    fn bgTileMapArea(self: @This()) u16 {
        return if (self.bit.bg_map) 0x9C00 else 0x9800;
    }

    fn bgWinTileDataArea(self: @This()) u16 {
        return if (self.bit.bg_win_data) 0x8000 else 0x8800;
    }

    fn winTileMapArea(self: @This()) u16 {
        return if (self.bit.window_map) 0x9C00 else 0x9800;
    }
};

const PpuMode = enum(u2) {
    hblank = 0,
    vblank = 1,
    oam_scan = 2,
    drawing = 3,
};

const Stat = packed union {
    bit: packed struct {
        ppu_mode: PpuMode,
        match_flag: bool,
        hblank_int: bool,
        vblank_int: bool,
        oam_int: bool,
        match_int: bool,
    },
    raw: u8,
};

const Registers = struct {
    ctrl: Control = .{ .raw = 0 },
    stat: Stat = .{ .raw = 0 },
    scy: u8 = 0,
    scx: u8 = 0,
    ly: u8 = 0,
    lyc: u8 = 0,
    bg_pal: u8 = 0xFC,
    obj_pal: [2]u8 = .{ 0xFF, 0xFF },
    win_y: u8 = 0,
    win_x: u8 = 0,
};

var registers: Registers = undefined;
var bg_colors: [4]u24 = undefined;
var obj_colors: [2][4]u24 = undefined;

pub fn init() void {
    registers = .{};

    for (colors, 0..) |color, i| {
        bg_colors[i] = color;
        obj_colors[0][i] = color;
        obj_colors[1][i] = color;
    }
}

fn validateAddress(addr: u16) void {
    std.debug.assert(addr >= 0xFF40 and addr <= 0xFF4B and addr != 0xFF46);
}

pub fn read(addr: u16) u8 {
    validateAddress(addr);
    return switch (addr) {
        0xFF40 => registers.ctrl.raw,
        0xFF41 => registers.stat.raw & 0x7F,
        0xFF42 => registers.scy,
        0xFF43 => registers.scx,
        0xFF44 => registers.ly,
        0xFF45 => registers.lyc,
        0xFF47 => registers.bg_pal,
        0xFF48, 0xFF49 => registers.obj_pal[addr & 1],
        else => 0,
    };
}

const Palette = enum { bg, obj0, obj1 };

fn updatePalette(data: u8, comptime palette: Palette) void {
    var ptr: *[4]u24 = undefined;
    switch (palette) {
        .bg => ptr = &bg_colors,
        .obj0 => ptr = &obj_colors[0],
        .obj1 => ptr = &obj_colors[1],
    }

    ptr[0] = colors[data & 0x3];
    ptr[1] = colors[data >> 2 & 0x3];
    ptr[2] = colors[data >> 4 & 0x3];
    ptr[3] = colors[data >> 6 & 0x3];
}

pub fn write(addr: u16, data: u8) void {
    validateAddress(addr);
    switch (addr) {
        0xFF40 => registers.ctrl.raw = data,
        0xFF41 => registers.stat.raw = (registers.stat.raw & 0x07) | (data & 0x78),
        0xFF42 => registers.scy = data,
        0xFF43 => registers.scx = data,
        0xFF45 => registers.lyc = data,
        0xFF47 => updatePalette(data, .bg),
        0xFF48 => updatePalette(data & 0xFC, .obj0),
        0xFF49 => updatePalette(data & 0xFC, .obj1),
        else => {},
    }
}
