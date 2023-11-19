const Self = @This();

pub const Reg8 = enum { a, f, b, c, d, e, h, l };
pub const Reg16 = enum { af, bc, de, hl, sp };

pub const Flags = packed union {
    bits: packed struct {
        _unused: u4,
        c: u1,
        h: u1,
        n: u1,
        z: u1,
    },
    raw: u8,
};

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

pub fn init() Self {
    return .{
        .a = 0x01,
        .f = .{ .raw = 0 },
        .b = 0xFF,
        .c = 0x13,
        .d = 0x00,
        .e = 0xC1,
        .h = 0x84,
        .l = 0x03,
        .sp = 0xFFFE,
        .pc = 0x0100,
    };
}

pub fn read16(self: *Self, comptime reg: Reg16) u16 {
    return switch (reg) {
        .af => @as(u16, self.a) << 8 | @as(u16, self.f.raw),
        .bc => @as(u16, self.b) << 8 | @as(u16, self.c),
        .de => @as(u16, self.d) << 8 | @as(u16, self.e),
        .hl => @as(u16, self.h) << 8 | @as(u16, self.l),
        .sp => self.sp,
    };
}

pub fn read8(self: *Self, comptime reg: Reg8) u8 {
    return switch (reg) {
        .a => self.a,
        .f => self.f.raw,
        .b => self.b,
        .c => self.c,
        .d => self.d,
        .e => self.e,
        .h => self.h,
        .l => self.l,
    };
}

pub fn write16(self: *Self, comptime reg: Reg16, value: u16) void {
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

pub fn write8(self: *Self, comptime reg: Reg8, value: u8) void {
    return switch (reg) {
        .a => self.a = value,
        .f => self.f.raw = value,
        .b => self.b = value,
        .c => self.c = value,
        .d => self.d = value,
        .e => self.e = value,
        .h => self.h = value,
        .l => self.l = value,
    };
}
