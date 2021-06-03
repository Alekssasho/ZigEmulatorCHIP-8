pub const OpCodeName = enum {
    SetIndex,
    SetRegister,
    DrawSprite,
    Nop,
    Count
};

pub const OpCode = union(OpCodeName) {
    SetIndex: u16,
    SetRegister: struct { register_name: u8, value: u8 },
    DrawSprite: struct { x: u8, y: u8, height: u8},
    Nop: void,
    Count: void,
};