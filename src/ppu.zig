const std = @import("std");
const Gameboy = @import("Gameboy.zig");
const interrupts = @import("interrupts.zig");

const OamEntry = struct {
    y: u8,
    x: u8,
    tile: u8,
    attr: packed struct {
        cgb_palette: u3,
        cgb_bank: u1,
        dmg_palette: u1,
        x_flip: u1,
        y_flip: u1,
        priority: u1,
    },
};

const dots_per_line = 456;
const lines_per_frame = 154;

const oam_size = 40;
const vram_size = 0x2000;
const vram_mask = vram_size - 1;

var oam: [oam_size]OamEntry = undefined;
var vram: [vram_size]u8 = undefined;

var framebuffers: [2]Gameboy.Frame = undefined;

var line_dot: u32 = undefined;

const colors = [4]u24{ 0xFFFFFF, 0xAAAAAA, 0x555555, 0x000000 };

const Control = packed union {
    bit: packed struct {
        bgw_on: bool,
        obj_on: bool,
        obj_size: bool,
        bg_map: bool,
        bgw_data: bool,
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

    fn bgwTileDataArea(self: @This()) u16 {
        return if (self.bit.bgw_data) 0x8000 else 0x8800;
    }

    fn winTileMapArea(self: @This()) u16 {
        return if (self.bit.window_map) 0x9C00 else 0x9800;
    }
};

const Mode = enum(u2) {
    hblank = 0,
    vblank = 1,
    oam_scan = 2,
    pixel_transfer = 3,
};

const Stat = packed union {
    bit: packed struct {
        mode: Mode,
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

pub var regs: Registers = undefined;
var bg_colors: [4]u24 = undefined;
var obj_colors: [2][4]u24 = undefined;
var fetcher: Fetcher = undefined;
var fifo: Fifo = undefined;

pub fn init() void {
    framebuffers[0].clear();
    framebuffers[1].clear();
    oam = std.mem.zeroes(@TypeOf(oam));
    line_dot = 0;

    regs = .{};
    regs.stat.bit.mode = .oam_scan;

    fetcher = .{};
    fifo = .{};

    for (colors, 0..) |color, i| {
        bg_colors[i] = color;
        obj_colors[0][i] = color;
        obj_colors[1][i] = color;
    }
}

fn validateOamAddress(addr: u16) void {
    std.debug.assert(addr >= 0x00 and addr <= 0x9F);
}

pub fn oamRead(addr: u16) u8 {
    validateOamAddress(addr);
    const ptr: [*]const u8 = @ptrCast(@alignCast(&oam));
    return ptr[addr];
}

pub fn oamWrite(addr: u16, data: u8) void {
    validateOamAddress(addr);
    const ptr: [*]u8 = @ptrCast(@alignCast(&oam));
    ptr[addr] = data;
}

fn validateVramAddress(addr: u16) void {
    std.debug.assert(addr >= 0x8000 and addr <= 0x9FFF);
}

pub fn vramRead(addr: u16) u8 {
    // TODO: return 0xFF during drawing mode
    validateVramAddress(addr);
    return vram[addr & vram_mask];
}

pub fn vramWrite(addr: u16, data: u8) void {
    validateVramAddress(addr);
    vram[addr & vram_mask] = data;
}

pub fn tick() void {
    line_dot += 1;

    switch (regs.stat.bit.mode) {
        .hblank => hblankTick(),
        .vblank => vblankTick(),
        .oam_scan => oamScanTick(),
        .pixel_transfer => pixelTransferTick(),
    }
}

fn oamScanTick() void {
    if (line_dot >= 80) regs.stat.bit.mode = .pixel_transfer;
}

fn pixelTransferTick() void {
    fetcher.tick();
    if (line_dot >= 80 + 172) {
        // TODO: interrupt 1 cycle before switch to hblank
        regs.stat.bit.mode = .hblank;
    }
}

fn hblankTick() void {
    if (line_dot >= dots_per_line) {
        line_dot = 0;
        incrementLy();
        if (regs.ly >= Gameboy.screen_height) {
            regs.stat.bit.mode = .vblank;
            interrupts.request(.vblank);
            if (regs.stat.bit.vblank_int) {
                interrupts.request(.stat);
            }
        } else {
            regs.stat.bit.mode = .oam_scan;
        }
    }
}

fn vblankTick() void {
    if (line_dot >= dots_per_line) {
        line_dot = 0;
        incrementLy();
        if (regs.ly == lines_per_frame) {
            regs.stat.bit.mode = .oam_scan;
            regs.ly = 0;
        }
    }
}

fn validateAddress(addr: u16) void {
    std.debug.assert(addr >= 0xFF40 and addr <= 0xFF4B and addr != 0xFF46);
}

pub fn read(addr: u16) u8 {
    validateAddress(addr);
    return switch (addr) {
        0xFF40 => regs.ctrl.raw,
        0xFF41 => regs.stat.raw & 0x7F,
        0xFF42 => regs.scy,
        0xFF43 => regs.scx,
        0xFF44 => regs.ly,
        0xFF45 => regs.lyc,
        0xFF47 => regs.bg_pal,
        0xFF48, 0xFF49 => regs.obj_pal[addr & 1],
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
        0xFF40 => regs.ctrl.raw = data,
        0xFF41 => regs.stat.raw = (regs.stat.raw & 0x07) | (data & 0x78),
        0xFF42 => regs.scy = data,
        0xFF43 => regs.scx = data,
        0xFF45 => regs.lyc = data,
        0xFF47 => updatePalette(data, .bg),
        0xFF48 => updatePalette(data & 0xFC, .obj0),
        0xFF49 => updatePalette(data & 0xFC, .obj1),
        else => {},
    }
}

fn incrementLy() void {
    regs.ly += 1;
    if (regs.ly == regs.lyc) {
        regs.stat.bit.match_flag = true;
        if (regs.stat.bit.match_int) {
            interrupts.request(.stat);
        }
    } else {
        regs.stat.bit.match_flag = false;
    }
}

const Fetcher = struct {
    const State = enum { tile, data0, data1, idle, push };

    state: State = .tile,
    x: u32 = 0,
    map_x: u32 = 0,
    map_y: u32 = 0,
    tile_y: u32 = 0,
    tile: u8 = 0,
    byte0: u8 = 0,
    byte1: u8 = 0,

    fn tick(self: *@This()) void {
        self.map_x = regs.scx + self.x;
        self.map_y = regs.ly + regs.scy;
        self.tile_y = (self.map_y % 8) * 2;
        switch (self.state) {
            .tile => if (line_dot & 1 == 0) {
                if (regs.ctrl.bit.bgw_on) {
                    // TODO: change impl when adding vram blocking
                    self.tile = vramRead(regs.ctrl.bgTileMapArea() + self.map_x / 8 + self.map_y / 8 * 32); // 32 tiles per row
                    // tiles start at 128 if lcdc.4 is off
                    if (!regs.ctrl.bit.bgw_data) self.tile += 128;
                }
                self.state = .data0;
                self.x += 8;
            },
            .data0 => if (line_dot & 1 == 0) {
                // TODO: change impl when adding vram blocking
                self.byte0 = vramRead(regs.ctrl.bgwTileDataArea() + self.tile * 16 + self.tile_y);
                self.state = .data1;
            },
            .data1 => if (line_dot & 1 == 0) {
                // TODO: change impl when adding vram blocking
                self.byte1 = vramRead(regs.ctrl.bgwTileDataArea() + self.tile * 16 + self.tile_y + 1);
                self.state = .idle;
            },
            .idle => if (line_dot & 1 == 0) {
                self.state = .push;
            },
            .push => if (fifo.addPixels()) {
                self.state = .tile;
            },
        }
    }
};

const Fifo = struct {
    size: u8 = 0,

    fn addPixels(self: @This()) bool {
        return self.size < 8;
    }
};
