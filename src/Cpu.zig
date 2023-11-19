const std = @import("std");
const Self = @This();
const Registers = @import("cpu/Registers.zig");
const Bus = @import("bus.zig").Bus;
const expect = std.testing.expect;
const rw = @import("cpu/rw.zig");
const Reg16 = Registers.Reg16;
// const Reg8 = Registers.Reg8;

regs: Registers,
bus: *Bus,

pub fn init(bus: *Bus) Self {
    return .{
        .bus = bus,
        .regs = Registers.init(),
    };
}

pub fn execute(self: *Self) void {
    const opcode: u8 = self.read8();
    switch (opcode) {
        0x00 => self.nop(),
        0x01 => self.ld16(.bc),
        0x02 => self.ld(.{ .address = .bc }, .{ .reg8 = .a }),
        0x06 => self.ld(.{ .reg8 = .b }, .{ .address = .imm }),
        0x08 => self.ldAbsSp(),
        0x0A => self.ld(.{ .reg8 = .a }, .{ .address = .bc }),
        0x0E => self.ld(.{ .reg8 = .c }, .{ .address = .imm }),
        0x11 => self.ld16(.de),
        0x12 => self.ld(.{ .address = .de }, .{ .reg8 = .a }),
        0x1A => self.ld(.{ .reg8 = .a }, .{ .address = .de }),
        0x1E => self.ld(.{ .reg8 = .e }, .{ .address = .imm }),
        0x16 => self.ld(.{ .reg8 = .d }, .{ .address = .imm }),
        0x21 => self.ld16(.hl),
        0x22 => self.ld(.{ .address = .hli }, .{ .reg8 = .a }),
        0x26 => self.ld(.{ .reg8 = .h }, .{ .address = .imm }),
        0x2A => self.ld(.{ .reg8 = .a }, .{ .address = .hli }),
        0x2E => self.ld(.{ .reg8 = .l }, .{ .address = .imm }),
        0x31 => self.ld16(.sp),
        0x32 => self.ld(.{ .address = .hld }, .{ .reg8 = .a }),
        0x36 => self.ld(.{ .address = .hl }, .{ .address = .imm }),
        0x3A => self.ld(.{ .reg8 = .a }, .{ .address = .hld }),
        0x3E => self.ld(.{ .reg8 = .a }, .{ .address = .imm }),
        0x40 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .b }),
        0x41 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .c }),
        0x42 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .d }),
        0x43 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .e }),
        0x44 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .h }),
        0x45 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .l }),
        0x46 => self.ld(.{ .reg8 = .b }, .{ .address = .hl }),
        0x47 => self.ld(.{ .reg8 = .b }, .{ .reg8 = .a }),
        0x48 => self.ld(.{ .reg8 = .c }, .{ .reg8 = .b }),
        0x49 => self.ld(.{ .reg8 = .c }, .{ .reg8 = .c }),
        0x4A => self.ld(.{ .reg8 = .c }, .{ .reg8 = .d }),
        0x4B => self.ld(.{ .reg8 = .c }, .{ .reg8 = .e }),
        0x4C => self.ld(.{ .reg8 = .c }, .{ .reg8 = .h }),
        0x4D => self.ld(.{ .reg8 = .c }, .{ .reg8 = .l }),
        0x4E => self.ld(.{ .reg8 = .c }, .{ .address = .hl }),
        0x4F => self.ld(.{ .reg8 = .c }, .{ .reg8 = .a }),
        0x50 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .b }),
        0x51 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .c }),
        0x52 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .d }),
        0x53 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .e }),
        0x54 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .h }),
        0x55 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .l }),
        0x56 => self.ld(.{ .reg8 = .d }, .{ .address = .hl }),
        0x57 => self.ld(.{ .reg8 = .d }, .{ .reg8 = .a }),
        0x58 => self.ld(.{ .reg8 = .e }, .{ .reg8 = .b }),
        0x59 => self.ld(.{ .reg8 = .e }, .{ .reg8 = .c }),
        0x5A => self.ld(.{ .reg8 = .e }, .{ .reg8 = .d }),
        0x5B => self.ld(.{ .reg8 = .e }, .{ .reg8 = .e }),
        0x5C => self.ld(.{ .reg8 = .e }, .{ .reg8 = .h }),
        0x5D => self.ld(.{ .reg8 = .e }, .{ .reg8 = .l }),
        0x5E => self.ld(.{ .reg8 = .e }, .{ .address = .hl }),
        0x5F => self.ld(.{ .reg8 = .e }, .{ .reg8 = .a }),
        0x60 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .b }),
        0x61 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .c }),
        0x62 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .d }),
        0x63 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .e }),
        0x64 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .h }),
        0x65 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .l }),
        0x66 => self.ld(.{ .reg8 = .h }, .{ .address = .hl }),
        0x67 => self.ld(.{ .reg8 = .h }, .{ .reg8 = .a }),
        0x68 => self.ld(.{ .reg8 = .l }, .{ .reg8 = .b }),
        0x69 => self.ld(.{ .reg8 = .l }, .{ .reg8 = .c }),
        0x6A => self.ld(.{ .reg8 = .l }, .{ .reg8 = .d }),
        0x6B => self.ld(.{ .reg8 = .l }, .{ .reg8 = .e }),
        0x6C => self.ld(.{ .reg8 = .l }, .{ .reg8 = .h }),
        0x6D => self.ld(.{ .reg8 = .l }, .{ .reg8 = .l }),
        0x6E => self.ld(.{ .reg8 = .l }, .{ .address = .hl }),
        0x6F => self.ld(.{ .reg8 = .l }, .{ .reg8 = .a }),
        0x70 => self.ld(.{ .address = .hl }, .{ .reg8 = .b }),
        0x71 => self.ld(.{ .address = .hl }, .{ .reg8 = .c }),
        0x72 => self.ld(.{ .address = .hl }, .{ .reg8 = .d }),
        0x73 => self.ld(.{ .address = .hl }, .{ .reg8 = .e }),
        0x74 => self.ld(.{ .address = .hl }, .{ .reg8 = .h }),
        0x75 => self.ld(.{ .address = .hl }, .{ .reg8 = .l }),
        0x77 => self.ld(.{ .address = .hl }, .{ .reg8 = .a }),
        0x78 => self.ld(.{ .reg8 = .a }, .{ .reg8 = .b }),
        0x79 => self.ld(.{ .reg8 = .a }, .{ .reg8 = .c }),
        0x7A => self.ld(.{ .reg8 = .a }, .{ .reg8 = .d }),
        0x7B => self.ld(.{ .reg8 = .a }, .{ .reg8 = .e }),
        0x7C => self.ld(.{ .reg8 = .a }, .{ .reg8 = .h }),
        0x7D => self.ld(.{ .reg8 = .a }, .{ .reg8 = .l }),
        0x7E => self.ld(.{ .reg8 = .a }, .{ .address = .hl }),
        0x7F => self.ld(.{ .reg8 = .a }, .{ .reg8 = .a }),
        0xE0 => self.ld(.{ .address = .zero_page }, .{ .reg8 = .a }),
        0xE2 => self.ld(.{ .address = .zero_page_c }, .{ .reg8 = .a }),
        0xEA => self.ld(.{ .address = .absolute }, .{ .reg8 = .a }),
        0xF0 => self.ld(.{ .reg8 = .a }, .{ .address = .zero_page }),
        0xF2 => self.ld(.{ .reg8 = .a }, .{ .address = .zero_page_c }),
        0xF8 => self.ldHlSpImm(),
        0xF9 => self.ldSpHl(),
        0xFA => self.ld(.{ .reg8 = .a }, .{ .address = .absolute }),
        else => {},
    }
}

pub fn read8(self: *Self) u8 {
    const byte: u8 = self.bus.read(self.regs.pc);
    self.regs.pc +%= 1;
    return byte;
}

pub fn read16(self: *Self) u16 {
    const lo: u16 = self.read8();
    const hi: u16 = self.read8();
    return hi << 8 | lo;
}

fn nop(_: *Self) void {}

fn ld(self: *Self, comptime dst: rw.Dst, comptime src: rw.Src) void {
    const value = src.read(self);
    dst.write(self, value);
}

fn ld16(self: *Self, comptime reg: Reg16) void {
    const d16 = self.read16();
    self.regs.write16(reg, d16);
}

fn ldAbsSp(self: *Self) void {
    const addr = self.read16();
    self.bus.write(addr, @truncate(self.regs.sp));
    self.bus.write(addr +% 1, @intCast(self.regs.sp >> 8));
}

fn ldHlSpImm(self: *Self) void {
    const offset: u16 = @bitCast(@as(i16, @bitCast(self.read8())));
    const sp = self.regs.sp;

    self.regs.write16(.hl, sp +% offset);

    const carry = (sp & 0xFF) + (offset & 0xFF) > 0xFF;
    const half = (sp & 0xF) + (offset & 0xF) > 0xF;
    self.regs.f.bits.c = @intFromBool(carry);
    self.regs.f.bits.h = @intFromBool(half);
    self.regs.f.bits.n = 0;
    self.regs.f.bits.z = 0;

    self.bus.tick();
}

fn ldSpHl(self: *Self) void {
    self.regs.sp = self.regs.read16(.hl);
    self.bus.tick();
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

test "ld16" {
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
