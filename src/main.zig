const Emulator = @import("emulator.zig").Emulator;
const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const key_mapping = [_] struct {
    sdl_key: u32,
    chip8_key: u8
} {
    .{.sdl_key = sdl.SDLK_1, .chip8_key = 0x1},
    .{.sdl_key = sdl.SDLK_2, .chip8_key = 0x2},
    .{.sdl_key = sdl.SDLK_3, .chip8_key = 0x3},
    .{.sdl_key = sdl.SDLK_4, .chip8_key = 0xC},
    .{.sdl_key = sdl.SDLK_q, .chip8_key = 0x4},
    .{.sdl_key = sdl.SDLK_w, .chip8_key = 0x5},
    .{.sdl_key = sdl.SDLK_e, .chip8_key = 0x6},
    .{.sdl_key = sdl.SDLK_r, .chip8_key = 0xD},
    .{.sdl_key = sdl.SDLK_a, .chip8_key = 0x7},
    .{.sdl_key = sdl.SDLK_s, .chip8_key = 0x8},
    .{.sdl_key = sdl.SDLK_d, .chip8_key = 0x9},
    .{.sdl_key = sdl.SDLK_f, .chip8_key = 0xE},
    .{.sdl_key = sdl.SDLK_z, .chip8_key = 0xA},
    .{.sdl_key = sdl.SDLK_x, .chip8_key = 0x0},
    .{.sdl_key = sdl.SDLK_c, .chip8_key = 0xB},
    .{.sdl_key = sdl.SDLK_v, .chip8_key = 0xF},
};

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
                sdl.SDL_KEYDOWN, sdl.SDL_KEYUP => {
                    const keycode = event.key.keysym.sym;
                    for (key_mapping) |map| {
                        if (map.sdl_key == keycode) {
                            emulator.keys[map.chip8_key] = event.type == sdl.SDL_KEYDOWN;
                            break;
                        }
                    }
                },
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
