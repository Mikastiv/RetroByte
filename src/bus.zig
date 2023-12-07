const std = @import("std");
const ram = @import("ram.zig");

const InterruptFlag = enum(u8) {
    vblank = 1 << 0,
    lcd = 1 << 1,
    timer = 1 << 2,
    serial = 1 << 3,
    joypad = 1 << 4,
};

const Interrupts = struct {
    flags: u8 = 0,
    enable: u8 = 0,

    pub fn request(self: *@This(), flag: InterruptFlag) void {
        self.flags |= @intFromEnum(flag);
    }
};

const Bus = struct {
    interrupts: Interrupts = .{},
};

pub fn peek(addr: u16) u8 {
    return ram.wramRead(addr);
}

pub fn read(addr: u16) u8 {
    return peek(addr);
}

pub fn write(addr: u16, data: u8) void {
    ram.wramWrite(addr, data);
}

pub fn tick() void {}
