const std = @import("std");
const ram = @import("ram.zig");
const vram = @import("vram.zig");
const rom = @import("rom.zig");
const timer = @import("timer.zig");
const interrupts = @import("interrupts.zig");
const joypad = @import("joypad.zig");

pub var cycles: u128 = 0;

var serial_data: [2]u8 = .{ 0, 0 };

pub fn init() void {
    serial_data = .{ 0, 0 };
    cycles = 0;
}

pub fn peek(addr: u16) u8 {
    return switch (addr) {
        0x0000...0x7FFF => rom.read(addr),
        0x8000...0x9FFF => vram.read(addr),
        0xC000...0xFDFF => ram.wramRead(addr),
        0xFF00 => joypad.read(),
        0xFF01 => serial_data[0],
        0xFF02 => serial_data[1],
        0xFF04...0xFF07 => timer.read(addr),
        0xFF80...0xFFFE => ram.hramRead(addr),
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
        0x8000...0x9FFF => vram.write(addr, data),
        0xC000...0xFDFF => ram.wramWrite(addr, data),
        0xFF00 => joypad.write(data),
        0xFF01 => serial_data[0] = data,
        0xFF02 => serial_data[1] = data,
        0xFF04...0xFF07 => timer.write(addr, data),
        0xFF0F => interrupts.rawRequest(data),
        0xFF80...0xFFFE => ram.hramWrite(addr, data),
        0xFFFF => interrupts.enable(data),
        else => std.debug.print("unimplemented write ${x:0>4}\n", .{addr}),
    }
}
pub fn write(addr: u16, data: u8) void {
    tick();
    set(addr, data);
}

pub fn tick() void {
    for (0..4) |_| timer.tick();
    cycles +%= 1;
}
