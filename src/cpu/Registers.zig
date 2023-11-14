const Self = @This();

pub const Regs8 = enum { a, f, b, c, d, e, h, l };
pub const Regs16 = enum { af, bc, de, hl, sp };

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
        .a = 0,
        .f = .{ .raw = 0 },
        .b = 0,
        .c = 0,
        .d = 0,
        .e = 0,
        .h = 0,
        .l = 0,
        .sp = 0,
        .pc = 0,
    };
}

pub fn read16(self: *Self, comptime reg: Regs16) u16 {
    return switch (reg) {
        .af => @as(u16, self.a) << 8 | @as(u16, self.f.raw),
        .bc => @as(u16, self.b) << 8 | @as(u16, self.c),
        .de => @as(u16, self.d) << 8 | @as(u16, self.e),
        .hl => @as(u16, self.h) << 8 | @as(u16, self.l),
        .sp => self.sp,
    };
}

pub fn write16(self: *Self, comptime reg: Regs16, value: u16) void {
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
