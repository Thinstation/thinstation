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

proc CreateWindow.SelectProgramFolder { wizard id } {
    CreateWindow.CustomBlankPane2 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 3 -weight 1
    grid columnconfigure $base 0 -weight 1

    label $base.programFolderL -anchor w -padx 0 -bd 0
    grid  $base.programFolderL -row 0 -column 0 -sticky w -padx 1
    $id widget set ProgramFolderLabel -widget $base.programFolderL

    entry $base.programFolderE -textvariable ::info(ProgramFolderName)
    grid  $base.programFolderE -row 1 -column 0 -sticky ew -padx 1

    label $base.existingFoldersL -anchor w -padx 0 -bd 0
    grid  $base.existingFoldersL -row 2 -column 0 -sticky w \
        -padx 1 -pady [list 5 0]
    $id widget set FolderListLabel -widget $base.existingFoldersL

    frame $base.frame
    grid  $base.frame -row 3 -column 0 -sticky news

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    listbox $base.frame.list -bd 2 -relief sunken -highlightthickness 0 \
        -xscrollcommand [list $base.frame.hs set] \
        -yscrollcommand [list $base.frame.vs set]
    grid $base.frame.list -row 0 -column 0 -sticky news
    $id widget set ProgramFolderListBox -widget $base.frame.list \
        -type optiontree

    ttk::scrollbar $base.frame.vs -orient vertical \
        -command [list $base.frame.list yview]
    grid $base.frame.vs -row 0 -column 1 -sticky ns

    ttk::scrollbar $base.frame.hs -orient horizontal \
        -command [list $base.frame.list xview]
    grid $base.frame.hs -row 1 -column 0 -sticky ew

    bind $base.frame.list <1> [list focus %W]
    bind $base.frame.list <Double-1> ::InstallJammer::SetProgramFolder

    ttk::checkbutton $base.allUsers -variable ::info(ProgramFolderAllUsers)
    $id widget set AllUsersCheckbutton -widget $base.allUsers
    grid  $base.allUsers -row 4 -column 0 -sticky nw -pady {2 0}

    if {![info exists ::InstallJammer]} {
        ::InstallJammer::PopulateProgramFolders $id
    }
}
