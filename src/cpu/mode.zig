const Cpu = @import("../Cpu.zig");

pub const Mode = enum {
    a,
    f,
    b,
    c,
    d,
    e,
    h,
    l,
    addr_bc,
    addr_de,
    addr_hl,
    addr_hli,
    addr_hld,
    imm,
    imm_word,
    zero_page,
    zero_page_c,

    pub fn getAddress(comptime loc: Mode, cpu: *Cpu) u16 {
        return switch (loc) {
            .addr_bc => cpu.regs._16.get(.bc),
            .addr_de => cpu.regs._16.get(.de),
            .addr_hl => cpu.regs._16.get(.hl),
            .addr_hli => blk: {
                const addr = cpu.regs._16.get(.hl);
                cpu.regs._16.set(.hl, addr +% 1);
                break :blk addr;
            },
            .addr_hld => blk: {
                const addr = cpu.regs._16.get(.hl);
                cpu.regs._16.set(.hl, addr -% 1);
                break :blk addr;
            },
            .imm_word => cpu.read16(),
            .zero_page => blk: {
                const lo: u16 = cpu.read8();
                const addr = 0xFF00 | lo;
                break :blk addr;
            },
            .zero_page_c => blk: {
                const lo: u16 = cpu.regs._8.get(.c);
                const addr = 0xFF00 | lo;
                break :blk addr;
            },
            else => @compileError("incompatible address mode " ++ @tagName(loc)),
        };
    }

    pub fn get(comptime loc: Mode, cpu: *Cpu) u8 {
        return switch (loc) {
            .a => cpu.regs._8.get(.a),
            .f => cpu.regs._8.get(.f),
            .b => cpu.regs._8.get(.b),
            .c => cpu.regs._8.get(.c),
            .d => cpu.regs._8.get(.d),
            .e => cpu.regs._8.get(.e),
            .h => cpu.regs._8.get(.h),
            .l => cpu.regs._8.get(.l),
            .imm => cpu.read8(),
            else => value: {
                const addr = loc.getAddress(cpu);
                break :value cpu.bus.read(addr);
            },
        };
    }

    pub fn set(comptime loc: Mode, cpu: *Cpu, data: u8) void {
        switch (loc) {
            .a => cpu.regs._8.set(.a, data),
            .b => cpu.regs._8.set(.b, data),
            .c => cpu.regs._8.set(.c, data),
            .d => cpu.regs._8.set(.d, data),
            .e => cpu.regs._8.set(.e, data),
            .h => cpu.regs._8.set(.h, data),
            .l => cpu.regs._8.set(.l, data),
            else => {
                const addr = loc.getAddress(cpu);
                cpu.bus.write(addr, data);
            },
        }
    }
};
