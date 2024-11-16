const term = @import("term.zig");

// Segment offsets
pub const KERNEL_CS = 0x08;
pub const KERNEL_DS = 0x10;
pub const USER_CS = 0x18;
pub const USER_DS = 0x20;
pub const TSS = 0x28;

const Access = packed struct(u8) {
    // A: Accessed bit, set when accessed (unless set 1 in advance)
    accessed: bool = false,

    /// RW: Readable/Writeable
    ///     For code: 0 read access not allowed, 1 read allowed
    ///     For data: 0 write access not allowed, 1 write allowed
    read_write: bool = false,

    /// DC: Direction/conforming bit
    ///     For data:   0: segment grows up
    ///                 1: segment grows down
    ///     For code:   0: code can only be executed by ring in DPL
    ///                 1: can be executed from equal or lower privilege level
    direction_conforming: bool = false,

    /// E: Executable, 0: data, 1: code
    executable: bool = false,

    /// S: Descriptor type, 1: for code or data segment
    descriptor: bool = false,

    /// DPL: Descriptor privilege field. 0: highest (kernel), 3: lowest (user)
    privilege: u2 = 0,

    /// P: Present (marks valid segment)
    present: bool = false,
};

const Flags = packed struct(u4) {
    reserved: u1 = 0,
    /// Is segment 64 bit, if set is_32 must be false
    is_64: bool = false,
    /// Is segment 32 bit, otherwise 16 bit
    is_32: bool = false,
    /// Is limit 4 KiB blocks, othwerwise 1B blocks
    block_4k: bool = false,

    const BLOCK_4K_32: Flags = .{ .is_32 = true, .block_4k = true };
};

const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u24,
    access: u8,
    limit_high: u4,
    flags: u4,
    base_high: u8,

    pub fn init(base: usize, limit: usize, access: Access, flags: Flags) GdtEntry {
        return .{
            .limit_low = @truncate(limit),
            .base_low = @truncate(base),
            .access = @bitCast(access),
            .limit_high = @truncate(limit >> 16),
            .flags = @bitCast(flags),
            .base_high = @truncate(base >> 24),
        };
    }
};
const GdtRegister = packed struct {
    limit: u16,
    base: u32,
};

var gdt align(4) = [_]GdtEntry{
    .init(0, 0, .{}, .{}),

    // Kernel Mode Code Segment
    .init(
        0,
        0xFFFFF,
        .{ .read_write = true, .executable = true, .descriptor = true, .present = true },
        .BLOCK_4K_32,
    ),
    // Kernel Mode Data Segment
    .init(
        0,
        0xFFFFF,
        .{ .read_write = true, .descriptor = true, .present = true },
        .BLOCK_4K_32,
    ),
    // User Mode Code Segment
    .init(
        0,
        0xFFFFF,
        .{
            .read_write = true,
            .executable = true,
            .descriptor = true,
            .privilege = 3,
            .present = true,
        },
        .BLOCK_4K_32,
    ),
    // User Mode Data Segment
    .init(
        0,
        0xFFFFF,
        .{ .read_write = true, .descriptor = true, .privilege = 3, .present = true },
        .BLOCK_4K_32,
    ),
    // Task State Segment, set later
    .init(0, 0, .{}, .{}),
};
var gdtr: GdtRegister = .{
    .limit = @sizeOf(@TypeOf(gdt)) - 1,
    .base = undefined,
};

const Tss = extern struct {
    unused0: u32,
    esp0: u32, // Stack
    ss0: u16, // Segment
    unused1: u16,
    unused2: [22]u32,
    unused3: u16,
    iopb: u16,
};
var tss: Tss = .{
    .unused0 = 0,
    .esp0 = 0,
    .ss0 = KERNEL_DS,
    .unused1 = 0,
    .unused2 = @splat(0),
    .unused3 = 0,
    .iopb = @sizeOf(Tss),
};

extern fn _loadGDT(*const GdtRegister) void;
comptime {
    asm (
        \\.type _loadGDT, @function
        \\_loadGDT:
        \\      mov +4(%esp), %eax
        \\      lgdt (%eax)
        \\      mov $0x10, %ax
        \\      mov %ax, %ds
        \\      mov %ax, %es
        \\      mov %ax, %fs
        \\      mov %ax, %gs
        \\      mov %ax, %ss
        \\      ljmp $0x08, $1f
        \\1:    ret
    );
}

pub fn init() void {
    term.print("Init GDT... ", .{});
    // Task State Segment
    gdt[gdt.len - 1] = .init(
        @intFromPtr(&tss),
        @sizeOf(Tss) - 1,
        .{ .accessed = true, .executable = true, .present = true },
        .{ .is_32 = true },
    );

    gdtr.base = @intFromPtr(&gdt[0]);
    _loadGDT(&gdtr);

    asm volatile ("ltr %ax"
        :
        : [ax] "r" (TSS),
    );

    term.print("Done!\n", .{});
}
