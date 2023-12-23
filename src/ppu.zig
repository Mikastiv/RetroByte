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
        x_flip: bool,
        y_flip: bool,
        priority: bool,
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
var current_frame: usize = undefined;
var display_frame: usize = undefined;

const colors = [4]Gameboy.Frame.Color{
    .{ .r = 0xFF, .g = 0xFF, .b = 0xFF },
    .{ .r = 0xAA, .g = 0xAA, .b = 0xAA },
    .{ .r = 0x55, .g = 0x55, .b = 0x55 },
    .{ .r = 0x00, .g = 0x00, .b = 0x00 },
};

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
        return if (self.bit.win_map) 0x9C00 else 0x9800;
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
    window_line: u8 = 0,
    current_oam: u8 = 0,
};

pub var regs: Registers = undefined;
var bg_colors: [4]Gameboy.Frame.Color = undefined;
var obj_colors: [2][4]Gameboy.Frame.Color = undefined;
var fetcher: Fetcher = undefined;
var fifo: Fifo = undefined;

var line_dot: u32 = undefined;
var interrupt_line: bool = undefined;
var visible_sprites: [10]OamEntry = undefined;
var visible_sprites_count: u8 = undefined;

pub fn init() void {
    for (&framebuffers) |*buf| {
        buf.clear();
    }
    current_frame = 0;
    display_frame = 1;

    oam = std.mem.zeroes(@TypeOf(oam));
    vram = std.mem.zeroes(@TypeOf(vram));
    visible_sprites = std.mem.zeroes(@TypeOf(visible_sprites));
    visible_sprites_count = 0;
    line_dot = 0;
    interrupt_line = false;

    regs = .{};
    regs.stat.bit.mode = .oam_scan;

    fetcher.reset();
    fifo.reset();

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
    // return 0xFF during oam scan
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

fn processInterruptTrigger(source: bool, comptime mode: Mode) void {
    const check_line: bool = switch (mode) {
        .oam_scan, .vblank => true,
        else => false,
    };

    if (source) {
        if (!(check_line and interrupt_line)) interrupts.request(.stat); // STAT blocking
        interrupt_line = true;
    } else {
        interrupt_line = false;
    }
}

fn oamScanTick() void {
    if (regs.ly == 0 and line_dot == 1) {
        if (regs.stat.bit.oam_int) {
            interrupts.request(.stat);
            interrupt_line = true;
        } else {
            interrupt_line = false;
        }
    }

    if (line_dot & 1 == 0 and visible_sprites_count < 10) {
        const h = regs.ctrl.objSize();
        const idx = regs.current_oam;
        if (regs.ly + 16 >= oam[idx].y and regs.ly + 16 < oam[idx].y + h) {
            visible_sprites[visible_sprites_count] = oam[idx];
            visible_sprites_count += 1;
        }
        regs.current_oam += 1;
    }

    if (line_dot >= 80) {
        regs.stat.bit.mode = .pixel_transfer;
        regs.current_oam = 0;
        fetcher.reset();
        fifo.reset();
        fifo.discard_count = @intCast(regs.scx % 8);
    }
}

fn windowVisible() bool {
    return regs.ctrl.bit.win_on and regs.win_x <= 166 and regs.win_y < Gameboy.screen_height;
}

fn processSprites() void {
    for (0..visible_sprites_count) |i| {
        const entry = visible_sprites[i];
        if (fifo.x == entry.x -% 8) {
            const y = (regs.ly + 16) - entry.y;
            const tile = blk: {
                if (regs.ctrl.objSize() == 16) {
                    const top = if (entry.attr.y_flip) entry.tile | 0x01 else entry.tile & 0xFE;
                    const bot = if (entry.attr.y_flip) entry.tile & 0xFE else entry.tile | 0x01;
                    if (y >= 8)
                        break :blk bot
                    else
                        break :blk top;
                }
                break :blk entry.tile;
            };
            const tile_y = if (entry.attr.y_flip) 7 - y % 8 else y % 8;
            const byte0 = vramRead(0x8000 + @as(u16, tile) * 16 + tile_y * 2);
            const byte1 = vramRead(0x8000 + @as(u16, tile) * 16 + tile_y * 2 + 1);
            fifo.addObjPixels(byte0, byte1, entry);
            break;
        }
    }
}

fn pixelTransferTick() void {
    if (windowVisible() and regs.win_x == fifo.x + 7 and fetcher.area != .win and regs.ly >= regs.win_y) {
        fetcher.switchToWindow();
        fifo.clear();
    }
    if (regs.ctrl.bit.obj_on) processSprites();
    fetcher.tick();
    fifo.push();
    if (fifo.x >= Gameboy.screen_width) {
        // TODO: interrupt 1 cycle before switch to hblank
        regs.stat.bit.mode = .hblank;
        processInterruptTrigger(regs.stat.bit.hblank_int, .hblank);
    }
}

fn hblankTick() void {
    if (line_dot >= dots_per_line) {
        line_dot = 0;
        visible_sprites_count = 0;
        incrementLy();
        if (regs.ly >= Gameboy.screen_height) {
            regs.stat.bit.mode = .vblank;

            current_frame = (current_frame + 1) % framebuffers.len;
            display_frame = (display_frame + 1) % framebuffers.len;

            interrupts.request(.vblank);

            processInterruptTrigger(regs.stat.bit.vblank_int, .vblank);
        } else {
            regs.stat.bit.mode = .oam_scan;
            processInterruptTrigger(regs.stat.bit.oam_int, .oam_scan);
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
            regs.window_line = 0;
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
        0xFF4A => regs.win_y,
        0xFF4B => regs.win_x,
        else => 0,
    };
}

const Palette = enum { bg, obj0, obj1 };

fn updatePalette(data: u8, comptime palette: Palette) void {
    var ptr: *[4]Gameboy.Frame.Color = undefined;
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
        0xFF4A => regs.win_y = data,
        0xFF4B => regs.win_x = data,
        else => {},
    }
}

fn incrementLy() void {
    if (windowVisible() and regs.ly >= regs.win_y) regs.window_line += 1;

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
    const Area = enum { bg, win };

    state: State = .tile,
    area: Area = .bg,
    x: u8 = 0,
    map_x: u8 = 0,
    map_y: u8 = 0,
    tile_y: u8 = 0,
    tile: u8 = 0,
    byte0: u8 = 0,
    byte1: u8 = 0,

    fn tileMapArea(self: *const @This()) u16 {
        return switch (self.area) {
            .bg => regs.ctrl.bgTileMapArea(),
            .win => regs.ctrl.winTileMapArea(),
        };
    }

    fn tick(self: *@This()) void {
        switch (self.area) {
            .bg => {
                self.map_x = (self.x +% (regs.scx / 8)) & 0x1F;
                self.map_y = regs.ly +% regs.scy;
                self.tile_y = self.map_y % 8;
            },
            .win => {
                self.map_x = self.x;
                self.map_y = regs.window_line;
                self.tile_y = self.map_y % 8;
            },
        }

        switch (self.state) {
            .tile => if (line_dot & 1 == 0) {
                if (regs.ctrl.bit.bgw_on) {
                    // TODO: change impl when adding vram blocking
                    self.tile = vramRead(self.tileMapArea() + self.map_x + @as(u16, self.map_y) / 8 * 32); // 32 tiles per row
                    // tiles start at 128 if lcdc.4 is off
                    if (!regs.ctrl.bit.bgw_data) self.tile +%= 128;
                }
                self.x += 1;
                self.state = .data0;
            },
            .data0 => if (line_dot & 1 == 0) {
                // TODO: change impl when adding vram blocking
                self.byte0 = vramRead(regs.ctrl.bgwTileDataArea() + @as(u16, self.tile) * 16 + self.tile_y * 2);
                self.state = .data1;
            },
            .data1 => if (line_dot & 1 == 0) {
                // TODO: change impl when adding vram blocking
                self.byte1 = vramRead(regs.ctrl.bgwTileDataArea() + @as(u16, self.tile) * 16 + self.tile_y * 2 + 1);
                self.state = .idle;
            },
            .idle => if (line_dot & 1 == 0) {
                self.state = .push;
            },
            .push => {
                if (fifo.addPixels(self.byte0, self.byte1))
                    self.state = .tile;
            },
        }
    }

    fn switchToWindow(self: *@This()) void {
        self.x = 0;
        self.area = .win;
        self.state = .tile;
    }

    fn reset(self: *@This()) void {
        self.* = .{};
    }
};

fn bitFlip(bits: u8) u8 {
    var x = bits;
    x = (x & 0x55) << 1 | (x & 0xAA) >> 1;
    x = (x & 0x33) << 2 | (x & 0xCC) >> 2;
    x = (x & 0x0F) << 4 | (x & 0xF0) >> 4;
    return x;
}

const Fifo = struct {
    size: u8 = 0,
    shifter_lo: u16 = 0,
    shifter_hi: u16 = 0,
    x: u8 = 0,
    discard_count: u3 = 0,

    obj_shifter_lo: u8 = 0,
    obj_shifter_hi: u8 = 0,
    obj_prio_shifter: u8 = 0,
    obj_exists: u8 = 0,
    obj_entries: [8]OamEntry = std.mem.zeroes([8]OamEntry),

    fn addObjPixels(self: *@This(), lo: u8, hi: u8, entry: OamEntry) void {
        if (self.obj_shifter_hi == 0 and self.obj_shifter_lo == 0) {
            if (entry.attr.x_flip) {
                self.obj_shifter_lo = bitFlip(lo);
                self.obj_shifter_hi = bitFlip(hi);
            } else {
                self.obj_shifter_lo = lo;
                self.obj_shifter_hi = hi;
            }
            self.obj_prio_shifter = if (entry.attr.priority) 0xFF else 0x00;
            self.obj_exists = 0xFF;
            @memset(&self.obj_entries, entry);
            return;
        }

        for (0..8) |i| {
            const bit: u3 = @intCast(7 - i);
            const mask: u8 = @as(u8, 1) << bit;

            if (self.obj_exists & mask != 0) continue;

            const bit_lo, const bit_hi = blk: {
                if (entry.attr.x_flip) {
                    break :blk .{ bitFlip(lo) & mask, bitFlip(hi) & mask };
                } else {
                    break :blk .{ lo & mask, hi & mask };
                }
            };

            self.obj_shifter_lo |= bit_lo;
            self.obj_shifter_hi |= bit_hi;
            self.obj_exists |= mask;
            self.obj_entries[i] = entry;
        }
    }

    fn addPixels(self: *@This(), lo: u8, hi: u8) bool {
        if (self.size > 8) return false;

        self.shifter_lo |= @as(u16, lo) << @intCast(8 - self.size);
        self.shifter_hi |= @as(u16, hi) << @intCast(8 - self.size);
        self.size += 8;

        std.debug.assert(self.size <= 16);

        return true;
    }

    fn push(self: *@This()) void {
        if (self.size > 0 and self.discard_count > 0) {
            self.shifter_lo <<= 1;
            self.shifter_hi <<= 1;
            self.discard_count -= 1;
            return;
        }

        if (self.size <= 8) return;

        const lo: u2 = @intFromBool(self.shifter_lo & 0x8000 != 0);
        const hi: u2 = @intFromBool(self.shifter_hi & 0x8000 != 0);
        const idx = hi << 1 | lo;
        self.shifter_hi <<= 1;
        self.shifter_lo <<= 1;
        self.size -= 1;

        const obj_lo: u2 = @intFromBool(self.obj_shifter_lo & 0x80 != 0);
        const obj_hi: u2 = @intFromBool(self.obj_shifter_hi & 0x80 != 0);
        const obj_idx = obj_hi << 1 | obj_lo;
        const prio: bool = self.obj_prio_shifter & 0x80 != 0;
        self.obj_shifter_lo <<= 1;
        self.obj_shifter_hi <<= 1;
        self.obj_prio_shifter <<= 1;
        self.obj_exists <<= 1;
        std.mem.copyForwards(OamEntry, &self.obj_entries, self.obj_entries[1..]);

        if (obj_idx == 0 or (prio and idx > 0)) {
            const color = bg_colors[idx];
            framebuffers[current_frame].putPixel(self.x, regs.ly, color);
        } else {
            const obj_color = obj_colors[self.obj_entries[0].attr.dmg_palette][obj_idx];
            framebuffers[current_frame].putPixel(self.x, regs.ly, obj_color);
        }
        self.x += 1;
    }

    fn clear(self: *@This()) void {
        self.shifter_hi = 0;
        self.shifter_lo = 0;
        self.size = 0;
        self.discard_count = 0;
    }

    fn reset(self: *@This()) void {
        self.* = .{};
    }
};

pub fn currentFrame() *const Gameboy.Frame {
    return &framebuffers[display_frame];
}
