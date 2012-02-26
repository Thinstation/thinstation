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

proc CreateWindow.UninstallDetails { wizard id } {
    set base [$id window]

    toplevel     $base
    wm withdraw  $base
    wm geometry  $base 500x400
    wm protocol  $base WM_DELETE_WINDOW exit
    wm resizable $base 0 0
    ::InstallJammer::SetTitle    $base $id
    ::InstallJammer::PlaceWindow $id -width 500 -height 400

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 1 -weight 1

    label $base.icon
    grid  $base.icon -row 0 -column 0 -sticky nw -padx 5 -pady 5
    $id widget set Icon -widget $base.icon -type image

    label $base.caption 
    grid  $base.caption -row 0 -column 1 -sticky sw -padx 5 -pady 5
    $id widget set Caption -widget $base.caption

    text $base.text -bg #FFFFFF -bd 2 -relief sunken -wrap word
    grid $base.text -row 1 -column 0 -columnspan 2 -sticky news
    $id widget set Errors -widget $base.text

    set text [::InstallJammer::GetText $id FinishButton]
    set width [string length $text]
    if {$width < 12} { set width 12 }

    ttk::button $base.finish -width $width -command [list $wizard finish 1]
    grid $base.finish -row 2 -column 1 -sticky se -padx 5 -pady 5
    $id widget set FinishButton -widget $base.finish
}
