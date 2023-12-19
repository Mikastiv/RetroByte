const std = @import("std");
const registers = @import("registers.zig");
const interrupts = @import("interrupts.zig");
const bus = @import("bus.zig");
const debug = @import("debug.zig");
const options = @import("options");

const Registers = registers.Registers;
const Flags = registers.Flags;
const Reg16 = registers.Reg16;
const Reg8 = registers.Reg8;

pub const freq = 1048576.0;
pub const freq_ms = freq / 1000.0;

const RotateOp = enum { rl, rlc, rr, rrc };
const JumpCond = enum { c, z, nc, nz, always };

const Cpu = struct {
    regs: Registers = Registers.init(),
    halted: bool = false,
    halt_bug: bool = false,
    skip_interrupts: bool = false,
    ime: bool = false,
    enabling_ime: bool = false,
};

const Location = enum {
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
    absolute,
    zero_page,
    zero_page_c,

    fn getAddress(comptime loc: @This()) u16 {
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
            .absolute => read16(),
            .zero_page => blk: {
                const lo: u16 = read8();
                const addr = 0xFF00 | lo;
                break :blk addr;
            },
            .zero_page_c => blk: {
                const lo: u16 = cpu.regs._8.get(.c);
                const addr = 0xFF00 | lo;
                break :blk addr;
            },
            else => @compileError("incompatible address loc " ++ @tagName(loc)),
        };
    }

    fn getValue(comptime loc: @This()) u8 {
        return switch (loc) {
            .a => cpu.regs._8.get(.a),
            .f => cpu.regs._8.get(.f),
            .b => cpu.regs._8.get(.b),
            .c => cpu.regs._8.get(.c),
            .d => cpu.regs._8.get(.d),
            .e => cpu.regs._8.get(.e),
            .h => cpu.regs._8.get(.h),
            .l => cpu.regs._8.get(.l),
            .imm => read8(),
            else => value: {
                const addr = loc.getAddress();
                break :value bus.read(addr);
            },
        };
    }

    pub fn setValue(comptime loc: @This(), data: u8) void {
        switch (loc) {
            .a => cpu.regs._8.set(.a, data),
            .b => cpu.regs._8.set(.b, data),
            .c => cpu.regs._8.set(.c, data),
            .d => cpu.regs._8.set(.d, data),
            .e => cpu.regs._8.set(.e, data),
            .h => cpu.regs._8.set(.h, data),
            .l => cpu.regs._8.set(.l, data),
            else => {
                const addr = loc.getAddress();
                bus.write(addr, data);
            },
        }
    }
};

var cpu: Cpu = undefined;

pub fn init() void {
    cpu = .{};
    bus.init();
}

fn elapsedCycles(start: u128) u128 {
    return bus.cycles - start;
}

pub fn step() u128 {
    debug.update();
    debug.print();

    const cycles_start = bus.cycles;
    const ime = cpu.ime;

    if (cpu.enabling_ime) {
        cpu.ime = true;
        cpu.enabling_ime = false;
    }

    if (cpu.halted) bus.tick();

    if (cpu.halted and !ime and interrupts.any()) {
        cpu.halted = false;
    } else if (ime and interrupts.any()) {
        handleInterrupt();
    } else if (!cpu.halted) {
        execute();
    }

    return elapsedCycles(cycles_start);
}

fn handleInterrupt() void {
    cpu.halted = false;
    bus.tick();
    bus.tick();

    stackPush(cpu.regs.pc());

    const interrupt = interrupts.highestPriority();
    const addr: u16 = switch (interrupt) {
        .vblank => 0x0040,
        .stat => 0x0048,
        .timer => 0x0050,
        .serial => 0x0058,
        .joypad => 0x0060,
    };
    cpu.regs._16.set(.pc, addr);

    cpu.ime = false;
    interrupts.handled(interrupt);
}

fn read8() u8 {
    const byte: u8 = bus.read(cpu.regs.pc());
    cpu.regs.incPc();
    return byte;
}

fn read16() u16 {
    const lo: u16 = read8();
    const hi: u16 = read8();
    return hi << 8 | lo;
}

fn shouldJump(flags: Flags, comptime cond: JumpCond) bool {
    return switch (cond) {
        .c => flags.c,
        .z => flags.z,
        .nc => !flags.c,
        .nz => !flags.z,
        .always => true,
    };
}

fn jump(addr: u16) void {
    cpu.regs._16.set(.pc, addr);
    bus.tick();
}

fn jumpRelative(offset: i8) void {
    const offset16: u16 = @bitCast(@as(i16, offset));
    const pc = cpu.regs.pc();
    jump(pc +% offset16);
}

fn stackPush(value: u16) void {
    bus.tick();

    const hi: u8 = @intCast(value >> 8);
    const lo: u8 = @truncate(value);

    cpu.regs.decSp();
    bus.write(cpu.regs.sp(), hi);
    cpu.regs.decSp();
    bus.write(cpu.regs.sp(), lo);
}

fn stackPop() u16 {
    const lo: u16 = bus.read(cpu.regs.sp());
    cpu.regs.incSp();
    const hi: u16 = bus.read(cpu.regs.sp());
    cpu.regs.incSp();

    return hi << 8 | lo;
}

fn nop() void {}

fn panic() noreturn {
    @panic("illegal instruction");
}

fn ld(comptime dst: Location, comptime src: Location) void {
    const value = src.getValue();
    dst.setValue(value);
}

fn ld16(comptime reg: Reg16) void {
    const value = read16();
    cpu.regs._16.set(reg, value);
}

fn ldAbsSp() void {
    const addr = read16();
    const sp = cpu.regs.sp();
    bus.write(addr, @truncate(sp));
    bus.write(addr +% 1, @intCast(sp >> 8));
}

fn ldHlSpImm() void {
    const signed: i16 = @as(i8, @bitCast(read8()));
    const offset: u16 = @bitCast(signed);
    const sp = cpu.regs.sp();

    cpu.regs._16.set(.hl, sp +% offset);

    const carry = (sp & 0xFF) + (offset & 0xFF) > 0xFF;
    const half = (sp & 0xF) + (offset & 0xF) > 0xF;
    cpu.regs.f.c = carry;
    cpu.regs.f.h = half;
    cpu.regs.f.n = false;
    cpu.regs.f.z = false;

    bus.tick();
}

fn ldSpHl() void {
    const hl = cpu.regs._16.get(.hl);
    cpu.regs._16.set(.sp, hl);
    bus.tick();
}

fn inc(comptime loc: Location) void {
    const value = loc.getValue();
    const new_value = value +% 1;

    cpu.regs.f.h = value & 0x0F == 0x0F;
    cpu.regs.f.n = false;
    cpu.regs.f.z = new_value == 0;

    loc.setValue(new_value);
}

fn inc16(comptime reg: Reg16) void {
    const value = cpu.regs._16.get(reg);
    cpu.regs._16.set(reg, value +% 1);
    bus.tick();
}

fn dec(comptime loc: Location) void {
    const value = loc.getValue();
    const new_value = value -% 1;

    cpu.regs.f.h = value & 0x0F == 0x00;
    cpu.regs.f.n = true;
    cpu.regs.f.z = new_value == 0;

    loc.setValue(new_value);
}

fn dec16(comptime reg: Reg16) void {
    const value = cpu.regs._16.get(reg);
    cpu.regs._16.set(reg, value -% 1);
    bus.tick();
}

fn aluAdd(value: u8, cy: u1) void {
    const a = cpu.regs._8.get(.a);
    const result: u16 = @as(u16, a) + @as(u16, value) + cy;

    cpu.regs.f.c = result > 0xFF;
    cpu.regs.f.h = (a & 0x0F) + (value & 0x0F) + cy > 0x0F;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result & 0xFF == 0;

    cpu.regs._8.set(.a, @truncate(result));
}

fn add(comptime loc: Location) void {
    const value = loc.getValue();
    aluAdd(value, 0);
}

fn adc(comptime loc: Location) void {
    const value = loc.getValue();
    aluAdd(value, @intFromBool(cpu.regs.f.c));
}

fn addSp() void {
    const signed: i16 = @as(i8, @bitCast(read8()));
    const value: u16 = @bitCast(signed);
    const sp = cpu.regs.sp();

    cpu.regs.f.c = (sp & 0x00FF) + (value & 0x00FF) > 0x00FF;
    cpu.regs.f.h = (sp & 0x000F) + (value & 0x000F) > 0x000F;
    cpu.regs.f.n = false;
    cpu.regs.f.z = false;

    cpu.regs._16.set(.sp, sp +% value);

    bus.tick();
    bus.tick();
}

fn add16(comptime reg: Reg16) void {
    const value = cpu.regs._16.get(reg);
    const hl = cpu.regs._16.get(.hl);
    const result, const carry = @addWithOverflow(hl, value);

    cpu.regs.f.c = carry != 0;
    cpu.regs.f.h = (hl & 0x0FFF) + (value & 0x0FFF) > 0x0FFF;
    cpu.regs.f.n = false;

    cpu.regs._16.set(.hl, result);

    bus.tick();
}

fn aluSub(value: u8, cy: u1) u8 {
    const a = cpu.regs._8.get(.a);
    const result = a -% value -% cy;

    cpu.regs.f.c = @as(u16, a) < @as(u16, value) + cy;
    cpu.regs.f.h = (a & 0x0F) < (value & 0x0F) + cy;
    cpu.regs.f.n = true;
    cpu.regs.f.z = result == 0;

    return result;
}

fn sub(comptime loc: Location) void {
    const value = loc.getValue();
    const result = aluSub(value, 0);
    cpu.regs._8.set(.a, result);
}

fn sbc(comptime loc: Location) void {
    const value = loc.getValue();
    const result = aluSub(value, @intFromBool(cpu.regs.f.c));
    cpu.regs._8.set(.a, result);
}

fn bitAnd(comptime loc: Location) void {
    const value = loc.getValue();
    const result = cpu.regs._8.get(.a) & value;

    cpu.regs.f.c = false;
    cpu.regs.f.h = true;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    cpu.regs._8.set(.a, result);
}

fn bitXor(comptime loc: Location) void {
    const value = loc.getValue();
    const result = cpu.regs._8.get(.a) ^ value;

    cpu.regs.f.c = false;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    cpu.regs._8.set(.a, result);
}

fn bitOr(comptime loc: Location) void {
    const value = loc.getValue();
    const result = cpu.regs._8.get(.a) | value;

    cpu.regs.f.c = false;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    cpu.regs._8.set(.a, result);
}

fn cp(comptime loc: Location) void {
    const value = loc.getValue();
    _ = aluSub(value, 0);
}

fn jr(comptime cond: JumpCond) void {
    const offset: i8 = @bitCast(read8());
    if (shouldJump(cpu.regs.f, cond)) {
        jumpRelative(offset);
    }
}

fn jp(comptime cond: JumpCond) void {
    const addr = read16();
    if (shouldJump(cpu.regs.f, cond)) {
        jump(addr);
    }
}

fn jpHl() void {
    const hl = cpu.regs._16.get(.hl);
    cpu.regs._16.set(.pc, hl);
}

fn daa() void {
    var adjust: u8 = 0;
    var carry = false;

    var a = cpu.regs._8.get(.a);
    const c = cpu.regs.f.c;
    const n = cpu.regs.f.n;
    const h = cpu.regs.f.h;

    if (h or (!n and a & 0x0F > 0x09)) {
        adjust = 0x06;
    }

    if (c or (!n and a > 0x99)) {
        adjust |= 0x60;
        carry = true;
    }

    if (n) {
        a -%= adjust;
    } else {
        a +%= adjust;
    }

    cpu.regs._8.set(.a, a);
    cpu.regs.f.c = carry;
    cpu.regs.f.z = a == 0;
    cpu.regs.f.h = false;
}

fn scf() void {
    cpu.regs.f.c = true;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
}

fn cpl() void {
    const a = cpu.regs._8.get(.a);
    cpu.regs._8.set(.a, ~a);

    cpu.regs.f.h = true;
    cpu.regs.f.n = true;
}

fn ccf() void {
    cpu.regs.f.c = !cpu.regs.f.c;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
}

fn push(comptime reg: Reg16) void {
    const value = cpu.regs._16.get(reg);
    stackPush(value);
}

fn pop(comptime reg: Reg16) void {
    const value = stackPop();
    cpu.regs._16.set(reg, value);

    // Clear unused flags bits; they didn't exist on real hardware
    if (reg == .af) cpu.regs.f._unused = 0;
}

fn call(comptime cond: JumpCond) void {
    const addr = read16();
    if (shouldJump(cpu.regs.f, cond)) {
        stackPush(cpu.regs.pc());
        cpu.regs._16.set(.pc, addr);
    }
}

fn ret(comptime cond: JumpCond) void {
    if (cond != .always) bus.tick();
    if (shouldJump(cpu.regs.f, cond)) {
        const addr = stackPop();
        jump(addr);
    }
}

fn reti() void {
    cpu.ime = true;
    ret(.always);
}

fn rst(comptime addr: u8) void {
    stackPush(cpu.regs.pc());
    cpu.regs._16.set(.pc, addr);
}

fn stop() void {
    @panic("stop instruction");
}

fn halt() void {
    if (interrupts.any()) {
        if (cpu.ime) {
            cpu.halted = true;
        } else {
            cpu.halted = false;
            cpu.halt_bug = true;
        }
    } else {
        cpu.halted = true;
    }
}

fn ei() void {
    if (!cpu.ime and !cpu.enabling_ime) {
        cpu.enabling_ime = true;
    }
}

fn di() void {
    cpu.ime = false;
    cpu.enabling_ime = false;
}

fn aluRotateRight(value: u8, cy: u1) u8 {
    const result = @as(u8, cy) << 7 | value >> 1;

    cpu.regs.f.c = value & 0x01 != 0;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    return result;
}

fn aluRotateLeft(value: u8, cy: u1) u8 {
    const result = value << 1 | cy;

    cpu.regs.f.c = value & 0x80 != 0;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    return result;
}

fn rotateA(comptime op: RotateOp) void {
    const value = cpu.regs._8.get(.a);
    const result = switch (op) {
        .rl => aluRotateLeft(value, @intFromBool(cpu.regs.f.c)),
        .rlc => aluRotateLeft(value, @intCast(value >> 7)),
        .rr => aluRotateRight(value, @intFromBool(cpu.regs.f.c)),
        .rrc => aluRotateRight(value, @intCast(value & 0x01)),
    };

    cpu.regs.f.z = false;
    cpu.regs._8.set(.a, result);
}

fn rotate(comptime loc: Location, comptime op: RotateOp) void {
    const value = loc.getValue();
    const result = switch (op) {
        .rl => aluRotateLeft(value, @intFromBool(cpu.regs.f.c)),
        .rlc => aluRotateLeft(value, @intCast(value >> 7)),
        .rr => aluRotateRight(value, @intFromBool(cpu.regs.f.c)),
        .rrc => aluRotateRight(value, @intCast(value & 0x01)),
    };
    loc.setValue(result);
}

fn sla(comptime loc: Location) void {
    const value = loc.getValue();
    const result = value << 1;

    cpu.regs.f.c = value & 0x80 != 0;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    loc.setValue(result);
}

fn sra(comptime loc: Location) void {
    const value = loc.getValue();
    const hi = value & 0x80;
    const result = hi | value >> 1;

    cpu.regs.f.c = value & 0x01 != 0;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    loc.setValue(result);
}

fn srl(comptime loc: Location) void {
    const value = loc.getValue();
    const result = value >> 1;

    cpu.regs.f.c = value & 0x01 != 0;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    loc.setValue(result);
}

fn swap(comptime loc: Location) void {
    const value = loc.getValue();
    const result = value >> 4 | value << 4;

    cpu.regs.f.c = false;
    cpu.regs.f.h = false;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;

    loc.setValue(result);
}

fn bit(comptime loc: Location, comptime n: u3) void {
    const value = loc.getValue();
    const result = value & (1 << n);

    cpu.regs.f.h = true;
    cpu.regs.f.n = false;
    cpu.regs.f.z = result == 0;
}

fn set(comptime loc: Location, comptime n: u3) void {
    const value = loc.getValue();
    const result = value | 1 << n;
    loc.setValue(result);
}

fn res(comptime loc: Location, comptime n: u3) void {
    const value = loc.getValue();
    const result = value & ~@as(u8, 1 << n);
    loc.setValue(result);
}

fn execute() void {
    if (options.disassemble) debug.disassemble(bus.peek(cpu.regs.pc()), cpu.regs) catch unreachable;

    const opcode = read8();
    if (cpu.halt_bug) {
        cpu.halt_bug = false;
        const pc = cpu.regs.pc();
        cpu.regs._16.set(.pc, pc -% 1);
    }

    switch (opcode) {
        0x00 => nop(),
        0x01 => ld16(.bc),
        0x02 => ld(.addr_bc, .a),
        0x03 => inc16(.bc),
        0x04 => inc(.b),
        0x05 => dec(.b),
        0x06 => ld(.b, .imm),
        0x07 => rotateA(.rlc),
        0x08 => ldAbsSp(),
        0x09 => add16(.bc),
        0x0A => ld(.a, .addr_bc),
        0x0B => dec16(.bc),
        0x0C => inc(.c),
        0x0D => dec(.c),
        0x0E => ld(.c, .imm),
        0x0F => rotateA(.rrc),
        0x10 => stop(),
        0x11 => ld16(.de),
        0x12 => ld(.addr_de, .a),
        0x13 => inc16(.de),
        0x14 => inc(.d),
        0x15 => dec(.d),
        0x16 => ld(.d, .imm),
        0x17 => rotateA(.rl),
        0x18 => jr(.always),
        0x19 => add16(.de),
        0x1A => ld(.a, .addr_de),
        0x1B => dec16(.de),
        0x1C => inc(.e),
        0x1D => dec(.e),
        0x1E => ld(.e, .imm),
        0x1F => rotateA(.rr),
        0x20 => jr(.nz),
        0x21 => ld16(.hl),
        0x22 => ld(.addr_hli, .a),
        0x23 => inc16(.hl),
        0x24 => inc(.h),
        0x25 => dec(.h),
        0x26 => ld(.h, .imm),
        0x27 => daa(),
        0x28 => jr(.z),
        0x29 => add16(.hl),
        0x2A => ld(.a, .addr_hli),
        0x2B => dec16(.hl),
        0x2C => inc(.l),
        0x2D => dec(.l),
        0x2E => ld(.l, .imm),
        0x2F => cpl(),
        0x30 => jr(.nc),
        0x31 => ld16(.sp),
        0x32 => ld(.addr_hld, .a),
        0x33 => inc16(.sp),
        0x34 => inc(.addr_hl),
        0x35 => dec(.addr_hl),
        0x36 => ld(.addr_hl, .imm),
        0x37 => scf(),
        0x38 => jr(.c),
        0x39 => add16(.sp),
        0x3A => ld(.a, .addr_hld),
        0x3B => dec16(.sp),
        0x3C => inc(.a),
        0x3D => dec(.a),
        0x3E => ld(.a, .imm),
        0x3F => ccf(),
        0x40 => ld(.b, .b),
        0x41 => ld(.b, .c),
        0x42 => ld(.b, .d),
        0x43 => ld(.b, .e),
        0x44 => ld(.b, .h),
        0x45 => ld(.b, .l),
        0x46 => ld(.b, .addr_hl),
        0x47 => ld(.b, .a),
        0x48 => ld(.c, .b),
        0x49 => ld(.c, .c),
        0x4A => ld(.c, .d),
        0x4B => ld(.c, .e),
        0x4C => ld(.c, .h),
        0x4D => ld(.c, .l),
        0x4E => ld(.c, .addr_hl),
        0x4F => ld(.c, .a),
        0x50 => ld(.d, .b),
        0x51 => ld(.d, .c),
        0x52 => ld(.d, .d),
        0x53 => ld(.d, .e),
        0x54 => ld(.d, .h),
        0x55 => ld(.d, .l),
        0x56 => ld(.d, .addr_hl),
        0x57 => ld(.d, .a),
        0x58 => ld(.e, .b),
        0x59 => ld(.e, .c),
        0x5A => ld(.e, .d),
        0x5B => ld(.e, .e),
        0x5C => ld(.e, .h),
        0x5D => ld(.e, .l),
        0x5E => ld(.e, .addr_hl),
        0x5F => ld(.e, .a),
        0x60 => ld(.h, .b),
        0x61 => ld(.h, .c),
        0x62 => ld(.h, .d),
        0x63 => ld(.h, .e),
        0x64 => ld(.h, .h),
        0x65 => ld(.h, .l),
        0x66 => ld(.h, .addr_hl),
        0x67 => ld(.h, .a),
        0x68 => ld(.l, .b),
        0x69 => ld(.l, .c),
        0x6A => ld(.l, .d),
        0x6B => ld(.l, .e),
        0x6C => ld(.l, .h),
        0x6D => ld(.l, .l),
        0x6E => ld(.l, .addr_hl),
        0x6F => ld(.l, .a),
        0x70 => ld(.addr_hl, .b),
        0x71 => ld(.addr_hl, .c),
        0x72 => ld(.addr_hl, .d),
        0x73 => ld(.addr_hl, .e),
        0x74 => ld(.addr_hl, .h),
        0x75 => ld(.addr_hl, .l),
        0x76 => halt(),
        0x77 => ld(.addr_hl, .a),
        0x78 => ld(.a, .b),
        0x79 => ld(.a, .c),
        0x7A => ld(.a, .d),
        0x7B => ld(.a, .e),
        0x7C => ld(.a, .h),
        0x7D => ld(.a, .l),
        0x7E => ld(.a, .addr_hl),
        0x7F => ld(.a, .a),
        0x80 => add(.b),
        0x81 => add(.c),
        0x82 => add(.d),
        0x83 => add(.e),
        0x84 => add(.h),
        0x85 => add(.l),
        0x86 => add(.addr_hl),
        0x87 => add(.a),
        0x88 => adc(.b),
        0x89 => adc(.c),
        0x8A => adc(.d),
        0x8B => adc(.e),
        0x8C => adc(.h),
        0x8D => adc(.l),
        0x8E => adc(.addr_hl),
        0x8F => adc(.a),
        0x90 => sub(.b),
        0x91 => sub(.c),
        0x92 => sub(.d),
        0x93 => sub(.e),
        0x94 => sub(.h),
        0x95 => sub(.l),
        0x96 => sub(.addr_hl),
        0x97 => sub(.a),
        0x98 => sbc(.b),
        0x99 => sbc(.c),
        0x9A => sbc(.d),
        0x9B => sbc(.e),
        0x9C => sbc(.h),
        0x9D => sbc(.l),
        0x9E => sbc(.addr_hl),
        0x9F => sbc(.a),
        0xA0 => bitAnd(.b),
        0xA1 => bitAnd(.c),
        0xA2 => bitAnd(.d),
        0xA3 => bitAnd(.e),
        0xA4 => bitAnd(.h),
        0xA5 => bitAnd(.l),
        0xA6 => bitAnd(.addr_hl),
        0xA7 => bitAnd(.a),
        0xA8 => bitXor(.b),
        0xA9 => bitXor(.c),
        0xAA => bitXor(.d),
        0xAB => bitXor(.e),
        0xAC => bitXor(.h),
        0xAD => bitXor(.l),
        0xAE => bitXor(.addr_hl),
        0xAF => bitXor(.a),
        0xB0 => bitOr(.b),
        0xB1 => bitOr(.c),
        0xB2 => bitOr(.d),
        0xB3 => bitOr(.e),
        0xB4 => bitOr(.h),
        0xB5 => bitOr(.l),
        0xB6 => bitOr(.addr_hl),
        0xB7 => bitOr(.a),
        0xB8 => cp(.b),
        0xB9 => cp(.c),
        0xBA => cp(.d),
        0xBB => cp(.e),
        0xBC => cp(.h),
        0xBD => cp(.l),
        0xBE => cp(.addr_hl),
        0xBF => cp(.a),
        0xC0 => ret(.nz),
        0xC1 => pop(.bc),
        0xC2 => jp(.nz),
        0xC3 => jp(.always),
        0xC4 => call(.nz),
        0xC5 => push(.bc),
        0xC6 => add(.imm),
        0xC7 => rst(0x00),
        0xC8 => ret(.z),
        0xC9 => ret(.always),
        0xCA => jp(.z),
        0xCB => prefixCb(),
        0xCC => call(.z),
        0xCD => call(.always),
        0xCE => adc(.imm),
        0xCF => rst(0x08),
        0xD0 => ret(.nc),
        0xD1 => pop(.de),
        0xD2 => jp(.nc),
        0xD3 => panic(),
        0xD4 => call(.nc),
        0xD5 => push(.de),
        0xD6 => sub(.imm),
        0xD7 => rst(0x10),
        0xD8 => ret(.c),
        0xD9 => reti(),
        0xDA => jp(.c),
        0xDB => panic(),
        0xDC => call(.c),
        0xDD => panic(),
        0xDE => sbc(.imm),
        0xDF => rst(0x18),
        0xE0 => ld(.zero_page, .a),
        0xE1 => pop(.hl),
        0xE2 => ld(.zero_page_c, .a),
        0xE3 => panic(),
        0xE4 => panic(),
        0xE5 => push(.hl),
        0xE6 => bitAnd(.imm),
        0xE7 => rst(0x20),
        0xE8 => addSp(),
        0xE9 => jpHl(),
        0xEA => ld(.absolute, .a),
        0xEB => panic(),
        0xEC => panic(),
        0xED => panic(),
        0xEE => bitXor(.imm),
        0xEF => rst(0x28),
        0xF0 => ld(.a, .zero_page),
        0xF1 => pop(.af),
        0xF2 => ld(.a, .zero_page_c),
        0xF3 => di(),
        0xF4 => panic(),
        0xF5 => push(.af),
        0xF6 => bitOr(.imm),
        0xF7 => rst(0x30),
        0xF8 => ldHlSpImm(),
        0xF9 => ldSpHl(),
        0xFA => ld(.a, .absolute),
        0xFB => ei(),
        0xFC => panic(),
        0xFD => panic(),
        0xFE => cp(.imm),
        0xFF => rst(0x38),
    }
}

fn prefixCb() void {
    const opcode = read8();
    switch (opcode) {
        0x00 => rotate(.b, .rlc),
        0x01 => rotate(.c, .rlc),
        0x02 => rotate(.d, .rlc),
        0x03 => rotate(.e, .rlc),
        0x04 => rotate(.h, .rlc),
        0x05 => rotate(.l, .rlc),
        0x06 => rotate(.addr_hl, .rlc),
        0x07 => rotate(.a, .rlc),
        0x08 => rotate(.b, .rrc),
        0x09 => rotate(.c, .rrc),
        0x0A => rotate(.d, .rrc),
        0x0B => rotate(.e, .rrc),
        0x0C => rotate(.h, .rrc),
        0x0D => rotate(.l, .rrc),
        0x0E => rotate(.addr_hl, .rrc),
        0x0F => rotate(.a, .rrc),
        0x10 => rotate(.b, .rl),
        0x11 => rotate(.c, .rl),
        0x12 => rotate(.d, .rl),
        0x13 => rotate(.e, .rl),
        0x14 => rotate(.h, .rl),
        0x15 => rotate(.l, .rl),
        0x16 => rotate(.addr_hl, .rl),
        0x17 => rotate(.a, .rl),
        0x18 => rotate(.b, .rr),
        0x19 => rotate(.c, .rr),
        0x1A => rotate(.d, .rr),
        0x1B => rotate(.e, .rr),
        0x1C => rotate(.h, .rr),
        0x1D => rotate(.l, .rr),
        0x1E => rotate(.addr_hl, .rr),
        0x1F => rotate(.a, .rr),
        0x20 => sla(.b),
        0x21 => sla(.c),
        0x22 => sla(.d),
        0x23 => sla(.e),
        0x24 => sla(.h),
        0x25 => sla(.l),
        0x26 => sla(.addr_hl),
        0x27 => sla(.a),
        0x28 => sra(.b),
        0x29 => sra(.c),
        0x2A => sra(.d),
        0x2B => sra(.e),
        0x2C => sra(.h),
        0x2D => sra(.l),
        0x2E => sra(.addr_hl),
        0x2F => sra(.a),
        0x30 => swap(.b),
        0x31 => swap(.c),
        0x32 => swap(.d),
        0x33 => swap(.e),
        0x34 => swap(.h),
        0x35 => swap(.l),
        0x36 => swap(.addr_hl),
        0x37 => swap(.a),
        0x38 => srl(.b),
        0x39 => srl(.c),
        0x3A => srl(.d),
        0x3B => srl(.e),
        0x3C => srl(.h),
        0x3D => srl(.l),
        0x3E => srl(.addr_hl),
        0x3F => srl(.a),
        0x40 => bit(.b, 0),
        0x41 => bit(.c, 0),
        0x42 => bit(.d, 0),
        0x43 => bit(.e, 0),
        0x44 => bit(.h, 0),
        0x45 => bit(.l, 0),
        0x46 => bit(.addr_hl, 0),
        0x47 => bit(.a, 0),
        0x48 => bit(.b, 1),
        0x49 => bit(.c, 1),
        0x4A => bit(.d, 1),
        0x4B => bit(.e, 1),
        0x4C => bit(.h, 1),
        0x4D => bit(.l, 1),
        0x4E => bit(.addr_hl, 1),
        0x4F => bit(.a, 1),
        0x50 => bit(.b, 2),
        0x51 => bit(.c, 2),
        0x52 => bit(.d, 2),
        0x53 => bit(.e, 2),
        0x54 => bit(.h, 2),
        0x55 => bit(.l, 2),
        0x56 => bit(.addr_hl, 2),
        0x57 => bit(.a, 2),
        0x58 => bit(.b, 3),
        0x59 => bit(.c, 3),
        0x5A => bit(.d, 3),
        0x5B => bit(.e, 3),
        0x5C => bit(.h, 3),
        0x5D => bit(.l, 3),
        0x5E => bit(.addr_hl, 3),
        0x5F => bit(.a, 3),
        0x60 => bit(.b, 4),
        0x61 => bit(.c, 4),
        0x62 => bit(.d, 4),
        0x63 => bit(.e, 4),
        0x64 => bit(.h, 4),
        0x65 => bit(.l, 4),
        0x66 => bit(.addr_hl, 4),
        0x67 => bit(.a, 4),
        0x68 => bit(.b, 5),
        0x69 => bit(.c, 5),
        0x6A => bit(.d, 5),
        0x6B => bit(.e, 5),
        0x6C => bit(.h, 5),
        0x6D => bit(.l, 5),
        0x6E => bit(.addr_hl, 5),
        0x6F => bit(.a, 5),
        0x70 => bit(.b, 6),
        0x71 => bit(.c, 6),
        0x72 => bit(.d, 6),
        0x73 => bit(.e, 6),
        0x74 => bit(.h, 6),
        0x75 => bit(.l, 6),
        0x76 => bit(.addr_hl, 6),
        0x77 => bit(.a, 6),
        0x78 => bit(.b, 7),
        0x79 => bit(.c, 7),
        0x7A => bit(.d, 7),
        0x7B => bit(.e, 7),
        0x7C => bit(.h, 7),
        0x7D => bit(.l, 7),
        0x7E => bit(.addr_hl, 7),
        0x7F => bit(.a, 7),
        0x80 => res(.b, 0),
        0x81 => res(.c, 0),
        0x82 => res(.d, 0),
        0x83 => res(.e, 0),
        0x84 => res(.h, 0),
        0x85 => res(.l, 0),
        0x86 => res(.addr_hl, 0),
        0x87 => res(.a, 0),
        0x88 => res(.b, 1),
        0x89 => res(.c, 1),
        0x8A => res(.d, 1),
        0x8B => res(.e, 1),
        0x8C => res(.h, 1),
        0x8D => res(.l, 1),
        0x8E => res(.addr_hl, 1),
        0x8F => res(.a, 1),
        0x90 => res(.b, 2),
        0x91 => res(.c, 2),
        0x92 => res(.d, 2),
        0x93 => res(.e, 2),
        0x94 => res(.h, 2),
        0x95 => res(.l, 2),
        0x96 => res(.addr_hl, 2),
        0x97 => res(.a, 2),
        0x98 => res(.b, 3),
        0x99 => res(.c, 3),
        0x9A => res(.d, 3),
        0x9B => res(.e, 3),
        0x9C => res(.h, 3),
        0x9D => res(.l, 3),
        0x9E => res(.addr_hl, 3),
        0x9F => res(.a, 3),
        0xA0 => res(.b, 4),
        0xA1 => res(.c, 4),
        0xA2 => res(.d, 4),
        0xA3 => res(.e, 4),
        0xA4 => res(.h, 4),
        0xA5 => res(.l, 4),
        0xA6 => res(.addr_hl, 4),
        0xA7 => res(.a, 4),
        0xA8 => res(.b, 5),
        0xA9 => res(.c, 5),
        0xAA => res(.d, 5),
        0xAB => res(.e, 5),
        0xAC => res(.h, 5),
        0xAD => res(.l, 5),
        0xAE => res(.addr_hl, 5),
        0xAF => res(.a, 5),
        0xB0 => res(.b, 6),
        0xB1 => res(.c, 6),
        0xB2 => res(.d, 6),
        0xB3 => res(.e, 6),
        0xB4 => res(.h, 6),
        0xB5 => res(.l, 6),
        0xB6 => res(.addr_hl, 6),
        0xB7 => res(.a, 6),
        0xB8 => res(.b, 7),
        0xB9 => res(.c, 7),
        0xBA => res(.d, 7),
        0xBB => res(.e, 7),
        0xBC => res(.h, 7),
        0xBD => res(.l, 7),
        0xBE => res(.addr_hl, 7),
        0xBF => res(.a, 7),
        0xC0 => set(.b, 0),
        0xC1 => set(.c, 0),
        0xC2 => set(.d, 0),
        0xC3 => set(.e, 0),
        0xC4 => set(.h, 0),
        0xC5 => set(.l, 0),
        0xC6 => set(.addr_hl, 0),
        0xC7 => set(.a, 0),
        0xC8 => set(.b, 1),
        0xC9 => set(.c, 1),
        0xCA => set(.d, 1),
        0xCB => set(.e, 1),
        0xCC => set(.h, 1),
        0xCD => set(.l, 1),
        0xCE => set(.addr_hl, 1),
        0xCF => set(.a, 1),
        0xD0 => set(.b, 2),
        0xD1 => set(.c, 2),
        0xD2 => set(.d, 2),
        0xD3 => set(.e, 2),
        0xD4 => set(.h, 2),
        0xD5 => set(.l, 2),
        0xD6 => set(.addr_hl, 2),
        0xD7 => set(.a, 2),
        0xD8 => set(.b, 3),
        0xD9 => set(.c, 3),
        0xDA => set(.d, 3),
        0xDB => set(.e, 3),
        0xDC => set(.h, 3),
        0xDD => set(.l, 3),
        0xDE => set(.addr_hl, 3),
        0xDF => set(.a, 3),
        0xE0 => set(.b, 4),
        0xE1 => set(.c, 4),
        0xE2 => set(.d, 4),
        0xE3 => set(.e, 4),
        0xE4 => set(.h, 4),
        0xE5 => set(.l, 4),
        0xE6 => set(.addr_hl, 4),
        0xE7 => set(.a, 4),
        0xE8 => set(.b, 5),
        0xE9 => set(.c, 5),
        0xEA => set(.d, 5),
        0xEB => set(.e, 5),
        0xEC => set(.h, 5),
        0xED => set(.l, 5),
        0xEE => set(.addr_hl, 5),
        0xEF => set(.a, 5),
        0xF0 => set(.b, 6),
        0xF1 => set(.c, 6),
        0xF2 => set(.d, 6),
        0xF3 => set(.e, 6),
        0xF4 => set(.h, 6),
        0xF5 => set(.l, 6),
        0xF6 => set(.addr_hl, 6),
        0xF7 => set(.a, 6),
        0xF8 => set(.b, 7),
        0xF9 => set(.c, 7),
        0xFA => set(.d, 7),
        0xFB => set(.e, 7),
        0xFC => set(.h, 7),
        0xFD => set(.l, 7),
        0xFE => set(.addr_hl, 7),
        0xFF => set(.a, 7),
    }
}

const expect = std.testing.expect;
const test_start_addr = 0xC000;

fn test_init() void {
    init();
    cpu.regs._16.set(.pc, test_start_addr);
}

test "ld16" {
    test_init();

    bus.write(test_start_addr, 0x01);
    bus.write(test_start_addr + 1, 0xF0);
    bus.write(test_start_addr + 2, 0x0F);
    step();
    try expect(cpu.regs._16.get(.bc) == 0x0FF0);
}

test "ld" {
    test_init();

    bus.write(test_start_addr, 0x41);
    cpu.regs._8.set(.b, 0x00);
    cpu.regs._8.set(.c, 0xFF);
    step();
    try expect(cpu.regs._8.get(.b) == 0xFF);
}

test "inc" {
    test_init();

    cpu.regs._8.set(.h, 0x4F);
    bus.write(test_start_addr, 0x24);
    step();

    try expect(cpu.regs._8.get(.h) == 0x50);
    try expect(cpu.regs.f.z == false);
    try expect(cpu.regs.f.n == false);
    try expect(cpu.regs.f.h == true);

    cpu.regs._8.set(.a, 0xFF);
    bus.write(test_start_addr + 1, 0x3C);
    step();

    try expect(cpu.regs._8.get(.a) == 0x00);
    try expect(cpu.regs.f.z == true);
    try expect(cpu.regs.f.n == false);
    try expect(cpu.regs.f.h == true);
}

test "dec" {
    test_init();

    const dec_addr = 0xD389;
    cpu.regs._16.set(.hl, dec_addr);
    bus.write(test_start_addr, 0x35);
    bus.write(dec_addr, 0xA0);
    step();

    try expect(bus.read(dec_addr) == 0x9F);
    try expect(cpu.regs.f.z == false);
    try expect(cpu.regs.f.n == true);
    try expect(cpu.regs.f.h == true);

    cpu.regs._8.set(.e, 0x01);
    bus.write(test_start_addr + 1, 0x1D);
    step();

    try expect(cpu.regs._8.get(.e) == 0x00);
    try expect(cpu.regs.f.z == true);
    try expect(cpu.regs.f.n == true);
    try expect(cpu.regs.f.h == false);
}

test "add" {
    test_init();

    cpu.regs._8.set(.a, 0x01);
    cpu.regs._8.set(.c, 0xFF);
    bus.write(test_start_addr, 0x81);
    step();

    try expect(cpu.regs._8.get(.a) == 0x00);
    try expect(cpu.regs.f.z == true);
    try expect(cpu.regs.f.h == true);
    try expect(cpu.regs.f.n == false);
    try expect(cpu.regs.f.c == true);
}

test "adc" {
    test_init();

    const addr = 0xCD8A;
    cpu.regs._8.set(.a, 0x00);
    cpu.regs._16.set(.hl, addr);
    bus.write(addr, 0x0F);
    cpu.regs.f.c = true;
    bus.write(test_start_addr, 0x8E);
    step();

    try expect(cpu.regs._8.get(.a) == 0x10);
    try expect(cpu.regs.f.z == false);
    try expect(cpu.regs.f.h == true);
    try expect(cpu.regs.f.n == false);
    try expect(cpu.regs.f.c == false);
}
