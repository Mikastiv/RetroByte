const interrupts = @import("interrupts.zig");

const Buttons = packed union {
    buttons: packed struct {
        a: u1,
        b: u1,
        select: u1,
        start: u1,
    },
    raw: u4,
};

const DPad = packed union {
    buttons: packed struct {
        right: u1,
        left: u1,
        up: u1,
        down: u1,
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

const select_buttons = 1 << 4;
const select_dpad = 1 << 5;

var buttons_state: Buttons = .{ .raw = 0xF };
var dpad_state: DPad = .{ .raw = 0xF };
var select: u8 = 0;

pub fn init() void {
    buttons_state = .{ .raw = 0xF };
    dpad_state = .{ .raw = 0xF };
    select = 0;
}

pub fn read() u8 {
    var value: u8 = 0;

    if (select & select_buttons == 0) {
        value |= buttons_state.raw;
    }
    if (select & select_dpad == 0) {
        value |= dpad_state.raw;
    }

    // 11SS BBBB
    // S: select
    // B: buttons
    return 0xC0 | select | value;
}

pub fn write(data: u8) void {
    select = data & 0x30;
}

pub fn keyup(button: GbButton) void {
    switch (button) {
        .a => buttons_state.buttons.a = 1,
        .b => buttons_state.buttons.b = 1,
        .select => buttons_state.buttons.select = 1,
        .start => buttons_state.buttons.start = 1,
        .right => dpad_state.buttons.right = 1,
        .left => dpad_state.buttons.left = 1,
        .up => dpad_state.buttons.up = 1,
        .down => dpad_state.buttons.down = 1,
    }
}

pub fn keydown(button: GbButton) void {
    switch (button) {
        .a => buttons_state.buttons.a = 0,
        .b => buttons_state.buttons.b = 0,
        .select => buttons_state.buttons.select = 0,
        .start => buttons_state.buttons.start = 0,
        .right => dpad_state.buttons.right = 0,
        .left => dpad_state.buttons.left = 0,
        .up => dpad_state.buttons.up = 0,
        .down => dpad_state.buttons.down = 0,
    }
    interrupts.request(.joypad);
}
