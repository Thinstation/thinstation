/* ----------------------------------------------------------------------- *
 *
 *   Copyright 2009 Erwan Velu - All Rights Reserved
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
 *   Boston MA 02110-1301, USA; either version 2 of the License, or
 *   (at your option) any later version; incorporated herein by reference.
 *
 * ----------------------------------------------------------------------- */

/*
 * ifmem.c
 *
 */


#include <alloca.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <memory.h>
#include <unistd.h>
#include <syslinux/boot.h>
#include <com32.h>
#include <consoles.h>

static inline void error(const char *msg)
{
    fputs(msg, stderr);
}

static void usage(void) 
{
 error("Run one command if system memory is greater than <size>, another if it doesn't. \n"
 "Usage: \n"
 "   label ifmem \n"
 "       com32 ifmem.c32 \n"
 "       append <option> <size> -- equal_greater_boot_entry_1 -- less_boot_entry_2 \n"
 "   label boot_entry_1 \n"
 "   	  kernel vmlinuz_entry1 \n"
 "	  append ... \n"
 "   label boot_entry_2 \n"
 "       kernel vmlinuz_entry2 \n"
 "       append ... \n"
 "\n"
 "options could be :\n"
 "   debug     : display some debugging messages \n"
 "   dry-run   : just do the detection, don't boot \n"
 "\n"
 "size could be:\n"
 "   2048\n"
 "\n");
}

/* XXX: this really should be librarized */
static void boot_args(char **args)
{
    int len = 0, a = 0;
    char **pp;
    const char *p;
    char c, *q, *str;

    for (pp = args; *pp; pp++)
		len += strlen(*pp) + 1;

    q = str = alloca(len);
    for (pp = args; *pp; pp++) {
		p = *pp;
		while ((c = *p++))
			*q++ = c;
		*q++ = ' ';
		a = 1;
    }
    q -= a;
    *q = '\0';

    if (!str[0])
		syslinux_run_default();
    else
		syslinux_run_command(str);
}

int main(int argc, char *argv[])
{
    char **args[3];
    int i=0;
    int n=0;
    bool enough_mem = true;
    bool debug = false;
    bool dryrun = false;
	struct e820entry map[E820MAX];
    unsigned long memsize = 0;
    int count = 0;
	
	console_ansi_raw();
    detect_memory_e820(map, E820MAX, &count);
    memsize = (memsize_e820(map, count) + (1 << 9) >> 10);
    memsize++;
	
    /* If no argument got passed, let's show the usage */
    if (argc == 1) {
	    usage();
	    return -1;
    }

    for (i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--")) {
			argv[i] = NULL;
			args[n++] = &argv[i + 1];
		} else if (!strcmp(argv[i], "dry-run")) {
			dryrun = true;
		} else if (!strcmp(argv[i], "debug")) {
			debug = true;
		} else if (strtoul(argv[i], &argv[i], 10) >= memsize) {
			if (debug)
				printf("'%lu' MiB on this system.\n", --memsize);
			enough_mem = false;
		}
		if (n >= 2)
			break;
	}
	while (n < 2) {
		args[n] = args[n - 1];
		n++;
	}
	if (debug) {
		printf("\nBooting labels are : '%s' or '%s'\n", *args[0], *args[1]);
		printf("Memory requirements were""%s""met by this system, let's boot '%s'\n",
			enough_mem ? " " : " not ",
			enough_mem ? *args[0] : *args[1]);
		printf("Sleeping 5sec before booting.\n");
		if (!dryrun)
			sleep(5);
    }
    if (!dryrun)
		boot_args(enough_mem ? args[0] : args[1]);
    else
		printf("Dry-run mode, let's just exit.\n");
		return -1;
}
