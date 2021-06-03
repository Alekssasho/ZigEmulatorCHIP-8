const Emulator = @import("emulator.zig").Emulator;
const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

pub fn main() anyerror!void {
    const allocator = std.heap.c_allocator;
    var emulator = Emulator.initialize();
    try emulator.load_program("Pong.ch8", allocator);

    if (sdl.SDL_Init(sdl.SDL_INIT_EVERYTHING) != 0) {
        std.debug.print("SD_Init Error: {}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_Quit();

    var window = sdl.SDL_CreateWindow("CHIP-8 Emulator", sdl.SDL_WINDOWPOS_CENTERED, sdl.SDL_WINDOWPOS_CENTERED, 1280, 720, sdl.SDL_WINDOW_SHOWN);
    if (window == null) {
        std.debug.print("SDL_CreateWidnow Error: {}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_DestroyWindow(window);

    var renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED | sdl.SDL_RENDERER_PRESENTVSYNC);
    if(renderer == null) {
        std.debug.print("SDL_CreateRenderer Error: {}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_DestroyRenderer(renderer);

    main_loop: while (true) {
        var event: sdl.SDL_Event = undefined;
        while(sdl.SDL_PollEvent(&event) != 0) {
            switch(event.type) {
                sdl.SDL_QUIT => break :main_loop,
                else => {}
            }
        }

        emulator.emulate_cycle();

        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 255, 255, 255);
        _ = sdl.SDL_RenderClear(renderer);
        sdl.SDL_RenderPresent(renderer);
    }
}
