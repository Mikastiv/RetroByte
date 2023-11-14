const Bus = @This();

ctx: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    read: *const fn (ctx: *anyopaque, addr: u16) u8,
    write: *const fn (ctx: *anyopaque, addr: u16, data: u8) void,
    tick: *const fn (ctx: *anyopaque) void,
};

pub fn read(self: Bus, addr: u16) u8 {
    return self.vtable.read(self.ctx, addr);
}

pub fn write(self: Bus, addr: u16, data: u8) void {
    return self.vtable.write(self.ctx, addr, data);
}

pub fn tick(self: Bus) void {
    return self.vtable.tick(self.ctx);
}
