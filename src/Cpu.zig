const std = @import("std");
const Self = @This();
const Registers = @import("cpu/Registers.zig");
const Bus = @import("bus.zig").Bus;
const expect = std.testing.expect;

regs: Registers,
bus: *Bus,

pub fn init(bus: *Bus) Self {
    return .{
        .bus = bus,
        .regs = Registers.init(),
    };
}

pub fn execute(self: *Self) void {
    _ = self;
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

test "bus" {
    const TestBus = @import("TestBus.zig");
    var test_bus = TestBus{};

    var cpu = Self{
        .regs = Registers.init(),
        .bus = test_bus.bus(),
    };

    test_bus.ram[0xFF34] = 0xBC;
    try expect(cpu.bus.read(0xFF34) == 0xBC);
}
