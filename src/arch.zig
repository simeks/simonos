// Common x86 specifics

const CpuidLeaf = struct {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
};

pub fn cpuid(eax_in: u32, ecx_in: u32) CpuidLeaf {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;
    asm volatile ("cpuid"
        : [_] "={eax}" (eax),
          [_] "={ebx}" (ebx),
          [_] "={ecx}" (ecx),
          [_] "={edx}" (edx),
        : [_] "{eax}" (eax_in),
          [_] "{ecx}" (ecx_in),
    );
    return .{
        .eax = eax,
        .ebx = ebx,
        .ecx = ecx,
        .edx = edx,
    };
}

pub fn rdmsr(msr: u32) u64 {
    var eax: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("rdmsr"
        : [_] "={eax}" (eax),
          [_] "={edx}" (edx),
        : [_] "{ecx}" (msr),
    );

    return (@as(u64, edx) << 32) | @as(u64, eax);
}

pub fn wrmsr(msr: u32, value: u64) void {
    const eax: u32 = @truncate(value);
    const edx: u32 = @truncate(value >> 32);

    asm volatile ("wrmsr"
        :
        : [_] "{eax}" (eax),
          [_] "{edx}" (edx),
          [_] "{ecx}" (msr),
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "{al}" (-> u8),
        : [port] "{dx}" (port),
    );
}
pub fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[ret]"
        : [ret] "{ax}" (-> u16),
        : [port] "{dx}" (port),
    );
}
pub fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[ret]"
        : [ret] "{eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}
pub fn outb(port: u16, value: u8) void {
    return asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}
pub fn outw(port: u16, value: u16) void {
    return asm volatile ("outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "{dx}" (port),
    );
}
pub fn outl(port: u16, value: u32) void {
    return asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "{dx}" (port),
    );
}
