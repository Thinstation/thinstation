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

proc Toplevel { id geometry } {
    set base [$id window]

    toplevel     $base
    wm withdraw  $base
    update idletasks
    wm transient $base .
    wm protocol  $base WM_DELETE_WINDOW [list ::InstallJammer::exit 1]
    wm resizable $base 0 0
    wm geometry  $base $geometry
    ::InstallJammer::SetTitle $base $id
    lassign [split $geometry x] w h
    ::InstallJammer::PlaceWindow $id -width $w -height $h

    return $base
}

proc Image { path id field } {
    label $path -relief sunken -borderwidth 2 -width 0 -height 0
    ::InstallJammer::SetImage $path $id $field
}
