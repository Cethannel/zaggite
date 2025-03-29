/**
 * Kernel Linker Script
 */

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2024 Samuel Fiedler
 */

KERNEL_PHYS_START = 1M;
KERNEL_STACK_SIZE = 0x4000;

ENTRY(_start)

SECTIONS {
    . = KERNEL_PHYS_START;
    __kernel_start = .;

    .start : ALIGN(4K) {
        __kernel_boot_info = .;
        . += 8;
        KEEP(*(.start*));
    }
    .start = KERNEL_PHYS_START;

    .text : ALIGN(4K) {
        *(.text*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata*)
    }

    .data : ALIGN(4K) {
        *(.data*)
    }

    .bss : ALIGN(4K) {
        *(COMMON*)
        *(.bss*)

        . = ALIGN(16);
        __stack_bottom = .;
        . += KERNEL_STACK_SIZE;
        __stack_top = .;
    }

    .debug_info : ALIGN(4K) {
        __debug_info_start = .;
        KEEP(*(.debug_info*))
        __debug_info_end = .;
    }

    .debug_abbrev : ALIGN(4K) {
        __debug_abbrev_start = .;
        KEEP(*(.debug_abbrev*))
        __debug_abbrev_end = .;
    }

    .debug_str : ALIGN(4K) {
        __debug_str_start = .;
        KEEP(*(.debug_str*))
        __debug_str_end = .;
    }

    .debug_line : ALIGN(4K) {
        __debug_line_start = .;
        KEEP(*(.debug_line*))
        __debug_line_end = .;
    }

    .debug_ranges : ALIGN(4K) {
        __debug_ranges_start = .;
        KEEP(*(.debug_ranges*))
        __debug_ranges_end = .;
    }

    __kernel_end = .;
}
