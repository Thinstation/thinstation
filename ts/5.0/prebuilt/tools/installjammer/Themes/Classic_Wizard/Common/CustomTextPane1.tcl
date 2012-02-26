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

proc CreateWindow.CustomTextPane1 { wizard id } {
    set base [$wizard widget get $id]

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 1 -weight 1

    label $base.image -relief sunken -bd 2 -width 0 -height 0
    grid  $base.image -row 0 -column 0 -rowspan 2 -sticky nw -padx 15 -pady 15
    $id widget set Image -widget $base.image -type image

    frame $base.frame
    grid  $base.frame -row 0 -column 1 -padx [list 0 10] -pady 15 -sticky ew

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 1 -weight 1

    label $base.frame.icon -height 0 -width 0
    grid  $base.frame.icon -row 0 -column 0 -padx [list 0 10] -sticky w
    $id widget set Icon -widget $base.frame.icon -type image

    Label $base.frame.caption -autowrap 1 -anchor nw -justify left
    grid  $base.frame.caption -row 0 -column 1 -sticky new
    $id widget set Caption -widget $base.frame.caption

    Label $base.message -autowrap 1 -anchor nw -justify left
    grid  $base.message -row 1 -column 1 -sticky new -padx [list 0 10] -pady 5
    $id widget set Message -widget $base.message
}
