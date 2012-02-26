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

proc CreateWindow.CustomTextPane2 { wizard id } {
    CreateWindow.CustomBlankPane1 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 0 -weight 1

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 0 -sticky new -pady [list 0 5]
    $id widget set Caption -widget $base.caption

    frame $base.frame
    grid  $base.frame -row 1 -column 0 -sticky news

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    text $base.frame.text \
        -state disabled -wrap word -highlightthickness 0 \
        -yscrollcommand [list $base.frame.vs set] \
        -xscrollcommand [list $base.frame.hs set]
    grid $base.frame.text -row 0 -column 0 -sticky news
    $id widget set Text -widget $base.frame.text

    ttk::scrollbar $base.frame.vs -command [list $base.frame.text yview]
    grid $base.frame.vs -row 0 -column 1 -sticky ns

    ttk::scrollbar $base.frame.hs -command [list $base.frame.text xview] \
        -orient horizontal
    grid $base.frame.hs -row 1 -column 0 -sticky ew
}
