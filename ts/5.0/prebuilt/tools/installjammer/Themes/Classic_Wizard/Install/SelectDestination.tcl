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
    CreateWindow.CustomBlankPane1 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 0 -weight 1

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 0 -sticky news
    $id widget set Caption -widget $base.caption

    labelframe $base.frame -bd 2 -relief ridge
    grid $base.frame -row 1 -column 0 -sticky ew -padx [list 0 5] -pady 10
    $id widget set DestinationLabel -widget $base.frame

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    Label $base.frame.label -anchor w -textvariable info(InstallDir) \
        -elide 1 -ellipsis {[...]} -elideside center
    grid  $base.frame.label -row 0 -column 0 -sticky ew
    $id widget set Destination -widget $base.frame.label

    ttk::button $base.frame.button -command \
        [list ::InstallAPI::PromptForDirectory -virtualtext InstallDir]
    grid $base.frame.button -row 0 -column 1 -padx 2
    $id widget set BrowseButton -widget $base.frame.button
}
