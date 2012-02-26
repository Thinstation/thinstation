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

proc CreateWindow.UninstallComplete { wizard id } {
    set base [$id window]

    toplevel     $base
    wm withdraw  $base
    wm geometry  $base 347x110
    wm protocol  $base WM_DELETE_WINDOW [list $wizard finish 1]
    wm resizable $base 0 0
    ::InstallJammer::SetTitle    $base $id
    ::InstallJammer::PlaceWindow $id -width 347 -height 110

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 1 -weight 1

    label $base.icon
    grid  $base.icon -row 0 -column 0 -sticky nw -padx 20 -pady 5
    $id widget set Icon -widget $base.icon -type image

    Label $base.label -autowrap 1 -anchor nw -justify left
    grid  $base.label -row 0 -column 1 -sticky new -pady 5
    $id widget set Caption -widget $base.label

    set text [::InstallJammer::GetText $id FinishButton]
    set width [string length $text]
    if {$width < 12} { set width 12 }

    ttk::button $base.finish -width $width -command [list $wizard finish 1]
    grid   $base.finish -row 1 -column 1 -sticky se -padx 5 -pady 5
    $id widget set FinishButton -widget $base.finish

    focus  $base.finish
}
