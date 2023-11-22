const std = @import("std");
const Self = @This();
const registers = @import("cpu/registers.zig");
const Bus = @import("bus.zig").Bus;
const Location = @import("cpu/Location.zig").Location;
const expect = std.testing.expect;

const Registers = registers.Registers;
const Reg16 = registers.Reg16;
const Reg8 = registers.Reg8;

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
        0x02 => self.ld(.addr_bc, .a),
        0x03 => self.inc16(.bc),
        0x04 => self.inc(.b),
        0x05 => self.dec(.b),
        0x06 => self.ld(.b, .imm),
        0x08 => self.ldAbsSp(),
        0x0A => self.ld(.a, .addr_bc),
        0x0B => self.dec16(.bc),
        0x0C => self.inc(.c),
        0x0D => self.dec(.c),
        0x0E => self.ld(.c, .imm),
        0x11 => self.ld16(.de),
        0x12 => self.ld(.addr_de, .a),
        0x13 => self.inc16(.de),
        0x14 => self.inc(.d),
        0x15 => self.dec(.d),
        0x1A => self.ld(.a, .addr_de),
        0x1B => self.dec16(.de),
        0x1C => self.inc(.e),
        0x1D => self.dec(.e),
        0x1E => self.ld(.e, .imm),
        0x16 => self.ld(.d, .imm),
        0x21 => self.ld16(.hl),
        0x22 => self.ld(.addr_hli, .a),
        0x23 => self.inc16(.hl),
        0x24 => self.inc(.h),
        0x25 => self.dec(.h),
        0x26 => self.ld(.h, .imm),
        0x2A => self.ld(.a, .addr_hli),
        0x2B => self.dec16(.hl),
        0x2C => self.inc(.l),
        0x2D => self.dec(.l),
        0x2E => self.ld(.l, .imm),
        0x31 => self.ld16(.sp),
        0x32 => self.ld(.addr_hld, .a),
        0x33 => self.inc16(.sp),
        0x34 => self.inc(.addr_hl),
        0x35 => self.dec(.addr_hl),
        0x36 => self.ld(.addr_hl, .imm),
        0x3A => self.ld(.a, .addr_hld),
        0x3B => self.dec16(.sp),
        0x3C => self.inc(.a),
        0x3D => self.dec(.a),
        0x3E => self.ld(.a, .imm),
        0x40 => self.ld(.b, .b),
        0x41 => self.ld(.b, .c),
        0x42 => self.ld(.b, .d),
        0x43 => self.ld(.b, .e),
        0x44 => self.ld(.b, .h),
        0x45 => self.ld(.b, .l),
        0x46 => self.ld(.b, .addr_hl),
        0x47 => self.ld(.b, .a),
        0x48 => self.ld(.c, .b),
        0x49 => self.ld(.c, .c),
        0x4A => self.ld(.c, .d),
        0x4B => self.ld(.c, .e),
        0x4C => self.ld(.c, .h),
        0x4D => self.ld(.c, .l),
        0x4E => self.ld(.c, .addr_hl),
        0x4F => self.ld(.c, .a),
        0x50 => self.ld(.d, .b),
        0x51 => self.ld(.d, .c),
        0x52 => self.ld(.d, .d),
        0x53 => self.ld(.d, .e),
        0x54 => self.ld(.d, .h),
        0x55 => self.ld(.d, .l),
        0x56 => self.ld(.d, .addr_hl),
        0x57 => self.ld(.d, .a),
        0x58 => self.ld(.e, .b),
        0x59 => self.ld(.e, .c),
        0x5A => self.ld(.e, .d),
        0x5B => self.ld(.e, .e),
        0x5C => self.ld(.e, .h),
        0x5D => self.ld(.e, .l),
        0x5E => self.ld(.e, .addr_hl),
        0x5F => self.ld(.e, .a),
        0x60 => self.ld(.h, .b),
        0x61 => self.ld(.h, .c),
        0x62 => self.ld(.h, .d),
        0x63 => self.ld(.h, .e),
        0x64 => self.ld(.h, .h),
        0x65 => self.ld(.h, .l),
        0x66 => self.ld(.h, .addr_hl),
        0x67 => self.ld(.h, .a),
        0x68 => self.ld(.l, .b),
        0x69 => self.ld(.l, .c),
        0x6A => self.ld(.l, .d),
        0x6B => self.ld(.l, .e),
        0x6C => self.ld(.l, .h),
        0x6D => self.ld(.l, .l),
        0x6E => self.ld(.l, .addr_hl),
        0x6F => self.ld(.l, .a),
        0x70 => self.ld(.addr_hl, .b),
        0x71 => self.ld(.addr_hl, .c),
        0x72 => self.ld(.addr_hl, .d),
        0x73 => self.ld(.addr_hl, .e),
        0x74 => self.ld(.addr_hl, .h),
        0x75 => self.ld(.addr_hl, .l),
        0x77 => self.ld(.addr_hl, .a),
        0x78 => self.ld(.a, .b),
        0x79 => self.ld(.a, .c),
        0x7A => self.ld(.a, .d),
        0x7B => self.ld(.a, .e),
        0x7C => self.ld(.a, .h),
        0x7D => self.ld(.a, .l),
        0x7E => self.ld(.a, .addr_hl),
        0x7F => self.ld(.a, .a),
        0xE0 => self.ld(.zero_page, .a),
        0xE2 => self.ld(.zero_page_c, .a),
        0xEA => self.ld(.imm_word, .a),
        0xF0 => self.ld(.a, .zero_page),
        0xF2 => self.ld(.a, .zero_page_c),
        0xF8 => self.ldHlSpImm(),
        0xF9 => self.ldSpHl(),
        0xFA => self.ld(.a, .imm_word),
        else => {},
    }
}

pub fn read8(self: *Self) u8 {
    const byte: u8 = self.bus.read(self.regs._16.get(.pc));
    self.regs.incPc();
    return byte;
}

pub fn read16(self: *Self) u16 {
    const lo: u16 = self.read8();
    const hi: u16 = self.read8();
    return hi << 8 | lo;
}

fn nop(_: *Self) void {}

fn ld(self: *Self, comptime dst: Location, comptime src: Location) void {
    const value = src.get(self);
    dst.set(self, value);
}

fn ld16(self: *Self, comptime reg: Reg16) void {
    const value = self.read16();
    self.regs._16.set(reg, value);
}

fn ldAbsSp(self: *Self) void {
    const addr = self.read16();
    self.bus.write(addr, @truncate(self.regs._16.get(.sp)));
    self.bus.write(addr +% 1, @intCast(self.regs._16.get(.sp) >> 8));
}

fn ldHlSpImm(self: *Self) void {
    const unsigned: i16 = @as(i8, @bitCast(self.read8()));
    const offset: u16 = @bitCast(unsigned);
    const sp = self.regs._16.get(.sp);

    self.regs._16.set(.hl, sp +% offset);

    const carry = (sp & 0xFF) + (offset & 0xFF) > 0xFF;
    const half = (sp & 0xF) + (offset & 0xF) > 0xF;
    self.regs.f.c = @intFromBool(carry);
    self.regs.f.h = @intFromBool(half);
    self.regs.f.n = 0;
    self.regs.f.z = 0;

    self.bus.tick();
}

fn ldSpHl(self: *Self) void {
    const hl = self.regs._16.get(.hl);
    self.regs._16.set(.sp, hl);
    self.bus.tick();
}

fn inc(self: *Self, comptime loc: Location) void {
    const value = loc.get(self);

    self.regs.f.z = @intFromBool(value == 0);
    self.regs.f.n = 0;
    self.regs.f.h = @intFromBool(value & 0x0F == 0x0F);

    loc.set(self, value +% 1);
}

fn inc16(self: *Self, comptime reg: Reg16) void {
    const value = self.regs._16.get(reg);
    self.regs._16.set(reg, value +% 1);
    self.bus.tick();
}

fn dec(self: *Self, comptime loc: Location) void {
    const value = loc.get(self);

    self.regs.f.z = @intFromBool(value == 0);
    self.regs.f.n = 1;
    self.regs.f.h = @intFromBool(value & 0x0F == 0x00);

    loc.set(self, value -% 1);
}

fn dec16(self: *Self, comptime reg: Reg16) void {
    const value = self.regs._16.get(reg);
    self.regs._16.set(reg, value -% 1);
    self.bus.tick();
}

test "ld16" {
    var bus = Bus{ .test_bus = .{} };
    var cpu = init(&bus);
    const ram = &bus.test_bus.ram;

    ram[registers.start_addr] = 0x01;
    ram[registers.start_addr + 1] = 0xF0;
    ram[registers.start_addr + 2] = 0x0F;
    cpu.execute();
    try expect(cpu.regs._16.get(.bc) == 0x0FF0);
}

test "ld" {
    var bus = Bus{ .test_bus = .{} };
    var cpu = init(&bus);
    const ram = &bus.test_bus.ram;

    ram[registers.start_addr] = 0x41;
    cpu.regs._8.set(.b, 0x00);
    cpu.regs._8.set(.c, 0xFF);
    cpu.execute();
    try expect(cpu.regs._8.get(.b) == 0xFF);
}

test "inc" {
    var bus = Bus{ .test_bus = .{} };
    var cpu = init(&bus);
    const ram = &bus.test_bus.ram;

    cpu.regs._8.set(.h, 0x4F);
    ram[registers.start_addr] = 0x24;
    cpu.execute();

    try expect(cpu.regs._8.get(.h) == 0x50);
    try expect(cpu.regs.f.z == 0);
    try expect(cpu.regs.f.n == 0);
    try expect(cpu.regs.f.h == 1);
}

test "dec" {
    var bus = Bus{ .test_bus = .{} };
    var cpu = init(&bus);
    const ram = &bus.test_bus.ram;

    const dec_addr = 0x54F3;
    cpu.regs._16.set(.hl, dec_addr);
    ram[registers.start_addr] = 0x35;
    ram[dec_addr] = 0xA0;
    cpu.execute();

    try expect(ram[dec_addr] == 0x9F);
    try expect(cpu.regs.f.z == 0);
    try expect(cpu.regs.f.n == 1);
    try expect(cpu.regs.f.h == 1);
}
