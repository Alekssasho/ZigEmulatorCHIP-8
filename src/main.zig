const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const OpCode = u16;
const Register = u8;

const Emulator = struct {
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
            .program_counter = 0x200, // Start of the program in memory
            .gfx = [_]bool{false} ** (64 * 32),
            .delay_timer = 0,
            .sound_timer = 0,
            .stack = [_]u16{0} ** 16,
            .stack_pointer = 0,
            .keys = [_]bool{false} ** 16,
        };
    }
};

pub fn main() anyerror!void {
    var emulator = Emulator.initialize();
}
