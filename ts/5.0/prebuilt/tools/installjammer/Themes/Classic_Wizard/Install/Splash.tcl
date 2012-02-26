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

proc CreateWindow.Splash { wizard id } {
    if {![$id get SplashTimer timer]} { return }
    if {![::InstallJammer::ImageExists $id,Image]} { return }

    set base   [$id window]
    set image  [::InstallJammer::Image $id Image]
    set width  [image width $image]
    set height [image height $image]

    toplevel    $base
    wm withdraw $base
    wm override $base 1
    ::InstallJammer::PlaceWindow $id -width $width -height $height

    label $base.l
    pack  $base.l
    $id widget set Image -type image -widget $base.l

    bind $base.l <Button-1> [list ::InstallJammer::Window hide $base]
}
