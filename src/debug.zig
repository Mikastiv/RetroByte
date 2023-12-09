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

const Mode = enum {
    none,
    af,
    bc,
    de,
    hl,
    sp,
    a,
    b,
    c,
    d,
    e,
    h,
    l,
    addr_hl,
    addr_bc,
    addr_de,
    imm8,
    imm_addr,
    imm16,
    imm_s8,
    cond_nz,
    cond_nc,
    cond_z,
    cond_c,
    addr_hli,
    addr_hld,
    zero_page,
    zero_page_c,
};

const Instruction = struct {
    mnemonic: Mnemonic,
    dst: Mode,
    src: Mode,
    cycles: u8,
};

const instructions = blk: {
    var i: [0x100]Instruction = undefined;
    i[0x00] = .{ .mnemonic = .nop, .dst = .none, .src = .none, .cycles = 1 };
    i[0x01] = .{ .mnemonic = .ld, .dst = .bc, .src = .imm16, .cycles = 3 };
    i[0x02] = .{ .mnemonic = .ld, .dst = .addr_bc, .src = .a, .cycles = 2 };
    i[0x03] = .{ .mnemonic = .inc, .dst = .bc, .src = .none, .cycles = 2 };
    i[0x04] = .{ .mnemonic = .inc, .dst = .b, .src = .none, .cycles = 1 };
    i[0x05] = .{ .mnemonic = .dec, .dst = .b, .src = .none, .cycles = 1 };
    i[0x06] = .{ .mnemonic = .ld, .dst = .b, .src = .imm8, .cycles = 2 };
    i[0x07] = .{ .mnemonic = .rcla, .dst = .none, .src = .none, .cycles = 1 };
    i[0x08] = .{ .mnemonic = .ld, .dst = .imm_addr, .src = .sp, .cycles = 5 };
    i[0x09] = .{ .mnemonic = .add, .dst = .hl, .src = .bc, .cycles = 2 };
    i[0x0A] = .{ .mnemonic = .ld, .dst = .a, .src = .addr_bc, .cycles = 2 };
    i[0x0B] = .{ .mnemonic = .dec, .dst = .bc, .src = .none, .cycles = 2 };
    i[0x0C] = .{ .mnemonic = .inc, .dst = .c, .src = .none, .cycles = 1 };
    i[0x0D] = .{ .mnemonic = .dec, .dst = .c, .src = .none, .cycles = 1 };
    i[0x0E] = .{ .mnemonic = .ld, .dst = .c, .src = .imm, .cycles = 2 };
    i[0x0F] = .{ .mnemonic = .rrca, .dst = .none, .src = .none, .cycles = 1 };
    i[0x10] = .{ .mnemonic = .stop, .dst = .none, .src = .none, .cycles = 1 };
    i[0x11] = .{ .mnemonic = .ld, .dst = .de, .src = .imm16, .cycles = 3 };
    i[0x12] = .{ .mnemonic = .ld, .dst = .addr_de, .src = .a, .cycles = 2 };
    i[0x13] = .{ .mnemonic = .inc, .dst = .de, .src = .none, .cycles = 1 };
    i[0x14] = .{ .mnemonic = .inc, .dst = .d, .src = .none, .cycles = 1 };
    i[0x15] = .{ .mnemonic = .dec, .dst = .d, .src = .none, .cycles = 1 };
    i[0x16] = .{ .mnemonic = .ld, .dst = .d, .src = .imm8, .cycles = 2 };
    i[0x17] = .{ .mnemonic = .rla, .dst = .none, .src = .none, .cycles = 1 };
    i[0x18] = .{ .mnemonic = .jr, .dst = .imm_s8, .src = .none, .cycles = 3 };
    i[0x19] = .{ .mnemonic = .add, .dst = .hl, .src = .none, .cycles = 1 };
    i[0x1A] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x1B] = .{ .mnemonic = .dec, .dst = .de, .src = .none, .cycles = 1 };
    i[0x1C] = .{ .mnemonic = .inc, .dst = .e, .src = .none, .cycles = 1 };
    i[0x1D] = .{ .mnemonic = .dec, .dst = .e, .src = .none, .cycles = 1 };
    i[0x1E] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x1F] = .{ .mnemonic = .rra, .dst = .none, .src = .none, .cycles = 1 };
    i[0x20] = .{ .mnemonic = .jr, .dst = .cond_nz, .src = .none, .cycles = 1 };
    i[0x21] = .{ .mnemonic = .ld, .dst = .hl, .src = .none, .cycles = 1 };
    i[0x22] = .{ .mnemonic = .ld, .dst = .addr_hli, .src = .none, .cycles = 1 };
    i[0x23] = .{ .mnemonic = .inc, .dst = .hl, .src = .none, .cycles = 1 };
    i[0x24] = .{ .mnemonic = .inc, .dst = .h, .src = .none, .cycles = 1 };
    i[0x25] = .{ .mnemonic = .dec, .dst = .h, .src = .none, .cycles = 1 };
    i[0x26] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x27] = .{ .mnemonic = .daa, .dst = .none, .src = .none, .cycles = 1 };
    i[0x28] = .{ .mnemonic = .jr, .dst = .cond_z, .src = .none, .cycles = 1 };
    i[0x29] = .{ .mnemonic = .add, .dst = .hl, .src = .none, .cycles = 1 };
    i[0x2A] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x2B] = .{ .mnemonic = .dec, .dst = .hl, .src = .none, .cycles = 1 };
    i[0x2C] = .{ .mnemonic = .inc, .dst = .l, .src = .none, .cycles = 1 };
    i[0x2D] = .{ .mnemonic = .dec, .dst = .l, .src = .none, .cycles = 1 };
    i[0x2E] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x2F] = .{ .mnemonic = .cpl, .dst = .none, .src = .none, .cycles = 1 };
    i[0x30] = .{ .mnemonic = .jr, .dst = .cond_nc, .src = .none, .cycles = 1 };
    i[0x31] = .{ .mnemonic = .ld, .dst = .sp, .src = .none, .cycles = 1 };
    i[0x32] = .{ .mnemonic = .ld, .dst = .addr_hld, .src = .none, .cycles = 1 };
    i[0x33] = .{ .mnemonic = .inc, .dst = .sp, .src = .none, .cycles = 1 };
    i[0x34] = .{ .mnemonic = .inc, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x35] = .{ .mnemonic = .dec, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x36] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x37] = .{ .mnemonic = .scf, .dst = .none, .src = .none, .cycles = 1 };
    i[0x38] = .{ .mnemonic = .jr, .dst = .cond_c, .src = .none, .cycles = 1 };
    i[0x39] = .{ .mnemonic = .add, .dst = .hl, .src = .none, .cycles = 1 };
    i[0x3A] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x3B] = .{ .mnemonic = .dec, .dst = .sp, .src = .none, .cycles = 1 };
    i[0x3C] = .{ .mnemonic = .inc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x3D] = .{ .mnemonic = .dec, .dst = .a, .src = .none, .cycles = 1 };
    i[0x3E] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x3F] = .{ .mnemonic = .ccf, .dst = .none, .src = .none, .cycles = 1 };
    i[0x40] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x41] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x42] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x43] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x44] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x45] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x46] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x47] = .{ .mnemonic = .ld, .dst = .b, .src = .none, .cycles = 1 };
    i[0x48] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x49] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x4A] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x4B] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x4C] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x4D] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x4E] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x4F] = .{ .mnemonic = .ld, .dst = .c, .src = .none, .cycles = 1 };
    i[0x50] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x51] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x52] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x53] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x54] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x55] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x56] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x57] = .{ .mnemonic = .ld, .dst = .d, .src = .none, .cycles = 1 };
    i[0x58] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x59] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x5A] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x5B] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x5C] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x5D] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x5E] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x5F] = .{ .mnemonic = .ld, .dst = .e, .src = .none, .cycles = 1 };
    i[0x60] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x61] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x62] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x63] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x64] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x65] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x66] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x67] = .{ .mnemonic = .ld, .dst = .h, .src = .none, .cycles = 1 };
    i[0x68] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x69] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x6A] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x6B] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x6C] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x6D] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x6E] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x6F] = .{ .mnemonic = .ld, .dst = .l, .src = .none, .cycles = 1 };
    i[0x70] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x71] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x72] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x73] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x74] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x75] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x76] = .{ .mnemonic = .halt, .dst = .none, .src = .none, .cycles = 1 };
    i[0x77] = .{ .mnemonic = .ld, .dst = .addr_hl, .src = .none, .cycles = 1 };
    i[0x78] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x79] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x7A] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x7B] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x7C] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x7D] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x7E] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x7F] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0x80] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x81] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x82] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x83] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x84] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x85] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x86] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x87] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0x88] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x89] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x8A] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x8B] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x8C] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x8D] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x8E] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x8F] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x90] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x91] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x92] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x93] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x94] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x95] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x96] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x97] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0x98] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x99] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x9A] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x9B] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x9C] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x9D] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x9E] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0x9F] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA0] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA1] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA2] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA3] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA4] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA5] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA6] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA7] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA8] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xA9] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xAA] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xAB] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xAC] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xAD] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xAE] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xAF] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB0] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB1] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB2] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB3] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB4] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB5] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB6] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB7] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB8] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xB9] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xBA] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xBB] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xBC] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xBD] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xBE] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xBF] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xC0] = .{ .mnemonic = .ret, .dst = .cond_nz, .src = .none, .cycles = 1 };
    i[0xC1] = .{ .mnemonic = .pop, .dst = .bc, .src = .none, .cycles = 1 };
    i[0xC2] = .{ .mnemonic = .jp, .dst = .cond_nz, .src = .none, .cycles = 1 };
    i[0xC3] = .{ .mnemonic = .jp, .dst = .imm_addr, .src = .none, .cycles = 1 };
    i[0xC4] = .{ .mnemonic = .call, .dst = .cond_nz, .src = .none, .cycles = 1 };
    i[0xC5] = .{ .mnemonic = .push, .dst = .bc, .src = .none, .cycles = 1 };
    i[0xC6] = .{ .mnemonic = .add, .dst = .a, .src = .none, .cycles = 1 };
    i[0xC7] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xC8] = .{ .mnemonic = .ret, .dst = .cond_z, .src = .none, .cycles = 1 };
    i[0xC9] = .{ .mnemonic = .ret, .dst = .none, .src = .none, .cycles = 1 };
    i[0xCA] = .{ .mnemonic = .jp, .dst = .cond_z, .src = .none, .cycles = 1 };
    i[0xCB] = .{ .mnemonic = .prefix_cb, .dst = .none, .src = .none, .cycles = 1 };
    i[0xCC] = .{ .mnemonic = .call, .dst = .cond_z, .src = .none, .cycles = 1 };
    i[0xCD] = .{ .mnemonic = .call, .dst = .imm_addr, .src = .none, .cycles = 1 };
    i[0xCE] = .{ .mnemonic = .adc, .dst = .a, .src = .none, .cycles = 1 };
    i[0xCF] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xD0] = .{ .mnemonic = .ret, .dst = .cond_nc, .src = .none, .cycles = 1 };
    i[0xD1] = .{ .mnemonic = .pop, .dst = .de, .src = .none, .cycles = 1 };
    i[0xD2] = .{ .mnemonic = .jp, .dst = .cond_nc, .src = .none, .cycles = 1 };
    i[0xD3] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xD4] = .{ .mnemonic = .call, .dst = .cond_nc, .src = .none, .cycles = 1 };
    i[0xD5] = .{ .mnemonic = .push, .dst = .de, .src = .none, .cycles = 1 };
    i[0xD6] = .{ .mnemonic = .sub, .dst = .a, .src = .none, .cycles = 1 };
    i[0xD7] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xD8] = .{ .mnemonic = .ret, .dst = .cond_c, .src = .none, .cycles = 1 };
    i[0xD9] = .{ .mnemonic = .reti, .dst = .none, .src = .none, .cycles = 1 };
    i[0xDA] = .{ .mnemonic = .jp, .dst = .cond_c, .src = .none, .cycles = 1 };
    i[0xDB] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xDC] = .{ .mnemonic = .call, .dst = .cond_c, .src = .none, .cycles = 1 };
    i[0xDD] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xDE] = .{ .mnemonic = .sbc, .dst = .a, .src = .none, .cycles = 1 };
    i[0xDF] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xE0] = .{ .mnemonic = .ld, .dst = .zero_page, .src = .none, .cycles = 1 };
    i[0xE1] = .{ .mnemonic = .pop, .dst = .hl, .src = .none, .cycles = 1 };
    i[0xE2] = .{ .mnemonic = .ld, .dst = .zero_page_c, .src = .none, .cycles = 1 };
    i[0xE3] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xE4] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xE5] = .{ .mnemonic = .push, .dst = .hl, .src = .none, .cycles = 1 };
    i[0xE6] = .{ .mnemonic = .bit_and, .dst = .a, .src = .none, .cycles = 1 };
    i[0xE7] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xE8] = .{ .mnemonic = .add, .dst = .sp, .src = .none, .cycles = 1 };
    i[0xE9] = .{ .mnemonic = .jp, .dst = .hl, .src = .none, .cycles = 1 };
    i[0xEA] = .{ .mnemonic = .ld, .dst = .imm_addr, .src = .none, .cycles = 1 };
    i[0xEB] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xEC] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xED] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xEE] = .{ .mnemonic = .bit_xor, .dst = .a, .src = .none, .cycles = 1 };
    i[0xEF] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xF0] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0xF1] = .{ .mnemonic = .pop, .dst = .af, .src = .none, .cycles = 1 };
    i[0xF2] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0xF3] = .{ .mnemonic = .di, .dst = .none, .src = .none, .cycles = 1 };
    i[0xF4] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xF5] = .{ .mnemonic = .push, .dst = .af, .src = .none, .cycles = 1 };
    i[0xF6] = .{ .mnemonic = .bit_or, .dst = .a, .src = .none, .cycles = 1 };
    i[0xF7] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    i[0xF8] = .{ .mnemonic = .ld, .dst = .hl, .src = .none, .cycles = 1 };
    i[0xF9] = .{ .mnemonic = .ld, .dst = .sp, .src = .none, .cycles = 1 };
    i[0xFA] = .{ .mnemonic = .ld, .dst = .a, .src = .none, .cycles = 1 };
    i[0xFB] = .{ .mnemonic = .ei, .dst = .none, .src = .none, .cycles = 1 };
    i[0xFC] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xFD] = .{ .mnemonic = .panic, .dst = .none, .src = .none, .cycles = 1 };
    i[0xFE] = .{ .mnemonic = .cp, .dst = .a, .src = .none, .cycles = 1 };
    i[0xFF] = .{ .mnemonic = .rst, .dst = .none, .src = .none, .cycles = 1 };
    break :blk i;
};

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
