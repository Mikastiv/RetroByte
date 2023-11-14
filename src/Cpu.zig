const std = @import("std");
const Self = @This();
const expect = std.testing.expect;

const Regs8 = enum { a, f, b, c, d, e, h, l };
const Regs16 = enum { af, bc, de, hl, sp };

const Flags = packed union {
    bits: packed struct {
        _unused: u4,
        c: u1,
        h: u1,
        n: u1,
        z: u1,
    },
    raw: u8,
};

const Registers = struct {
    a: u8,
    f: Flags,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    h: u8,
    l: u8,
    sp: u16,
    pc: u16,

    fn read16(self: *Registers, comptime reg: Regs16) u16 {
        return switch (reg) {
            .af => @as(u16, self.a) << 8 | @as(u16, self.f.raw),
            .bc => @as(u16, self.b) << 8 | @as(u16, self.c),
            .de => @as(u16, self.d) << 8 | @as(u16, self.e),
            .hl => @as(u16, self.h) << 8 | @as(u16, self.l),
            .sp => self.sp,
        };
    }

    fn write16(self: *Registers, comptime reg: Regs16, value: u16) void {
        switch (reg) {
            .af => {
                self.a = @intCast(value >> 8);
                self.f.raw = @truncate(value);
            },
            .bc => {
                self.b = @intCast(value >> 8);
                self.c = @truncate(value);
            },
            .de => {
                self.d = @intCast(value >> 8);
                self.e = @truncate(value);
            },
            .hl => {
                self.h = @intCast(value >> 8);
                self.l = @truncate(value);
            },
            .sp => self.sp = value,
        }
    }
};

regs: Registers,

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
