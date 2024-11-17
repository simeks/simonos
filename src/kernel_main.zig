const std = @import("std");
const term = @import("term.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const apic = @import("apic.zig");

pub fn panic(
    message: []const u8,
    _: ?*std.builtin.StackTrace,
    _: ?usize,
) noreturn {
    term.print("PANIC: {s}\n", .{message});
    // x86 hang
    asm volatile (
        \\ cli
        \\ hlt
    );
    unreachable;
}

export fn kernel_main() callconv(.C) void {
    term.init();

    gdt.init();
    idt.init();
    apic.init();

    // x86: Enable interrupts and halt
    asm volatile (
    // \\ sti
        \\ hlt
    );
    unreachable;
}

// Multiboot header
// https://www.gnu.org/software/grub/manual/multiboot/multiboot.html
export var multiboot_header: extern struct {
    const MAGIC: u32 = 0x1BADB002;
    const FLAG_ALIGN: u32 = 1 << 0;
    const FLAG_MEMINFO: u32 = 1 << 1;
    const FLAGS: u32 = FLAG_ALIGN | FLAG_MEMINFO;

    magic: u32 = MAGIC,
    flags: u32 = FLAGS,
    checksum: u32 = ~(MAGIC + FLAGS) +% 1,
} align(4) linksection(".multiboot") = .{};
