usingnamespace @import("opcode.zig");
const std = @import("std");

const Register = u8;

pub const Emulator = struct {
    const ProgramStartLocation = 0x200;
    const FontsetStartLocation = 0x050;

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
    draw_flag: bool,

    pub fn initialize() Emulator {
        var result = Emulator {
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
            .draw_flag = false,
        };

        // Load the fontset
        comptime std.debug.assert(chip8_fontset.len == 80);
        for (chip8_fontset) |value, i| {
            result.memory[FontsetStartLocation + i] = value;
        }

        return result;
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

    fn fetch_opcode(self: *Emulator) ?OpCode {
        if (self.program_counter + 2 >= 4096) {
            return null;
        }
        // Fetch
        const opcode: u16 = @intCast(u16, self.memory[self.program_counter]) << 8 | @intCast(u16, self.memory[self.program_counter + 1]);

        self.program_counter += 2;
        // Decode
        switch (opcode & 0xF000) {
            0x0000 => {
                switch (opcode & 0x00FF) {
                    0x00EE => return OpCode{ .Return = .{} },
                    else => std.debug.warn("Unknown opcode = {x}\n", .{opcode}),
                }
            },
            0xA000 => return OpCode{ .SetIndex = opcode & 0x0FFF },
            0x6000 => return OpCode{ .SetRegister = .{
                .register_name = @intCast(u8, (opcode & 0x0F00) >> 8),
                .value = @intCast(u8, opcode & 0x00FF)
            }},
            0x7000 => return OpCode{ .Add = .{
                .register_name = @intCast(u8, (opcode & 0x0F00) >> 8),
                .value = @intCast(u8, opcode & 0x00FF)
            }},
            0x8000 => {
                switch (opcode & 0x000F) {
                    0x0000 => return OpCode{ .Assign = .{
                        .register_destination = @intCast(u8, (opcode & 0x0F00) >> 8),
                        .register_source = @intCast(u8, (opcode & 0x00F0) >> 4),
                    }},
                    else => std.debug.warn("Unknown opcode = {x}\n", .{opcode}),
                }
            },
            0xD000 => return OpCode{ .DrawSprite = .{
                .x = @intCast(u8, (opcode & 0x0F00) >> 8),
                .y = @intCast(u8, (opcode & 0x00F0) >> 4),
                .height = @intCast(u8, opcode & 0x000F)
            }},
            0x2000 => {
                return OpCode{ .CallFunction = opcode & 0x0FFF };
            },
            0xF000 => {
                const second_byte: u8 = @intCast(u8, (opcode & 0x0F00) >> 8);
                switch (opcode & 0x00FF) {
                    0x0015 => return OpCode{ .SetDelayTimer = second_byte },
                    0x0033 => return OpCode{ .StoreBCD = second_byte },
                    0x0065 => return OpCode{ .LoadIntoRegisters = second_byte },
                    0x0029 => return OpCode{ .SetIndexToSprite = second_byte },
                    else => std.debug.warn("Unknown opcode = {x}\n", .{opcode}),
                }
            },
            else => std.debug.warn("Unknown opcode = {x}\n", .{opcode}),
        }
        return null;
    }

    fn execute_opcode(self: *Emulator, opcode: OpCode) void {
        switch(opcode) {
            OpCodeName.SetIndex => |value| {
                self.index_register = value;
            },
            OpCodeName.SetIndexToSprite => |register| {
                const character = self.registers[register];
                self.index_register = FontsetStartLocation + (5 * character);
            },
            OpCodeName.SetRegister => |value| {
                self.registers[value.register_name] = value.value;
            },
            OpCodeName.Add => |value| {
                self.registers[value.register_name] +%= value.value;
            },
            OpCodeName.Assign => |value| {
                self.registers[value.register_destination] = self.registers[value.register_source];
            },
            OpCodeName.DrawSprite => |value| {
                self.draw_sprite(self.registers[value.x], self.registers[value.y], value.height);
            },
            OpCodeName.CallFunction => |address| {
                self.stack[self.stack_pointer] = self.program_counter;
                self.stack_pointer += 1;
                self.program_counter = address;
            },
            OpCodeName.Return => |_| {
                std.debug.assert(self.stack_pointer > 0);
                self.stack_pointer -= 1;
                self.program_counter = self.stack[self.stack_pointer];
            },
            OpCodeName.SetDelayTimer => |register| {
                self.delay_timer = self.registers[register];
            },
            OpCodeName.StoreBCD => |register| {
                const value = self.registers[register];
                self.memory[self.index_register + 0] = value / 100;
                self.memory[self.index_register + 1] = (value / 10) % 10;
                self.memory[self.index_register + 2] = (value % 100) % 10;
            },
            OpCodeName.LoadIntoRegisters => |until_register| {
                var i: u8 = 0;
                while (i <= until_register) : (i += 1) {
                    self.registers[i] = self.memory[self.index_register + i];
                }
            },
            OpCodeName.Nop => {},
            OpCodeName.Count => unreachable,
        }
    }

    fn draw_sprite(self: *Emulator, x: Register, y: Register, height: u8) void {
        // VF is special register used for collision detection
        self.registers[0xF] = 0;
        var yline: u8 = 0;
        while (yline < height) : (yline += 1) {
            const pixel = self.memory[self.index_register + yline];
            var xline: u8 = 0;
            while (xline < 8) : (xline += 1) {
                const sprite_pixel = pixel & (@intCast(u8, 0x80) >> @intCast(u3, xline));
                if (sprite_pixel != 0) {
                    const screen_pixel: *bool = &self.gfx[@intCast(u16, x + xline) + (@intCast(u16, (y + yline)) * 64)];
                    if (screen_pixel.*) {
                        // Collision
                        self.registers[0xF] = 1;
                    }
                    screen_pixel.* = (@boolToInt(screen_pixel.*) ^ 1) != 0;
                }
            }
        }

        self.draw_flag = true;
    }

    pub fn emulate_cycle(self: *Emulator) void {
        const opcode = self.fetch_opcode() orelse OpCode{ .Nop = {} };
        self.execute_opcode(opcode);

        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
        }

        if (self.sound_timer > 0) {
            if (self.sound_timer == 1) {
                std.log.info("BEEP!", .{});
            }
            self.sound_timer -= 1;
        }
    }
};

const chip8_fontset = [_]u8 {
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80  // F
};