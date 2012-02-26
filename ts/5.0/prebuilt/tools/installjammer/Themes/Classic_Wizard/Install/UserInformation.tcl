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

proc CreateWindow.UserInformation { wizard id } {
    CreateWindow.CustomBlankPane1 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 1 -weight 1
    grid columnconfigure $base 0 -weight 1

    Label $base.caption -autowrap 1 -anchor nw -justify left
    grid  $base.caption -row 0 -column 0 -sticky new -pady 15
    $id widget set Caption -widget $base.caption

    frame $base.frame
    grid  $base.frame -row 1 -column 0 -sticky new -padx [list 0 15] -pady 20

    grid columnconfigure $base.frame 1 -weight 1

    label $base.frame.nameL
    grid  $base.frame.nameL -row 0 -column 0 -sticky w -padx 5 -pady 5
    $id widget set NameLabel -widget $base.frame.nameL

    entry $base.frame.nameE -textvariable info(UserInfoName)
    grid  $base.frame.nameE -row 0 -column 1 -sticky ew -pady 5

    label $base.frame.companyL
    grid  $base.frame.companyL -row 1 -column 0 -sticky w -padx 5 -pady 5
    $id widget set CompanyLabel -widget $base.frame.companyL

    entry $base.frame.companyE -textvariable info(UserInfoCompany)
    grid  $base.frame.companyE -row 1 -column 1 -sticky ew

    focus $base.frame.nameE
}
