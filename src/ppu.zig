const std = @import("std");

const OAM_Entry = struct {
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

var oam: [oam_size]OAM_Entry = undefined;

pub fn init() void {}

fn validateAddress(addr: u16) void {
    std.debug.assert(addr >= 0x00 and addr <= 0x9F);
}

pub fn oamRead(addr: u16) u8 {
    validateAddress(addr);
    const ptr: [*]const u8 = @ptrCast(@alignCast(&oam));
    return ptr[addr];
}

pub fn oamWrite(addr: u16, data: u8) void {
    validateAddress(addr);
    const ptr: [*]u8 = @ptrCast(@alignCast(&oam));
    ptr[addr] = data;
}
