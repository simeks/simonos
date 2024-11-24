// Chapter 12: Advanced Programmable Interrupt Controller (APIC)
// Intel 64 and IA-32 Software Developer Manual, Vol 3, Oct 2024
//
// Uses APIC as opposed to the legacy(?) 8259 PIC.
//
// The local APIC two primary functions:
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
// The external I/O APIC (part of Intel system chipset) has the primary function
// of receiving external interrupts from I/O devices, relaying them to local APIC.
//
// As interrupts are sent to its processor core, the processor uses the interrupt
// and exception mechanism setup in idt.zig is.

const arch = @import("arch.zig");
const term = @import("term.zig");

var lapic_base: u32 = undefined;

// APIC registers are memory-mapped starting at APIC base.
// The registers are of various widths but aligned on 128-bit boundaries.
// They all need to be accessed using 32 bit loads/stores

// Offset bye offsets for APIC registers.
// Spurious Interrupt Vector Register, Read/Write
const APIC_SPURIOUS = 0xF0;
const APIC_LVT_LINT0 = 0x350;
const APIC_LVT_LINT1 = 0x360;

/// Read from local APIC register
fn lapicRead(reg: u32) u32 {
    const src: *u32 = @ptrFromInt(lapic_base + reg);
    return src.*;
}

/// Write to local APIC register
fn lapicWrite(reg: u32, value: u32) void {
    const dest: *u32 = @ptrFromInt(lapic_base + reg);
    dest.* = value;
}
//
// fn ioapicRead() u32 {
//     const ptr: *volatile u32 = @ptrFromInt();
// }

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
    lapic_base = @truncate(apic_base_msr & 0xFFFFF000);

    // Set spurious interrupt vector bit
    // Sets vector to 0xFF
    lapicWrite(APIC_SPURIOUS, lapicRead(APIC_SPURIOUS) | 0x1FF);

    asm volatile ("sti");
    // @breakpoint();

    term.print("Done!\n", .{});
}
