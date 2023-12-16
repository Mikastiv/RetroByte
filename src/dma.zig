const bus = @import("bus.zig");
const ppu = @import("ppu.zig");

var active: bool = undefined;
var byte: u8 = undefined;
var page: u16 = undefined;
var delay: u8 = undefined;

pub fn init() void {
    active = false;
    byte = 0;
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

    const data = bus.read(page | byte);
    // write on the same cycle
    ppu.oamWrite(byte, data);
    byte += 1;

    active = byte < 0xA0;
}

pub fn transfering() bool {
    return active;
}
