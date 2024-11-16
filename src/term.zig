// VGA text printing

const std = @import("std");

pub const Color = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    light_brown = 14,
    white = 15,
};

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;

const vga_buffer: [*]volatile u16 = @ptrFromInt(0xB8000);
const color: u16 = @as(u16, @intFromEnum(Color.light_grey)) | @as(u16, @intFromEnum(Color.black)) << 4;

var cursor: [2]u16 = .{ 0, 0 };

pub fn init() void {
    for (0..VGA_HEIGHT) |y| {
        for (0..VGA_WIDTH) |x| {
            vga_buffer[x + y * VGA_WIDTH] = @as(u16, ' ') | @as(u16, (color << 8));
        }
    }
    cursor = .{ 0, 0 };
}
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = @splat(0);
    var stream = std.io.fixedBufferStream(&buf);

    std.fmt.format(stream.writer(), fmt, args) catch {
        return;
    };

    for (stream.getWritten()) |char| {
        putChar(char);
    }
}

fn putChar(char: u8) void {
    if (char == '\n') {
        newLine();
        return;
    }

    if (cursor[0] >= VGA_WIDTH) {
        newLine();
    }

    vga_buffer[cursor[0] + cursor[1] * VGA_WIDTH] = @as(u16, char) | color << 8;
    cursor[0] += 1;
}
fn newLine() void {
    cursor = .{
        0,
        (cursor[1] + 1) % VGA_HEIGHT,
    };
}
