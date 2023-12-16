const std = @import("std");
const rom = @import("rom.zig");
const timer = @import("timer.zig");
const interrupts = @import("interrupts.zig");
const joypad = @import("joypad.zig");
const lcd = @import("lcd.zig");
const ppu = @import("ppu.zig");
const dma = @import("dma.zig");

pub var cycles: u128 = 0;

var serial_data: [2]u8 = .{ 0, 0 };

const wram_size = 0x2000;
const wram_mask = wram_size - 1;
const hram_size = 0x80;
const hram_mask = hram_size - 1;
const vram_size = 0x2000;
const vram_mask = vram_size - 1;

var wram: [wram_size]u8 = undefined;
var hram: [hram_size]u8 = undefined;
var vram: [vram_size]u8 = undefined;

pub fn init() void {
    serial_data = .{ 0, 0 };
    cycles = 0;
}

pub fn peek(addr: u16) u8 {
    return switch (addr) {
        0x0000...0x7FFF => rom.read(addr),
        0x8000...0x9FFF => vram[addr & vram_mask],
        0xC000...0xFDFF => wram[addr & wram_mask],
        0xFE00...0xFE9F => ppu.oamRead(addr & 0xFF),
        0xFEA0...0xFEFF => 0, // prohibited region
        0xFF00 => joypad.read(),
        0xFF01 => serial_data[0],
        0xFF02 => serial_data[1],
        0xFF04...0xFF07 => timer.read(addr),
        0xFF0F => interrupts.requestedFlags(),
        0xFF40...0xFF45 => lcd.read(addr),
        0xFF46 => dma.read(),
        0xFF47...0xFF4B => lcd.read(addr),
        0xFF80...0xFFFE => hram[addr & hram_mask],
        0xFFFF => interrupts.enabledFlags(),
        else => {
            std.debug.print("unimplemented read ${x:0>4}\n", .{addr});
            return 0;
        },
    };
}

pub fn read(addr: u16) u8 {
    tick();
    return peek(addr);
}

pub fn set(addr: u16, data: u8) void {
    switch (addr) {
        0x0000...0x7FFF => rom.write(addr, data),
        0x8000...0x9FFF => vram[addr & vram_mask] = data,
        0xC000...0xFDFF => wram[addr & wram_mask] = data,
        0xFE00...0xFE9F => ppu.oamWrite(addr & 0xFF, data),
        0xFEA0...0xFEFF => {}, // prohibited region
        0xFF00 => joypad.write(data),
        0xFF01 => serial_data[0] = data,
        0xFF02 => serial_data[1] = data,
        0xFF04...0xFF07 => timer.write(addr, data),
        0xFF0F => interrupts.rawRequest(data),
        0xFF40...0xFF45 => lcd.write(addr, data),
        0xFF46 => dma.write(data),
        0xFF47...0xFF4B => lcd.write(addr, data),
        0xFF80...0xFFFE => hram[addr & hram_mask] = data,
        0xFFFF => interrupts.enable(data),
        else => std.debug.print("unimplemented write ${x:0>4}\n", .{addr}),
    }
}
pub fn write(addr: u16, data: u8) void {
    tick();
    set(addr, data);
}

pub fn tick() void {
    for (0..4) |_| {
        timer.tick();
    }
    dma.tick();
    cycles +%= 1;
}
