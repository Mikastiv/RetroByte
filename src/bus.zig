const Gameboy = @import("Gameboy.zig");
const MainBus = @import("MainBus.zig");
const TestBus = @import("TestBus.zig");

pub const Bus = union(enum) {
    const Self = @This();

    main_bus: MainBus,
    test_bus: TestBus,

    pub fn init(self: *Self, gameboy: *const Gameboy) void {
        switch (self.*) {
            inline else => |*b| b.init(gameboy),
        }
    }

    pub fn peek(self: *Self, addr: u16) u8 {
        return switch (self.*) {
            inline else => |*b| b.peek(addr),
        };
    }

    pub fn read(self: *Self, addr: u16) u8 {
        return switch (self.*) {
            inline else => |*b| b.read(addr),
        };
    }

    pub fn write(self: *Self, addr: u16, data: u8) void {
        return switch (self.*) {
            inline else => |*b| b.write(addr, data),
        };
    }

    pub fn tick(self: *Self) void {
        return switch (self.*) {
            inline else => |*b| b.tick(),
        };
    }
};
