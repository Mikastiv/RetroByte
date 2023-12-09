const std = @import("std");
const bus = @import("bus.zig");
const registers = @import("registers.zig");
const Registers = registers.Registers;

pub fn disassemble(opcode: u8, regs: Registers) void {
    const pc = regs.pc();
    const imm = bus.peek(pc);
    const imm_word = @as(u16, bus.peek(pc + 1)) << 8 | imm;
    _ = imm_word;

    const inst = mnemonic(opcode);
    const prefix_cb = if (inst == .prefix_cb) prefixCb(imm) else null;
    if (prefix_cb) |prefix| {
        std.debug.print("{s: <5} ", .{@tagName(prefix)});
    } else {
        std.debug.print("{s: <5} ", .{inst.toStr()});
    }

    const z: u8 = if (regs.f.z) 'z' else '-';
    const n: u8 = if (regs.f.n) 'n' else '-';
    const h: u8 = if (regs.f.h) 'h' else '-';
    const c: u8 = if (regs.f.c) 'c' else '-';
    std.debug.print("| flags: {c}{c}{c}{c} ", .{ z, n, h, c });

    std.debug.print(
        "| a: ${x:0<2} | bc: ${x:0<4} | de: ${x:0<4} | hl: ${x:0<4} | sp: ${x:0<4} | pc: ${x:0<4} | cycles: {d}\n",
        .{ regs._8.get(.a), regs._16.get(.bc), regs._16.get(.de), regs._16.get(.hl), regs.sp(), regs.pc(), bus.cycles },
    );
}

const Mnemonic = enum {
    nop,
    stop,
    daa,
    cpl,
    scf,
    ccf,
    halt,
    ld,
    inc,
    dec,
    rcla,
    rrca,
    rla,
    rra,
    add,
    adc,
    jr,
    sub,
    sbc,
    bit_and,
    bit_xor,
    bit_or,
    cp,
    ret,
    pop,
    jp,
    call,
    push,
    rst,
    reti,
    prefix_cb,
    panic,
    di,
    ei,
    rlc,
    rrc,
    rl,
    rr,
    sla,
    sra,
    swap,
    srl,
    bit,
    res,
    set,

    fn toStr(self: @This()) []const u8 {
        return switch (self) {
            .bit_and => "and",
            .bit_xor => "xor",
            .bit_or => "or",
            else => @tagName(self),
        };
    }
};

const Dst = enum {
    implied,
    r16,
    addr_r16,
    r8,
    imm16,
    imm_s8,
    cond,
    addr_hli,
    addr_hld,
};

fn mnemonic(opcode: u8) Mnemonic {
    return switch (opcode) {
        0x00 => .nop,
        0x10 => .stop,
        0x27 => .daa,
        0x2F => .cpl,
        0x37 => .scf,
        0x3F => .ccf,
        0x76 => .halt,
        0x01,
        0x02,
        0x06,
        0x08,
        0x0A,
        0x0E,
        0x11...0x13,
        0x16,
        0x1A,
        0x1E,
        0x21,
        0x22,
        0x26,
        0x2A,
        0x2E,
        0x31,
        0x32,
        0x36,
        0x3A,
        0x3E,
        0x40...0x75,
        0x77...0x7F,
        0xE0,
        0xE2,
        0xEA,
        0xF0,
        0xF2,
        0xF8,
        0xF9,
        0xFA,
        => .ld,
        0x03,
        0x04,
        0x0C,
        0x14,
        0x1C,
        0x23,
        0x24,
        0x2C,
        0x33,
        0x34,
        0x3C,
        => .inc,
        0x05,
        0x0B,
        0x0D,
        0x15,
        0x1B,
        0x1D,
        0x25,
        0x2B,
        0x2D,
        0x35,
        0x3B,
        0x3D,
        => .dec,
        0x07 => .rcla,
        0x0F => .rrca,
        0x17 => .rla,
        0x1F => .rra,
        0x09, 0x19, 0x29, 0x39, 0x80...0x87, 0xC6, 0xE8 => .add,
        0x88...0x8F, 0xCE => .adc,
        0x18, 0x20, 0x28, 0x30, 0x38 => .jr,
        0x90...0x97, 0xD6 => .sub,
        0x98...0x9F, 0xDE => .sbc,
        0xA0...0xA7, 0xE6 => .bit_and,
        0xA8...0xAF, 0xEE => .bit_xor,
        0xB0...0xB7, 0xF6 => .bit_or,
        0xB8...0xBF, 0xFE => .cp,
        0xC0, 0xC8, 0xC9, 0xD0, 0xD8 => .ret,
        0xC1, 0xD1, 0xE1, 0xF1 => .pop,
        0xC2, 0xC3, 0xCA, 0xD2, 0xDA, 0xE9 => .jp,
        0xC4, 0xCC, 0xCD, 0xD4, 0xDC => .call,
        0xC5, 0xD5, 0xE5, 0xF5 => .push,
        0xC7, 0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0xFF => .rst,
        0xD9 => .reti,
        0xCB => .prefix_cb,
        0xD3, 0xDB, 0xDD, 0xE3, 0xE4, 0xEB...0xED, 0xF4, 0xFC, 0xFD => .panic,
        0xF3 => .di,
        0xFB => .ei,
    };
}

fn prefixCb(opcode: u8) Mnemonic {
    return switch (opcode) {
        0x00...0x07 => .rlc,
        0x08...0x0F => .rrc,
        0x10...0x17 => .rl,
        0x18...0x1F => .rr,
        0x20...0x27 => .sla,
        0x28...0x2F => .sra,
        0x30...0x37 => .swap,
        0x38...0x3F => .srl,
        0x40...0x7F => .bit,
        0x80...0xBF => .res,
        0xC0...0xFF => .set,
    };
}
