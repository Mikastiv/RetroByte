const std = @import("std");

const wram_size = 0x2000;
const wram_mask = wram_size - 1;
const hram_size = 0x80;
const hram_mask = hram_size - 1;

var wram = std.mem.zeroes([wram_size]u8);
var hram = std.mem.zeroes([hram_size]u8);

fn validateWramAddress(addr: u16) void {
    std.debug.assert(addr >= 0xC000 and addr <= 0xFDFF);
}

fn validateHramAddress(addr: u16) void {
    std.debug.assert(addr >= 0xFF80 and addr <= 0xFFFE);
}

pub fn wramRead(addr: u16) u8 {
    validateWramAddress(addr);
    return wram[addr & wram_mask];
}

pub fn wramWrite(addr: u16, data: u8) void {
    validateWramAddress(addr);
    wram[addr & wram_mask] = data;
}

pub fn hramRead(addr: u16) u8 {
    validateHramAddress(addr);
    return hram[addr & hram_mask];
}

pub fn hramWrite(addr: u16, data: u8) void {
    validateHramAddress(addr);
    hram[addr & hram_mask] = data;
}
