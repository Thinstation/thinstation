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

proc CreateWindow.Setup { wizard id } {
    set base [Toplevel $id 325x90]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 1 -weight 1

    label $base.icon
    grid  $base.icon -row 0 -column 0 -sticky w -padx 5
    $id widget set Icon -widget $base.icon -type image

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid $base.caption -row 0 -column 1 -sticky w -pady [list 10 0]
    $id widget set Caption -widget $base.caption

    ::Progressbar::New $base.progress
    grid $base.progress -row 1 -column 1 -sticky ew -padx [list 0 10] -pady 5
    $id widget set ProgressBar -widget $base.progress -type progress
}
