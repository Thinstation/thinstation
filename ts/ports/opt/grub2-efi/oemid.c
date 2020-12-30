/* acpi.c  - Display acpi tables.  */
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
#include <grub/types.h>
#include <grub/mm.h>
#include <grub/misc.h>
#include <grub/normal.h>
#include <grub/acpi.h>
#include <grub/extcmd.h>
#include <grub/env.h>
#include <grub/dl.h>

#pragma GCC diagnostic ignored "-Wcast-align"

GRUB_MOD_LICENSE ("GPLv3+");

static void
disp_acpi_rsdpv1 (struct grub_acpi_rsdp_v10 *rsdp)
{
  grub_env_set ( "OEMID", rsdp->oemid);
}

static grub_err_t
grub_cmd_oemid (struct grub_extcmd_context *ctxt,
		 int argc __attribute__ ((unused)),
		 char **args __attribute__ ((unused)))
{
      struct grub_acpi_rsdp_v10 *rsdp1 = grub_acpi_get_rsdpv1 ();
      if (rsdp1)
	  disp_acpi_rsdpv1 (rsdp1);

  return GRUB_ERR_NONE;
}

static grub_extcmd_t cmd;

GRUB_MOD_INIT(oemid)
{
  cmd = grub_register_extcmd ("oemid", grub_cmd_oemid, 0, 0,
			      N_("Show OEM ID."), 0);
}

GRUB_MOD_FINI(oemid)
{
  grub_unregister_extcmd (cmd);
}


