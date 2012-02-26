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

proc CreateWindow.SetupType { wizard id } {
    CreateWindow.CustomBlankPane1 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 0 -weight 1

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 0 -sticky ew -padx [list 0 10] -pady 15
    $id widget set Caption -widget $base.caption

    set f [frame $base.types]
    grid $f -row 1 -column 0 -sticky new

    grid columnconfigure $f 1 -weight 1

    if {[info exists ::InstallJammer]} { return }

    foreach id [SetupTypes children] {
        if {![$id active] || ![$id get ShowSetupType]} { continue }

        set radio $f.radio[incr0 row]

        ttk::radiobutton $radio -text [$id name] \
            -value [$id name] -variable ::info(InstallType) \
            -command ::InstallJammer::SelectSetupType

        set label $f.label$row
        Label $label -autowrap 1 -anchor nw -justify left \
            -text [::InstallJammer::GetText $id Description]

        grid $radio -column 0 -row $row -sticky nw -padx 5 -pady 10
        grid $label -column 1 -row $row -sticky ew -padx 5 -pady 10
    }
}
