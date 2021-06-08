const Emulator = @import("emulator.zig").Emulator;
const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

pub fn main() anyerror!void {
    const allocator = std.heap.c_allocator;
    var emulator = Emulator.initialize();
    try emulator.load_program("tetris.ch8", allocator);

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

    var texture = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_RGBA8888, sdl.SDL_TEXTUREACCESS_STREAMING, 64, 32);
    defer sdl.SDL_DestroyTexture(texture);

    const CYCLE_TIME_NS = 16 * 1000;

    var timer = try std.time.Timer.start();
    main_loop: while (true) {
        timer.reset();
        var event: sdl.SDL_Event = undefined;
        while(sdl.SDL_PollEvent(&event) != 0) {
            switch(event.type) {
                sdl.SDL_QUIT => break :main_loop,
                else => {}
            }
        }

        emulator.emulate_cycle();
        if (emulator.draw_flag) {
            var pixels = [_]u32{0x000000FF} ** (64 * 32);
            for (emulator.gfx) | value, i| {
                if (value != 0) {
                    pixels[i] = 0xFFFFFFFF;
                }
            }

            _ = sdl.SDL_UpdateTexture(texture, null, &pixels, @sizeOf(u32) * 64);

            emulator.draw_flag = false;
        }
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        _ = sdl.SDL_RenderClear(renderer);

        _ = sdl.SDL_RenderCopy(renderer, texture, null, null);
        sdl.SDL_RenderPresent(renderer);

        const time_took = timer.read();
        if (time_took < CYCLE_TIME_NS) {
            std.time.sleep(CYCLE_TIME_NS - time_took);
        }
    }
}
