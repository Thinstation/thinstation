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

proc CreateWindow.CopyFiles { wizard id } {
    set base [Toplevel $id 347x110]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 1 -weight 1

    $id get AllowUserToCancel allowCancel
    if {$allowCancel} {
	wm protocol $base WM_DELETE_WINDOW exit
    } else {
	wm protocol $base WM_DELETE_WINDOW noop
    }

    label $base.icon
    grid  $base.icon -row 0 -column 0 -rowspan 3 -sticky nw -padx 15 -pady 15
    $id widget set Icon -type image -widget $base.icon

    label $base.caption -anchor w
    grid  $base.caption -row 0 -column 1 -columnspan 2 -sticky nw \
        -padx [list 0 15] -pady 15
    $id widget set Caption -widget $base.caption

    label $base.message -anchor w
    grid  $base.message -row 1 -column 1 -columnspan 2 -sticky nw
    $id widget set Message -widget $base.message

    ::Progressbar::New $base.progress
    grid $base.progress -row 2 -column 1 -sticky ew -pady [list 0 10]
    $id widget set ProgressValue -widget $base.progress -type progress

    if {$allowCancel} {
	ttk::button $base.cancel -text "Cancel" -width 10 \
            -command [list ::InstallJammer::exit 1]
        grid $base.cancel -row 2 -column 2 -padx 5 -pady [list 0 10]
        $id widget set CancelButton -widget $base.cancel
    }
}
