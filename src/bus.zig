const std = @import("std");
const ram = @import("ram.zig");
const rom = @import("rom.zig");
const timer = @import("timer.zig");
const interrupts = @import("interrupts.zig");

pub var cycles: u64 = 0;

pub fn peek(addr: u16) u8 {
    return switch (addr) {
        0x0000...0x7FFF => rom.read(addr),
        0xC000...0xFDFF => ram.wramRead(addr),
        0xFF04 => timer.divRead(),
        0xFF05 => timer.timaRead(),
        0xFF06 => timer.tmaRead(),
        0xFF07 => timer.tacRead(),
        0xFF0F => interrupts.requestedFlags(),
        0xFF80...0xFFFE => ram.hramRead(addr),
        0xFFFF => interrupts.enabledFlags(),
        else => {
            std.debug.print("unimplemented read {d}\n", .{addr});
            return 0;
        },
    };
}

pub fn read(addr: u16) u8 {
    tick();
    return peek(addr);
}

pub fn write(addr: u16, data: u8) void {
    tick();
    switch (addr) {
        0x0000...0x7FFF => rom.write(addr, data),
        0xC000...0xFDFF => ram.wramWrite(addr, data),
        0xFF04 => timer.divWrite(),
        0xFF05 => timer.timaWrite(data),
        0xFF06 => timer.tmaWrite(data),
        0xFF07 => timer.tacWrite(data),
        0xFF0F => interrupts.rawRequest(data),
        0xFF80...0xFFFE => ram.hramWrite(addr, data),
        0xFFFF => interrupts.enable(data),
        else => std.debug.print("unimplemented write {d}\n", .{addr}),
    }
}

pub fn tick() void {
    timer.tick();
    cycles += 1;
}
