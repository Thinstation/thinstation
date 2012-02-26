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
    CreateWindow.CustomBlankPane2 $wizard $id

    set base [$id widget get ClientArea]

    grid rowconfigure    $base 0 -weight 1
    grid columnconfigure $base 0 -weight 1

    set frame [frame $base.frame]
    grid $frame -row 0 -column 0 -sticky new

    grid rowconfigure    $frame 0 -weight 1
    grid columnconfigure $frame 0 -weight 1

    label $frame.userLabel -anchor w -padx 0
    grid  $frame.userLabel -row 0 -column 0 -sticky w -pady 5
    $id widget set UserNameLabel -widget $frame.userLabel

    entry $frame.userEntry -textvariable info(UserInfoName)
    grid  $frame.userEntry -row 1 -column 0 -sticky ew
    $id widget set UserNameEntry -widget $frame.userEntry -type entry

    label $frame.companyLabel -anchor w -padx 0
    grid  $frame.companyLabel -row 2 -column 0 -sticky w -pady 5
    $id widget set CompanyLabel -widget $frame.companyLabel

    entry $frame.companyEntry -textvariable info(UserInfoCompany)
    grid  $frame.companyEntry -row 3 -column 0 -sticky ew
    $id widget set CompanyEntry -widget $frame.userEntry -type entry
}
