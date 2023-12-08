const std = @import("std");

pub const Interrupt = enum(u8) {
    vblank = 1 << 0,
    lcd = 1 << 1,
    timer = 1 << 2,
    serial = 1 << 3,
    joypad = 1 << 4,
};

var requests: u8 = 0;
var enabled: u8 = 0;

pub fn request(interrupt: Interrupt) void {
    requests |= @intFromEnum(interrupt);
}

pub fn enable(flags: u8) void {
    enabled = flags;
}

pub fn handled(interrupt: Interrupt) void {
    requests &= ~@intFromEnum(interrupt);
}

pub fn any() bool {
    return requests & enabled != 0;
}

pub fn highestPriority() Interrupt {
    const queue: u5 = @truncate(requests & enabled);
    const first = @as(u8, 1) << @ctz(queue);
    return @enumFromInt(first);
}
