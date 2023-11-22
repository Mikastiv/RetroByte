const Self = @This();
const std = @import("std");
const Gameboy = @import("Gameboy.zig");

const ram_size = 0x10000;

ram: [ram_size]u8 = std.mem.zeroes([ram_size]u8),

pub fn init(self: *Self, gameboy: *const Gameboy) void {
    _ = gameboy;
    self.ram = std.mem.zeroes([ram_size]u8);
}

pub fn peek(self: *Self, addr: u16) u8 {
    return self.ram[addr];
}

pub fn read(self: *Self, addr: u16) u8 {
    return self.peek(addr);
}

pub fn write(self: *Self, addr: u16, data: u8) void {
    self.ram[addr] = data;
}

pub fn tick(_: *Self) void {}
