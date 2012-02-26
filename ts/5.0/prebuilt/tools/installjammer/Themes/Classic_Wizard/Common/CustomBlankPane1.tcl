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

proc CreateWindow.CustomBlankPane1 { wizard id } {
    set base [$wizard widget get $id]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 1 -weight 1

    label $base.image -relief sunken -bd 2 -width 0 -height 0
    grid  $base.image -row 0 -column 0 -rowspan 2 -sticky nw -padx 15 -pady 15
    $id widget set Image -widget $base.image -type image

    frame $base.clientArea
    grid  $base.clientArea -row 0 -column 1 -padx [list 0 10] -pady 15 \
        -sticky news
    $id widget set ClientArea -widget $base.clientArea -type frame
}
