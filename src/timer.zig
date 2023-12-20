const std = @import("std");
const interrupts = @import("interrupts.zig");
const bus = @import("bus.zig");

var request_interrupt = false;
var tima_just_loaded = false;

var div: u16 = undefined;
var tima: u8 = undefined;
var tma: u8 = undefined;
var tac: u8 = undefined;

var reload_delay: u8 = undefined;

pub fn init() void {
    div = 0xABCC;
    tima = 0;
    tma = 0;
    tac = 0;
    reload_delay = 0;
}

fn tacMask() u16 {
    const mode: u2 = @truncate(tac);
    return switch (mode) {
        0b00 => 1 << 9,
        0b01 => 1 << 3,
        0b10 => 1 << 5,
        0b11 => 1 << 7,
    };
}

fn divOutputBit() bool {
    return div & tacMask() != 0;
}

fn timerEnabled() bool {
    return tac & 0b100 != 0;
}

fn incrementTima() void {
    tima, const overflow = @addWithOverflow(tima, 1);

    if (overflow != 0) {
        tima = 0;
        request_interrupt = true;
    }
}

pub fn tick() void {
    if (tima_just_loaded) reload_delay -= 1;
    if (reload_delay == 0) tima_just_loaded = false;

    if (request_interrupt) {
        request_interrupt = false;
        interrupts.request(.timer);
        tima = tma;
        tima_just_loaded = true;
        reload_delay = 4;
    }

    const old_bit = divOutputBit();
    div +%= 1;
    const new_bit = divOutputBit();

    const falling_edge = old_bit and !new_bit;

    if (falling_edge and timerEnabled()) {
        incrementTima();
    }
}

fn divRead() u8 {
    return @truncate(div >> 8);
}

fn divWrite() void {
    if (timerEnabled() and divOutputBit()) {
        incrementTima();
    }
    div = 0;
}

fn tacRead() u8 {
    return 0xF8 | (tac & 0x07);
}

fn tacWrite(value: u8) void {
    const old_bit = divOutputBit();
    const old_enable = timerEnabled();
    tac = value;
    const new_bit = divOutputBit();
    const new_enable = timerEnabled();

    if (!old_enable) return;

    var increment = false;
    if (!new_enable) {
        increment = old_bit;
    } else {
        increment = old_bit and !new_bit;
    }

    if (increment) incrementTima();
}

fn tmaRead() u8 {
    return tma;
}

fn tmaWrite(value: u8) void {
    tma = value;
    if (tima_just_loaded) {
        tima = value;
    }
}

fn timaRead() u8 {
    return tima;
}

fn timaWrite(value: u8) void {
    if (!tima_just_loaded) {
        tima = value;
    }
    if (request_interrupt) {
        request_interrupt = false;
    }
}

fn validateTimerAddress(addr: u16) void {
    std.debug.assert(addr >= 0xFF04 and addr <= 0xFF07);
}

pub fn read(addr: u16) u8 {
    validateTimerAddress(addr);
    return switch (addr) {
        0xFF04 => divRead(),
        0xFF05 => timaRead(),
        0xFF06 => tmaRead(),
        0xFF07 => tacRead(),
        else => unreachable,
    };
}

pub fn write(addr: u16, data: u8) void {
    validateTimerAddress(addr);
    switch (addr) {
        0xFF04 => divWrite(),
        0xFF05 => timaWrite(data),
        0xFF06 => tmaWrite(data),
        0xFF07 => tacWrite(data),
        else => unreachable,
    }
}
