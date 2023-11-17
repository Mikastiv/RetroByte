const Self = @This();
const std = @import("std");
const Bus = @import("Bus.zig");

const ram_size = 0x10000;

ram: [ram_size]u8 = std.mem.zeroes([ram_size]u8),

pub fn bus(self: *Self) Bus {
    return .{
        .ctx = self,
        .vtable = &.{
            .peek = peek,
            .read = read,
            .write = write,
            .tick = tick,
        },
    };
}

fn peek(ctx: *anyopaque, addr: u16) u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.ram[addr];
}

fn read(ctx: *anyopaque, addr: u16) u8 {
    return peek(ctx, addr);
}

fn write(ctx: *anyopaque, addr: u16, data: u8) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.ram[addr] = data;
}

fn tick(_: *anyopaque) void {}
