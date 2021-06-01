const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const OpCode = u16;
const Register = u8;

const Emulator = struct {
    const ProgramStartLocation = 0x200;

    memory: [4096]u8,
    registers: [16]Register,
    index_register: u16,
    program_counter: u16,
    gfx: [64 * 32]bool,
    delay_timer: u8,
    sound_timer: u8,
    stack: [16]u16,
    stack_pointer: u16,
    keys: [16]bool,

    pub fn initialize() Emulator {
        return Emulator {
            .memory = [_]u8{0} ** 4096,
            .registers = [_]Register{0} ** 16,
            .index_register = 0,
            .program_counter = ProgramStartLocation,
            .gfx = [_]bool{false} ** (64 * 32),
            .delay_timer = 0,
            .sound_timer = 0,
            .stack = [_]u16{0} ** 16,
            .stack_pointer = 0,
            .keys = [_]bool{false} ** 16,
        };
    }

    pub fn load_program(self: *Emulator, filename: []const u8, allocator: *std.mem.Allocator) !void {
        const file = try std.fs.cwd().openFile(filename, .{ .read = true });
        defer file.close();

        const file_stats = try file.stat();
        const memory = try allocator.alloc(u8, file_stats.size);
        defer allocator.free(memory);

        const read_bytes = try file.read(memory);
        std.debug.assert(read_bytes == memory.len);

        for (memory) |byte, i| {
            self.memory[i + ProgramStartLocation] = byte;
        }
    }

    pub fn emulate_cycle(self: *Emulator) void {
        // Fetch
        const opcode: OpCode = @intCast(OpCode, self.memory[self.program_counter]) << 8 | @intCast(OpCode, self.memory[self.program_counter + 1]);
        // TODO: make union/enum for decoded opcode
        switch (opcode & 0xF000) {
            0xA000 => { // ANNN: Sets I to the address NNN
                self.index_register = opcode & 0x0FFF;
            },
            else => {},
        }
        //self.program_counter += 2;
    }
};

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
