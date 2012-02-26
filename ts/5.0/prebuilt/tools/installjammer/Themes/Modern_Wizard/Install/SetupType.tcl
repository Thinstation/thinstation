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
    CreateWindow.CustomBlankPane2 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 0 -weight 1

    ScrolledWindow $base.sw
    grid $base.sw -row 0 -column 0 -sticky news -pady [list 4 0]

    ListBox $base.list -bd 2 -relief sunken -background #FFFFFF \
        -highlightthickness 0 -selectmode single -selectfill 1 -padx 0
    $base.sw setwidget $base.list
    $id widget set SetupTypeListBox -widget $base.list -type listbox

    labelframe $base.frame -relief groove -bd 2
    grid $base.frame -row 0 -column 1 -sticky news -padx [list 10 0]
    $id widget set DescriptionLabel -widget $base.frame

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    Label $base.frame.desc -width 25 -autowrap 1 -anchor nw -justify left
    grid $base.frame.desc -row 0 -column 0 -sticky news -padx 10 -pady 5
    $id widget set DescriptionText -widget $base.frame.desc

    if {[info exists ::InstallJammer]} {
        $base.list insert end #auto -text "Typical"
        $base.list selection set 0

        ::InstallJammer::SetVirtualText $id DescriptionText \
            "Program will be installed with the most common options."
        return
    }
}
