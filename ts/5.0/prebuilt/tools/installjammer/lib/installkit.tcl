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

## Create a generic InstallKit from the current running process.
proc ::installkit::base { {installkit ""} args } {
    global conf
    global info

    if {[info exists conf(BuildingInstallkit)]} {
        ## An installkit is already being built.  We need to wait
        ## for that one to finish, and then we'll just return back
        ## to the caller.
        vwait ::conf(BuildingInstallkit)
    }

    set conf(BuildingInstallkit) 1

    if {$installkit eq ""} {
        set installkit [::InstallJammer::TmpDir installkit$info(Ext)]
    }

    set res 0
    if {![file exists $installkit]} {
        set res [catch {
            eval ::InstallJammer::Wrap -o [list $installkit] $args
        } err]
    }

    unset conf(BuildingInstallkit)

    if {$res} { return -code error $err }

    return [::InstallJammer::Normalize $installkit]
}

proc ::installkit::Mount { crapFile mountPoint } {
    crapvfs::mount $crapFile $mountPoint
}

proc ::installkit::Unmount { mountPoint } {
    crapvfs::unmount $mountPoint
}
