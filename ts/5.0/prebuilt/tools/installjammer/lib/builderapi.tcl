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

namespace eval ::BuilderAPI {}

proc ::BuilderAPI::GetAction { args } {
    ::InstallAPI::ParseArgs _args $args {
        -alias { string 1 }
        -setup { choice 0 "" {install uninstall} }
    }

    set setups $_args(-setup)
    if {$setups eq ""} { set setups [list install uninstall] }

    foreach setup $setups {
        set setup [string totitle $setup]

        set list [::InstallJammer::GetActionComponentList $setup]

        foreach id $list {
            if {[$id get Alias] eq $_args(-alias)} { return $id }
        }
    }
}

proc ::BuilderAPI::GetActionGroup { args } {
    ::InstallAPI::ParseArgs _args $args {
        -alias { string 1 }
        -setup { choice 0 "" {install uninstall} }
    }

    set setups $_args(-setup)
    if {$setups eq ""} { set setups [list install uninstall] }

    foreach setup $setups {
        set list [ActionGroups[string toupper $setup 0] children]

        foreach id $list {
            if {[$id get Alias] eq $_args(-alias)} { return $id }
        }
    }
}

proc ::BuilderAPI::ModifyObject { args } {
    ::InstallAPI::ParseArgs _args $args {
        -object { string  1 }
        -active { boolean 0 }
    }

    set id [::InstallJammer::ID $_args(-object)]

    if {[info exists _args(-active)]} {
        $id active $_args(-active)
    }
}

proc ::BuilderAPI::SetPlatformProperty { args } {
    ::InstallAPI::ParseArgs _args $args {
        -platform { string 1 }
        -property { string 1 }
        -value    { string 1 }
    }

    set platforms $_args(-platform)

    if {[string equal -nocase $_args(-platform) "all"]} {
        set platforms [AllPlatforms]
    }

    if {[string equal -nocase $_args(-platform) "unix"]} {
        set platforms [lremove [AllPlatforms] "Windows"]
    }

    if {[string equal -nocase $_args(-platform) "active"]} {
        set platforms [ActivePlatforms]
    }

    foreach platform $platforms {
        if {![::InstallJammer::ObjExists $platform]} {
            return -code error "\"$platform\" is not a valid platform"
        }

        $platform set $_args(-property) $_args(-value)
    }
}
