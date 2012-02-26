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

proc RaiseStep { wizard id } {
    set widget [$id widget get Caption]
    if {$widget ne ""} {
        if {![string length [::InstallJammer::GetText $id Caption]]} {
            grid remove $widget
        } else {
            grid $widget
        }
    }

    set widget [$id widget get Message]
    if {$widget ne ""} {
        if {![string length [::InstallJammer::GetText $id Message]]} {
            grid remove $widget
        } else {
            grid $widget
        }
    }

    set widget [$id widget get ClientArea]
    if {$widget ne ""} {
        grid configure $wizard.buttons -pady {18 5}
    } else {
        grid configure $wizard.buttons -pady 5
    }
}
