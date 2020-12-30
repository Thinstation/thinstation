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
#include <grub/memory.h>
#include <grub/mm.h>
#include <grub/env.h>

unsigned long long total = 0;

GRUB_MOD_LICENSE ("GPLv3+");

#ifndef GRUB_MACHINE_EMU

/* Helper for grub_cmd_lsmmap.  */
static int
sysmem_hook (grub_uint64_t addr, grub_uint64_t size, grub_memory_type_t type,
         void *data)
{
  total += size;
  return 0;
}
#endif

static grub_err_t
grub_cmd_sysmem (grub_command_t cmd __attribute__ ((unused)),
         int argc __attribute__ ((unused)),
         char **args __attribute__ ((unused)))

{
#ifndef GRUB_MACHINE_EMU
  char s[32];
  grub_machine_mmap_iterate (sysmem_hook, NULL);
  grub_snprintf (s, 31, "%llu", total / 1024 / 1024);
  grub_env_set("RAM", s);
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
