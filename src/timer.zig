const std = @import("std");
const interrupts = @import("interrupts.zig");
const bus = @import("bus.zig");

var request_interrupt = false;
var tima_just_loaded = false;

var div: u16 = 0xABCC;
var tima: u8 = 0;
var tma: u8 = 0;
var tac: u8 = 0;

// fn tacMask() u16 {
//     const mode: u2 = @truncate(tac);
//     return switch (mode) {
//         0b00 => 1 << 9,
//         0b01 => 1 << 3,
//         0b10 => 1 << 5,
//         0b11 => 1 << 7,
//     };
// }

// fn divOutputBit() bool {
//     return div & tacMask() != 0;
// }

// fn timerEnabled() bool {
//     return tac & 0b100 != 0;
// }

// fn incrementTima() void {
//     tima, const overflow = @addWithOverflow(tima, 1);

//     if (overflow != 0) {
//         tima = 0;
//         request_interrupt = true;
//     }
// }

// pub fn tick() void {
//     if (request_interrupt) {
//         request_interrupt = false;
//         interrupts.request(.timer);
//         tima = tma;
//         tima_just_loaded = true;
//     } else {
//         tima_just_loaded = false;
//     }

//     const old_bit = divOutputBit();
//     div +%= 1;
//     const new_bit = divOutputBit();

//     const falling_edge = old_bit and !new_bit;

//     if (falling_edge and timerEnabled()) {
//         incrementTima();
//     }
// }

// pub fn divRead() u8 {
//     return @truncate(div >> 8);
// }

// pub fn divWrite() void {
//     if (timerEnabled() and divOutputBit()) {
//         incrementTima();
//     }
//     div = 0;
// }

// pub fn tacRead() u8 {
//     return 0xF8 | (tac & 0x07);
// }

// pub fn tacWrite(value: u8) void {
//     const old_bit = divOutputBit();
//     const old_enable = timerEnabled();
//     tac = value;
//     const new_bit = divOutputBit();
//     const new_enable = timerEnabled();

//     if (!old_enable) return;

//     var increment = false;
//     if (!new_enable) {
//         increment = old_bit;
//     } else {
//         increment = old_bit and !new_bit;
//     }

//     if (increment) incrementTima();
// }

// pub fn tmaRead() u8 {
//     return tma;
// }

// pub fn tmaWrite(value: u8) void {
//     tma = value;
//     if (tima_just_loaded) {
//         tima = value;
//     }
// }

// pub fn timaRead() u8 {
//     return tima;
// }

// pub fn timaWrite(value: u8) void {
//     if (!tima_just_loaded) {
//         tima = value;
//     }
//     if (request_interrupt) {
//         request_interrupt = false;
//     }
// }

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
    tima +%= 1;

    if (tima == 0xFF) {
        tima = tma;
        interrupts.request(.timer);
    }
}

pub fn tick() void {
    const old_bit = divOutputBit();
    div +%= 1;
    const new_bit = divOutputBit();

    const falling_edge = old_bit and !new_bit;

    if (falling_edge and timerEnabled()) {
        incrementTima();
    }
}

pub fn divRead() u8 {
    return @truncate(div >> 8);
}

pub fn divWrite() void {
    div = 0;
}

pub fn tacRead() u8 {
    return tac;
}

pub fn tacWrite(value: u8) void {
    tac = value;
}

pub fn tmaRead() u8 {
    return tma;
}

pub fn tmaWrite(value: u8) void {
    tma = value;
}

pub fn timaRead() u8 {
    return tima;
}

pub fn timaWrite(value: u8) void {
    tima = value;
}
