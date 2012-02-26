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

proc CreateWindow.ChooseComponents { wizard id } {
    CreateWindow.CustomBlankPane1 $wizard $id

    set base [$id widget get ClientArea]
    set tree $base.frame.tree

    grid rowconfigure    $base 2 -weight 1
    grid columnconfigure $base 0 -weight 1

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 0 -sticky ew -pady [list 0 5]
    $id widget set Caption -widget $base.caption

    Label $base.label -autowrap 1 -anchor nw -justify left
    grid  $base.label -row 1 -column 0 -sticky ew
    $id widget set ComponentLabel -widget $base.label

    frame $base.frame -bd 2 -relief sunken
    grid  $base.frame -row 2 -column 0 -sticky news

    grid rowconfigure    $base.frame 0 -weight 1
    grid columnconfigure $base.frame 0 -weight 1

    OptionTree $tree -bg #FFFFFF -relief flat -toggleselect 0 \
        -yscrollcommand [list $base.frame.vs set]
    grid $tree -row 0 -column 0 -sticky news
    $id widget set ComponentTree -widget $base.frame.tree -type tree

    ttk::scrollbar $base.frame.vs -command [list $tree yview]
    grid $base.frame.vs -row 0 -column 1 -sticky ns

    labelframe $base.descframe -bd 2 -relief ridge
    grid $base.descframe -row 3 -column 0 -sticky ew -pady 5
    $id widget set DescriptionLabel -widget $base.descframe

    grid rowconfigure    $base.descframe 0 -weight 1
    grid columnconfigure $base.descframe 0 -weight 1

    Label $base.descframe.desc -autowrap 1 -anchor nw -justify left -height 5
    grid  $base.descframe.desc -row 0 -column 0 -sticky news -padx 5 -pady 5
    $id widget set DescriptionText -widget $base.descframe.desc

    label $base.spacereq
    grid  $base.spacereq -row 4 -column 0 -sticky w -padx 5
    $id widget set SpaceRequiredLabel -widget $base.spacereq
}
