const interrupts = @import("interrupts.zig");

const Buttons = packed union {
    buttons: packed struct {
        a: bool,
        b: bool,
        select: bool,
        start: bool,
    },
    raw: u4,
};

const DPad = packed union {
    buttons: packed struct {
        right: bool,
        left: bool,
        up: bool,
        down: bool,
    },
    raw: u4,
};

pub const GbButton = enum {
    a,
    b,
    select,
    start,
    right,
    left,
    up,
    down,
};

const select_dpad = 1 << 4;
const select_buttons = 1 << 5;

var buttons_state: Buttons = undefined;
var dpad_state: DPad = undefined;
var select: u8 = undefined;

pub fn init() void {
    buttons_state = .{ .raw = 0xF };
    dpad_state = .{ .raw = 0xF };
    select = 0x30;
}

pub fn read() u8 {
    var value: u8 = 0xC0 | select;

    if (select & select_buttons == 0) value |= buttons_state.raw;
    if (select & select_dpad == 0) value |= dpad_state.raw;
    if (select == 0x30) value |= 0xF;

    // 11SS BBBB
    // S: select
    // B: buttons
    return value;
}

pub fn write(data: u8) void {
    select = data & 0x30;
}

pub fn keypress(button: GbButton, up: bool) void {
    switch (button) {
        .a => buttons_state.buttons.a = up,
        .b => buttons_state.buttons.b = up,
        .select => buttons_state.buttons.select = up,
        .start => buttons_state.buttons.start = up,
        .right => dpad_state.buttons.right = up,
        .left => dpad_state.buttons.left = up,
        .up => dpad_state.buttons.up = up,
        .down => dpad_state.buttons.down = up,
    }
    if (!up) interrupts.request(.joypad);
}
