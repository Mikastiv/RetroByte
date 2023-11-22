const std = @import("std");
const expect = std.testing.expect;

pub const Reg8 = enum(u8) { f = 0, a = 1, c = 2, b = 3, e = 4, d = 5, l = 6, h = 7 };
pub const Reg16 = enum(u8) { af = 0, bc = 1, de = 2, hl = 3, sp = 4, pc = 5 };

pub fn RegisterArray(comptime Reg: type, comptime T: type) type {
    return extern struct {
        const len = @typeInfo(Reg).Enum.fields.len;
        data: [len]T,

        pub fn get(self: *const @This(), comptime reg: Reg) T {
            return self.data[@intFromEnum(reg)];
        }

        pub fn set(self: *@This(), comptime reg: Reg, value: T) void {
            self.data[@intFromEnum(reg)] = value;
        }
    };
}

pub const Flags = packed struct {
    _unused: u4,
    c: u1,
    h: u1,
    n: u1,
    z: u1,
};

pub const start_addr = 0x0100;

pub const Registers = extern union {
    const Self = @This();

    _16: RegisterArray(Reg16, u16),
    _8: RegisterArray(Reg8, u8),
    f: Flags,

    pub fn init() Self {
        var regs: RegisterArray(Reg16, u16) = undefined;
        regs.set(.af, 0x0100);
        regs.set(.bc, 0xFF13);
        regs.set(.de, 0x00C1);
        regs.set(.hl, 0x8403);
        regs.set(.sp, 0xFFFE);
        regs.set(.pc, start_addr);

        return .{
            ._16 = regs,
        };
    }

    pub fn incPc(self: *Self) void {
        const value = self._16.get(.pc);
        self._16.set(.pc, value +% 1);
    }
};

test "registers" {
    var regs: Registers = undefined;

    regs._8.set(.b, 0x7A);
    regs._8.set(.c, 0xFF);
    try expect(regs._16.get(.bc) == 0x7AFF);

    regs._16.set(.af, 0xBEEF);
    try expect(regs._8.get(.a) == 0xBE and regs._8.get(.f) == 0xEF);
    try expect(regs._16.get(.af) == 0xBEEF);
}

test "flags" {
    var regs: Registers = undefined;

    regs._8.set(.f, 0);
    regs.f.z = 1;
    try expect(regs._8.get(.f) == 0x80);
    regs.f.c = 1;
    try expect(regs._8.get(.f) == 0x90);
    regs.f.n = 1;
    try expect(regs._8.get(.f) == 0xD0);
}
