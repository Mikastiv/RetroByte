const std = @import("std");

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

const oam_size = 40;
const vram_size = 0x2000;
const vram_mask = vram_size - 1;

var oam: [oam_size]OamEntry = undefined;
var vram: [vram_size]u8 = undefined;

pub fn init() void {}

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
    validateVramAddress(addr);
    return vram[addr & vram_mask];
}

pub fn vramWrite(addr: u16, data: u8) void {
    validateVramAddress(addr);
    vram[addr & vram_mask] = data;
}
