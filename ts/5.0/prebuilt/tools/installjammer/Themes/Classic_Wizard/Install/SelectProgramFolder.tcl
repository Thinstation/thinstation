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
    CreateWindow.CustomBlankPane1 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 4 -weight 1
    grid columnconfigure $base 0 -weight 1

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 0 -sticky new -pady [list 0 5]
    $id widget set Caption -widget $base.caption

    label $base.label
    grid  $base.label -row 1 -column 0 -sticky w -pady [list 0 2]
    $id widget set ProgramFolderLabel -widget $base.label

    entry $base.entry -textvariable ::info(ProgramFolderName)
    grid  $base.entry -row 2 -column 0 -sticky ew

    label $base.label2
    grid  $base.label2 -row 3 -column 0 -sticky w -pady [list 10 0]
    $id widget set FolderListLabel -widget $base.label2

    frame $base.frame
    grid  $base.frame -row 4 -column 0 -sticky news -pady {2 0}

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    listbox $base.frame.list \
        -bg #FFFFFF -highlightthickness 0 -selectmode single \
        -xscrollcommand "$base.frame.hs set" \
        -yscrollcommand "$base.frame.vs set"
    grid $base.frame.list -row 0 -column 0 -sticky news
    $id widget set ProgramFolderListBox -widget $base.frame.list \
        -type optiontree

    ttk::scrollbar $base.frame.vs -command "$base.frame.list yview"
    grid $base.frame.vs -row 0 -column 1 -sticky ns

    ttk::scrollbar $base.frame.hs -command "$base.frame.list xview" \
        -orient horizontal
    grid $base.frame.hs -row 1 -column 0 -stick ew

    bind $base.frame.list <1> [list focus %W]
    bind $base.frame.list <Double-1> ::InstallJammer::SetProgramFolder

    ttk::checkbutton $base.allUsers -variable ::info(ProgramFolderAllUsers)
    grid $base.allUsers -row 5 -column 0 -sticky nw -pady {2 10}
    $id widget set AllUsersCheckbutton -widget $base.allUsers

    if {![info exists ::InstallJammer]} {
        ::InstallJammer::PopulateProgramFolders $id
    }
}
