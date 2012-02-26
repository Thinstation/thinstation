## $Id$
##
## BEGIN LICENSE BLOCK
##
## Copyright (C) 2002  Damon Courtney
## 
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## version 2 as published by the Free Software Foundation.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License version 2 for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the
##     Free Software Foundation, Inc.
##     51 Franklin Street, Fifth Floor
##     Boston, MA  02110-1301, USA.
##
## END LICENSE BLOCK

proc CreateWindow.License { wizard id } {
    set base [$wizard widget get $id]

    CreateWindow.CustomTextPane3 $wizard $id

    ttk::checkbutton $base.accept -variable ::info(LicenseAccepted) -command {
        if {$::info(LicenseAccepted)} {
            $::info(Wizard) itemconfigure next -state normal
        } else {
            $::info(Wizard) itemconfigure next -state disabled
        }
    }

    grid $base.accept -columnspan 2 -sticky w -padx 10
    $id widget set AcceptCheck -widget $base.accept
}
