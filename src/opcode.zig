pub const OpCodeName = enum {
    SetIndex,
    SetRegister,
    Nop,
    Count
};

pub const OpCode = union(OpCodeName) {
    SetIndex: u16,
    SetRegister: struct { register_name: u8, value: u8 },
    Nop: void,
    Count: void,
};