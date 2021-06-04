pub const OpCodeName = enum {
    SetIndex,
    SetRegister,
    DrawSprite,
    CallFunction,
    Return,
    SetDelayTimer,
    StoreBCD,
    LoadIntoRegisters,
    SetIndexToSprite,
    Add,
    Assign,
    Nop,
    Count
};

pub const OpCode = union(OpCodeName) {
    SetIndex: u16,
    SetRegister: struct { register_name: u8, value: u8 },
    DrawSprite: struct { x: u8, y: u8, height: u8},
    CallFunction: u16,
    Return: void,
    SetDelayTimer: u8,
    StoreBCD: u8,
    LoadIntoRegisters: u8,
    SetIndexToSprite: u8,
    Add: struct { register_name: u8, value: u8 },
    Assign: struct { register_destination: u8, register_source: u8 },
    Nop: void,
    Count: void,
};