const bus = @import("bus.zig");
const ppu = @import("ppu.zig");

var active: bool = undefined;
var byte: u8 = undefined;
var page: u16 = undefined;
var delay: u8 = undefined;

pub fn init() void {
    active = false;
    byte = 0;
    page = 0;
    delay = 0;
}

pub fn write(data: u8) void {
    active = true;
    delay = 1;
    byte = 0;
    page = @as(u16, data) << 8;
}

pub fn read() u8 {
    return @intCast(page >> 8);
}

pub fn tick() void {
    if (!active) return;

    if (delay > 0) {
        delay -= 1;
        return;
    }

    // read & write in 1 cycle
    const data = bus.peek(page | byte);
    ppu.oamWrite(byte, data);

    byte += 1;

    active = byte < 0xA0;
}

pub fn transfering() bool {
    return active;
}
