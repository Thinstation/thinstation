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
    CreateWindow.CustomTextPane1 $wizard $id

    if {![$id get UserMustAcceptLicense]} { return }

    set base [$id widget get ClientArea]

    ttk::radiobutton $base.accept -variable ::info(LicenseAccepted) -value 1 \
        -command [list $wizard itemconfigure next -state normal]
    grid $base.accept -row 1 -column 0 -sticky w
    $id widget set AcceptRadiobutton -widget $base.accept

    ttk::radiobutton $base.decline -variable ::info(LicenseAccepted) -value 0 \
        -command [list $wizard itemconfigure next -state disabled]
    grid $base.decline -row 2 -column 0 -sticky w
    $id widget set DeclineRadiobutton -widget $base.decline
}
