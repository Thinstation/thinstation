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

proc CreateWindow.SetupComplete { wizard id } {
    set base [$wizard widget get $id]

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 1 -weight 1

    Image $base.image $id Image
    grid  $base.image -row 0 -column 0 -rowspan 5 -sticky nw -padx 15 -pady 15

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid $base.caption -row 0 -column 1 -sticky nw -padx [list 0 15] -pady 15
    $id widget set Caption -widget $base.caption

    Label $base.text -autowrap 1 -anchor nw -justify left
    grid $base.text -row 1 -column 1 -sticky sew -padx [list 0 15] -pady 15
    $id widget set Text -widget $base.text
}
