// Chapter 12: Advanced Programmable Interrupt Controller (APIC)
// Intel 64 and IA-32 Software Developer Manual, Vol 3, Oct 2024
//
// Uses APIC as opposed to the legacy(?) 8259 PIC.
//
// The local APIC (one per CPU) two primary functions:
// * Receiving interrupts from internal sources and external I/O APIC (or other)
// * Send and receive interprocessor interrupt (IPI) messages on MP systems.
//
// Possible interrupt sources:
// * Locally connected I/O: I/O devices connect directly to processor interrupt pins.
// * External I/O: Interrupt messages sent by the I/O APIC
// * Inter/processor interrupts (IPI)
// * APIC timer generated interrupts
// * Performance monitoring counter interrutps
// * Thermal sensor interrupts
// * APIC internal error interrupts
//
// The external I/O APIC (part of Intel system chipset) has the primary function]
// of receiving external interrupts from I/O devices, relaying them to local APIC.
//
// As interrupts are sent to its processor core, the processor uses the interrupt
// and exception mechanism setup in idt.zig is.

const arch = @import("arch.zig");
const term = @import("term.zig");

var apic_base: u32 = undefined;

// APIC registers are memory-mapped starting at APIC base.
// The registers are of various widths but aligned on 128-bit boundaries.
// They all need to be accessed using 32 bit loads/stores

// Offset bye offsets for APIC registers.
// Spurious Interrupt Vector Register, Read/Write
const APIC_SPURIOUS_OFFSET = 0xF0;

/// Read from local APIC register
pub fn apicRead(reg: u32) u32 {
    const src: *u32 = @ptrFromInt(apic_base + reg);
    return src.*;
}

/// Write to local APIC register
pub fn apicWrite(reg: u32, value: u32) void {
    const dest: *u32 = @ptrFromInt(apic_base + reg);
    dest.* = value;
}

pub fn init() void {
    term.print("Init PIC... ", .{});

    // Disable 8259 by masking all interrupts
    arch.outb(0x0021, 0xff); // Master data port
    arch.outb(0x00A1, 0xff); // Slave data port

    const leaf = arch.cpuid(0x1, undefined);

    const has_apic = leaf.edx & (1 << 9) != 0;
    if (!has_apic) {
        @panic("No APIC!");
    }

    // Ensure APIC is enabled
    const apic_base_msr = arch.rdmsr(0x1B); // IA32_APIC_BASE MSR
    arch.wrmsr(0x1B, apic_base_msr | (1 << 11));

    // Get APIC base address
    // TODO: OsDev suggets remapping the registers
    apic_base = @truncate(apic_base_msr & 0xFFFFF000);

    // Set spurious interrupt vector bit
    apicWrite(APIC_SPURIOUS_OFFSET, apicRead(APIC_SPURIOUS_OFFSET) | 0x100);

    term.print("APIC_BASE {x}\n", .{apic_base});

    term.print("Done!\n", .{});
}
