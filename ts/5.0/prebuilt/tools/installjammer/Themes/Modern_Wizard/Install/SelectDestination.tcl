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

proc CreateWindow.SelectDestination { wizard id } {
    variable info

    CreateWindow.CustomBlankPane2 $wizard $id

    set base [$id widget get ClientArea]

    set varName [$id get VirtualText]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 0 -weight 1

    labelframe $base.frame -relief groove -bd 2
    grid $base.frame -row 0 -column 0 -sticky sew
    $id widget set DestinationLabel -widget $base.frame

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    Label $base.frame.destination -anchor nw -elide 1 -elideside center \
        -ellipsis {[...]}
    grid  $base.frame.destination -row 0 -column 0 -sticky ew -padx 5 -pady 3
    $id widget set Destination -widget $base.frame.destination
    if {$varName ne ""} {
        $id setText all Destination "<%Dir <%$varName%>%>"
    }

    Button $base.frame.browse -command \
        [list ::InstallAPI::PromptForDirectory -virtualtext $varName]
    grid $base.frame.browse -row 0 -column 1 -sticky nw -padx 5 -pady [list 0 5]
    $id widget set BrowseButton -widget $base.frame.browse
}
