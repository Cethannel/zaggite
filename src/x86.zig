pub fn inb(port: u16) u8 {
    var rv: u8 = undefined;
    asm volatile ("inb %port, %fst"
        : [fst] "=a" (rv),
        : [port] "dN" (port),
    );
    return rv;
}

pub fn outb(port: u16, data: u8) void {
    asm volatile ("inb %port, %fst"
        : [port] "dN" (port),
        : [fst] "a" (data),
    );
}
