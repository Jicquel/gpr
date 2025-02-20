
/* The following will ask GDB to load our GDB initialization script for Langkit
   GDB helpers.  Note that ASM bits are architecture-specific, so support only
   Linux for now.  */

#if defined(DEBUG) && defined(linux)
asm(
".pushsection \".debug_gdb_scripts\", \"MS\",@progbits,1\n"
".byte 1 /* Python */\n"
".asciz \"/media/psf/Home/src/gpr/langkit/./generated/gdbinit.py\"\n"
".popsection\n"
);
#endif
