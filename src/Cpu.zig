const std = @import("std");
const Self = @This();
const Registers = @import("cpu/Registers.zig");
const Bus = @import("bus.zig").Bus;
const expect = std.testing.expect;
const Regs8 = Registers.Regs8;
const Regs16 = Registers.Regs16;

regs: Registers,
bus: *Bus,

pub fn init(bus: *Bus) Self {
    return .{
        .bus = bus,
        .regs = Registers.init(),
    };
}

pub fn execute(self: *Self) void {
    const opcode: u8 = self.bus.read(self.regs.pc);
    self.regs.pc +%= 1;
    switch (opcode) {
        0x00 => self.nop(),
        0x01 => self.ldD16(.bc),
        0x11 => self.ldD16(.de),
        0x21 => self.ldD16(.hl),
        0x31 => self.ldD16(.sp),
        0x40 => self.ldRR(.b, .b),
        0x41 => self.ldRR(.b, .c),
        0x42 => self.ldRR(.b, .d),
        0x43 => self.ldRR(.b, .e),
        0x44 => self.ldRR(.b, .h),
        0x45 => self.ldRR(.b, .l),
        //0x46 => self.ldRR(.b, )
        0x47 => self.ldRR(.b, .a),
        0x48 => self.ldRR(.c, .b),
        0x49 => self.ldRR(.c, .c),
        0x4A => self.ldRR(.c, .d),
        0x4B => self.ldRR(.c, .e),
        0x4C => self.ldRR(.c, .h),
        0x4D => self.ldRR(.c, .l),
        //0x4E => self.ldRR(.c, ),
        0x4F => self.ldRR(.c, .a),
        0x50 => self.ldRR(.d, .b),
        0x51 => self.ldRR(.d, .c),
        0x52 => self.ldRR(.d, .d),
        0x53 => self.ldRR(.d, .e),
        0x54 => self.ldRR(.d, .h),
        0x55 => self.ldRR(.d, .l),
        //0x56 => self.ldRR(.d, ),
        0x57 => self.ldRR(.d, .a),
        0x58 => self.ldRR(.e, .b),
        0x59 => self.ldRR(.e, .c),
        0x5A => self.ldRR(.e, .d),
        0x5B => self.ldRR(.e, .e),
        0x5C => self.ldRR(.e, .h),
        0x5D => self.ldRR(.e, .l),
        //0x5E => self.ldRR(.e, ),
        0x5F => self.ldRR(.e, .a),
        0x60 => self.ldRR(.h, .b),
        0x61 => self.ldRR(.h, .c),
        0x62 => self.ldRR(.h, .d),
        0x63 => self.ldRR(.h, .e),
        0x64 => self.ldRR(.h, .h),
        0x65 => self.ldRR(.h, .l),
        //0x66 => self.ldRR(.h, ),
        0x67 => self.ldRR(.h, .a),
        0x68 => self.ldRR(.l, .b),
        0x69 => self.ldRR(.l, .c),
        0x6A => self.ldRR(.l, .d),
        0x6B => self.ldRR(.l, .e),
        0x6C => self.ldRR(.l, .h),
        0x6D => self.ldRR(.l, .l),
        //0x6E => self.ldRR(.l, ),
        0x6F => self.ldRR(.l, .a),
        //0x77 => self.ldRR(.h, .a),
        0x78 => self.ldRR(.a, .b),
        0x79 => self.ldRR(.a, .c),
        0x7A => self.ldRR(.a, .d),
        0x7B => self.ldRR(.a, .e),
        0x7C => self.ldRR(.a, .h),
        0x7D => self.ldRR(.a, .l),
        //0x7E => self.ldRR(.a, ),
        0x7F => self.ldRR(.a, .a),
        else => {},
    }
}

fn read8(self: *Self) u8 {
    const byte: u8 = self.bus.read(self.regs.pc);
    self.regs.pc +%= 1;
    return byte;
}

fn read16(self: *Self) u16 {
    const lo: u16 = self.read8();
    const hi: u16 = self.read8();
    return (hi << 8 | lo);
}

fn nop(_: *Self) void {}

fn ldD16(self: *Self, comptime reg: Regs16) void {
    const d16 = self.read16();
    self.regs.write16(reg, d16);
}

fn ldRR(self: *Self, comptime dst: Regs8, comptime src: Regs8) void {
    self.regs.write8(dst, self.regs.read8(src));
}

test "registers" {
    var regs: Registers = undefined;

    regs.b = 0x7A;
    regs.c = 0xFF;
    try expect(regs.read16(.bc) == 0x7AFF);

    regs.write16(.af, 0xBEEF);
    try expect(regs.a == 0xBE and regs.f.raw == 0xEF);
    try expect(regs.read16(.af) == 0xBEEF);
}

test "flags" {
    var regs: Registers = undefined;

    regs.f.raw = 0;
    regs.f.bits.z = 1;
    try expect(regs.f.raw == 0x80);
    regs.f.bits.c = 1;
    try expect(regs.f.raw == 0x90);
    regs.f.bits.n = 1;
    try expect(regs.f.raw == 0xD0);
}

test "ldD16" {
    var bus = Bus{ .test_bus = .{} };

    var cpu = init(&bus);

    bus.test_bus.ram[0x0100] = 0x01;
    bus.test_bus.ram[0x0101] = 0xF0;
    bus.test_bus.ram[0x0102] = 0x0F;
    cpu.execute();
    try expect(cpu.regs.read16(.bc) == 0x0FF0);
}

test "ldRR" {
    var bus = Bus{ .test_bus = .{} };

    var cpu = init(&bus);
    bus.test_bus.ram[0x0100] = 0x41;
    cpu.regs.b = 0x00;
    cpu.regs.c = 0xFF;
    cpu.execute();
    try expect(cpu.regs.b == 0xFF);
}
