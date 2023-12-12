const std = @import("std");

const vram_size = 0x2000;
const vram_mask = vram_size - 1;

var vram = std.mem.zeroes([vram_size]u8);

fn validateAddress(addr: u16) void {
    std.debug.assert(addr >= 0x8000 and addr <= 0x9FFF);
}

pub fn read(addr: u16) u8 {
    validateAddress(addr);
    return vram[addr & vram_mask];
}

pub fn write(addr: u16, data: u8) void {
    validateAddress(addr);
    vram[addr & vram_mask] = data;
}
