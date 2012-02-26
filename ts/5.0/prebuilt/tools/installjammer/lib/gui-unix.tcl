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

proc PROPERTIES { path args } {
    eval [list ::Properties $path -expand 1 -padx [list 0 10]] $args

    $path bindValue <3> {::InstallJammer::PostPropertiesRightClick %W %n %X %Y}

    return $path
}

proc COMBOBOX { path args } {
    eval ComboBox $path -entrybg #FFFFFF -autocomplete 1 -hottrack 1 $args
}

tile::setTheme jammer

if {[::InstallJammer::GetDesktopEnvironment] eq "KDE"
    && ![catch { tile::setTheme tileqt }]} { return }

option add *Installjammer*borderWidth        0
option add *Installjammer*highlightThickness 0

option add *Installjammer*background         [style default . -background]
option add *Installjammer*selectForeground   [style default . -selectforeground]
option add *Installjammer*selectBackground   [style default . -selectbackground]

option add *Installjammer*Listbox.background           #FFFFFF

option add *Installjammer*Entry.background             #FFFFFF
option add *Installjammer*Entry.borderWidth            1

option add *Installjammer*Text.background              #FFFFFF

option add *Installjammer*Menu.relief                  flat
option add *Installjammer*Menu.activeBackground \
    [style default . -selectbackground]
option add *Installjammer*Menu.activeForeground \
    [style default . -selectforeground]

option add *Installjammer*Table.borderWidth            1

tk_setPalette [style default . -background]
