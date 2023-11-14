const std = @import("std");
const Self = @This();
const Registers = @import("cpu/Registers.zig");
const expect = std.testing.expect;

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
