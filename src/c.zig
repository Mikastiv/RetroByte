const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    if (builtin.os.tag == .emscripten) @cInclude("emscripten.h");
});
