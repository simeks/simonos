const std = @import("std");
const term = @import("term.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const apic = @import("apic.zig");

const assert = std.debug.assert;

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

export fn kernel_main(mb_info: *const MultibootInfo) callconv(.C) void {
    term.init();

    assert(mb_info.flags & (1 << 0) != 0); // Memory range
    term.print("mem_lower: {d}\n", .{mb_info.mem_lower});
    term.print("mem_upper: {d}\n", .{mb_info.mem_upper});

    assert(mb_info.flags & (1 << 6) != 0); // mmap
    term.print("mmap_length: {d}\n", .{mb_info.mmap_length});
    term.print("mmap_addr: {x}\n", .{mb_info.mmap_addr});

    gdt.init();
    idt.init();
    apic.init();

    // x86: Enable interrupts and halt
    asm volatile (
        \\ sti
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

const MultibootInfo = packed struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    syms: u96,
    mmap_length: u32,
    mmap_addr: u32,
    drives_length: u32,
    drives_addr: u32,
    config_table: u32,
    boot_loader_name: u32,
    apm_table: u32,
    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,
    framebuffer_addr: u64,
    framebuffer_pitch: u32,
    framebuffer_width: u32,
    framebuffer_height: u32,
    framebuffer_bpp: u8,
    framebuffer_type: u8,
    framebuffer_color_info: u48,
};
