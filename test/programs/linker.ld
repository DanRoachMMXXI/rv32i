/* STARTUP might be the thing I need to load startup code */
ENTRY(init)
SECTIONS
{
	. = 0x00000000;	/* sometimes this might be 0x10000 or something non-zero
			 * to make room for ROM and/or throwing faults on null
			 * or near null memory references */
	.text : { *(.text) }
	. = 0x08000000;
	.data : { *(.data) }
	.bss : { *(.bss) }
}
