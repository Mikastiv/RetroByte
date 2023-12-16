const std = @import("std");

const Control = packed union {
    bit: packed struct {
        bg_on: u1,
        obj_on: u1,
        obj_size: u1,
        bg_map: u1,
        bg_addr: u1,
        window_on: u1,
        window_map: u1,
        lcd_on: u1,
    },
    raw: u8,
};

const Stat = packed union {
    bit: packed struct {
        ppu_mode: u2,
        compare: u1,
        mode_0: u1,
        mode_1: u1,
        mode_2: u1,
        lyc_int: u1,
    },
    raw: u8,
};

const Registers = struct {
    ctrl: Control,
    ly: u8,
    lyc: u8,
    stat: Stat,
};

var registers: Registers = undefined;

pub fn init() void {
    registers.ctrl.raw = 0;
    registers.ly = 0;
    registers.lyc = 0;
    registers.stat.raw = 0;
}

fn validateAddress(addr: u16) void {
    std.debug.assert(addr >= 0xFF40 and addr <= 0xFF4B and addr != 0xFF46);
}

pub fn read(addr: u16) u8 {
    validateAddress(addr);
    return switch (addr) {
        0xFF40 => registers.ctrl.raw,
        0xFF41 => registers.stat.raw & 0x7F,
        0xFF44 => registers.ly,
        0xFF45 => registers.lyc,
        else => 0,
    };
}

pub fn write(addr: u16, data: u8) void {
    validateAddress(addr);
    switch (addr) {
        0xFF40 => registers.ctrl.raw = data,
        0xFF41 => registers.stat.raw = (registers.stat.raw & 0x07) | (data & 0x78),
        0xFF45 => registers.lyc = data,
        else => {},
    }
}
