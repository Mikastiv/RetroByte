const Cpu = @import("../Cpu.zig");
const Reg8 = @import("Registers.zig").Reg8;

pub const Address = enum {
    bc,
    de,
    hl,
    hli,
    hld,
    imm,
    zero_page,
    zero_page_c,
    absolute,

    fn get(cpu: *Cpu, comptime loc: Address) u16 {
        return switch (loc) {
            .bc => cpu.regs.read16(.bc),
            .de => cpu.regs.read16(.de),
            .hl => cpu.regs.read16(.hl),
            .hli => blk: {
                const addr = cpu.regs.read16(.hl);
                cpu.regs.write16(.hl, addr +% 1);
                break :blk addr;
            },
            .hld => blk: {
                const addr = cpu.regs.read16(.hl);
                cpu.regs.write16(.hl, addr -% 1);
                break :blk addr;
            },
            .imm => cpu.read8(),
            .zero_page => blk: {
                const lo: u16 = cpu.read8();
                const addr = 0xFF00 | lo;
                break :blk addr;
            },
            .zero_page_c => blk: {
                const lo: u16 = cpu.regs.c;
                const addr = 0xFF00 | lo;
                break :blk addr;
            },
            .absolute => cpu.read16(),
        };
    }
};

pub const Dst = union(enum) {
    reg8: Reg8,
    address: Address,

    pub fn write(comptime dst: Dst, cpu: *Cpu, data: u8) void {
        switch (dst) {
            .reg8 => |reg| cpu.regs.write8(reg, data),
            .address => |a| {
                const addr = Address.get(cpu, a);
                cpu.bus.write(addr, data);
            },
        }
    }
};

pub const Src = union(enum) {
    reg8: Reg8,
    address: Address,

    pub fn read(comptime src: Src, cpu: *Cpu) u8 {
        return switch (src) {
            .reg8 => |reg| cpu.regs.read8(reg),
            .address => |a| blk: {
                const addr = Address.get(cpu, a);
                break :blk cpu.bus.read(addr);
            },
        };
    }
};
