const std = @import("std");
const Self = @This();

const Regs8 = enum { a, f, b, c, d, e, h, l };
const Regs16 = enum { af, bc, de, hl, sp, pc };

const Register = packed union {
    _16: u16,
    _8: packed struct {
        lo: u8,
        hi: u8,
    },
};

af: Register,
bc: Register,
de: Register,
hl: Register,
sp: Register,
pc: Register,

test "register" {
    var r: Register = undefined;
    r._8.lo = 5;
    r._8.hi = 1;
    try std.testing.expect(r._16 == 0x0105);

    r._16 = 0xFF0A;
    try std.testing.expect(r._8.lo == 0x0A and r._8.hi == 0xFF);
}
