/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2008  Free Software Foundation, Inc.
 *
 *  GRUB is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  GRUB is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GRUB.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <grub/dl.h>
#include <grub/misc.h>
#include <grub/command.h>
#include <grub/i18n.h>
#include <grub/memory.h>
#include <grub/mm.h>

GRUB_MOD_LICENSE ("GPLv3+");

#ifndef GRUB_MACHINE_EMU
static const char *names[] =
  {
    [GRUB_MEMORY_AVAILABLE] = N_("available RAM"),
    [GRUB_MEMORY_RESERVED] = N_("reserved RAM"),
    /* TRANSLATORS: this refers to memory where ACPI tables are stored
       and which can be used by OS once it loads ACPI tables.  */
    [GRUB_MEMORY_ACPI] = N_("ACPI reclaimable RAM"),
    /* TRANSLATORS: this refers to memory which ACPI-compliant OS
       is required to save accross hibernations.  */
    [GRUB_MEMORY_NVS] = N_("ACPI non-volatile storage RAM"),
    [GRUB_MEMORY_BADRAM] = N_("faulty RAM (BadRAM)"),
    [GRUB_MEMORY_PERSISTENT] = N_("persistent RAM"),
    [GRUB_MEMORY_PERSISTENT_LEGACY] = N_("persistent RAM (legacy)"),
    [GRUB_MEMORY_COREBOOT_TABLES] = N_("RAM holding coreboot tables"),
    [GRUB_MEMORY_CODE] = N_("RAM holding firmware code")
  };

/* Helper for grub_cmd_lsmmap.  */
static int
lsmmap_hook (grub_uint64_t addr, grub_uint64_t size, grub_memory_type_t type,
         void *data)
{
  long long *total = (long long *)data;
  *total += (long long)size;
  return 0;
}
#endif

static grub_err_t
grub_cmd_sysmem (grub_command_t cmd __attribute__ ((unused)),
         int argc __attribute__ ((unused)),
         char **args __attribute__ ((unused)))

{
#ifndef GRUB_MACHINE_EMU
  long long total;
  grub_machine_mmap_iterate (lsmmap_hook, &total);
#endif
  return 0;
}

static grub_command_t cmd;

GRUB_MOD_INIT(sysmem)
{
  cmd = grub_register_command ("sysmem", grub_cmd_sysmem,
			       0, N_("Test amount of system RAM."));
}

GRUB_MOD_FINI(sysmem)
{
  grub_unregister_command (cmd);
}
