// Chapter 7: Interrupt and exception handling
// Intel 64 and IA-32 Software Developer Manual, Vol 3, Oct 2024

const std = @import("std");

const gdt = @import("gdt.zig");
const term = @import("term.zig");

const GateType = enum(u3) {
    zero = 0,
    task = 0b101,
    interrupt = 0b110,
    trap = 0b111,
};

const IdtEntry = packed struct {
    /// Offset to interrupt handler
    base_low: u16,
    /// Segment selector
    selector: u16,
    /// Reserved or 0 for all gate types
    reserved: u8 = 0,
    /// Gate type (0b101 for task, 0b110 for interrupt, 0b111 for trap)
    gate_type: GateType,
    /// Size of gate (0: 16bits, 1: 32bits)
    is_32b: u1,
    zero: u1 = 0,
    /// Minimum ring level of caller to invoke the handler
    privilege: u2,
    /// 1 if entry is present
    present: u1,
    base_high: u16,

    pub fn init(base: u32, selector: u16, gate_type: GateType, privilege: u2) IdtEntry {
        return .{
            .base_low = @truncate(base),
            .selector = selector,
            .gate_type = gate_type,
            .is_32b = 1, // TODO: Any point in exposing this?
            .privilege = privilege,
            .present = 1,
            .base_high = @truncate(base >> 16),
        };
    }
};
const IdtRegister = packed struct {
    limit: u16,
    base: u32,
};

var idt: [256]IdtEntry = std.mem.zeroes([256]IdtEntry);
var idtr: IdtRegister = .{
    .limit = @sizeOf(@TypeOf(idt)) - 1,
    .base = undefined,
};

/// Gets a stub function (struct with fn) for the given interrupt id.
/// Each ID gets a unique stub
fn interruptStub(comptime name: []const u8, comptime id: u32) type {
    return struct {
        const ID = id;
        fn stub() void {
            term.print(name, .{});
            asm volatile (
                \\ cli
                \\ hlt
            );
        }
    };
}

fn makeIsr(comptime id: u32, comptime name: []const u8) IdtEntry {
    const stub = interruptStub(name, id);
    return .init(@intFromPtr(&stub.stub), gdt.KERNEL_CS, .interrupt, 0);
}

pub fn init() void {
    term.print("Init IDT... ", .{});

    idt[0] = makeIsr(0, "Divide Error");
    idt[1] = makeIsr(1, "Debug");
    idt[2] = makeIsr(2, "NMI");
    idt[3] = makeIsr(3, "Break");
    idt[4] = makeIsr(4, "Overflow");
    idt[5] = makeIsr(5, "BOUND");
    idt[6] = makeIsr(6, "Invalid Opcode");
    idt[7] = makeIsr(7, "Device not available");
    idt[8] = makeIsr(8, "Double Fault");
    idt[9] = makeIsr(9, "Coprocessor Segment Overrun");
    idt[10] = makeIsr(10, "Invalid TSS");
    idt[11] = makeIsr(11, "Segment Not Present");
    idt[12] = makeIsr(12, "Stack-Segment Fault");
    idt[13] = makeIsr(13, "General Protection");
    idt[14] = makeIsr(14, "Page Fault");
    // idt[15] Intel reserved
    idt[16] = makeIsr(16, "Math Fault");
    idt[17] = makeIsr(17, "Alignment Check");
    idt[18] = makeIsr(18, "Machine Check");
    idt[19] = makeIsr(19, "SIMD FP Exception");
    idt[20] = makeIsr(20, "Virtualization Exception");
    idt[21] = makeIsr(21, "Control Protection Exception");
    // idt[22] - idt[31] Intel reserved

    idt[255] = makeIsr(255, "Spurious");

    idtr.base = @intFromPtr(&idt);
    asm volatile ("lidt (%eax)"
        :
        : [eax] "r" (&idtr),
    );

    term.print("Done!\n", .{});
}
