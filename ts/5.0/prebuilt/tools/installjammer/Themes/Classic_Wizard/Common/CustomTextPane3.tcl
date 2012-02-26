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

proc CreateWindow.CustomTextPane3 { wizard id } {
    set base [$wizard widget get $id]

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 1 -weight 1

    label $base.icon -height 0 -width 0 
    grid  $base.icon -row 0 -column 0 -pady 10 -padx 10
    $id widget set Icon -widget $base.icon -type image

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 1 -sticky new -pady 10
    $id widget set Caption -widget $base.caption

    frame $base.frame
    grid  $base.frame -row 1 -column 0 -columnspan 2 -sticky news -padx 10

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    text $base.frame.text \
        -state disabled -wrap word -highlightthickness 0 \
        -yscrollcommand [list $base.frame.vs set]
    grid $base.frame.text -row 0 -column 0 -sticky news
    $id widget set Text -widget $base.frame.text

    ttk::scrollbar $base.frame.vs -command [list $base.frame.text yview]
    grid $base.frame.vs -row 0 -column 1 -sticky ns

    Label $base.message -autowrap 1 -anchor nw -justify left
    grid  $base.message -row 2 -column 0 -columnspan 2 -sticky ew \
        -padx [list 12 10] -pady 5
    $id widget set Message -widget $base.message
}
