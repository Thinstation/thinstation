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

proc ::InstallJammer::theme::NewProject { arrayName } {
    upvar 1 $arrayName vars

    if {$vars(includeCustomSetup)} {
        ::InstallJammer::AddPane Install ChooseComponents \
            -parent StandardInstall -index 2
        ::InstallJammer::AddPane Install SetupType \
            -parent StandardInstall -index 2
    }

    foreach pane [GetPaneComponentList] {
        if {[$pane component] ne "SetupComplete"} { continue }

        set y 140
        if {$vars(ViewReadmeCheckbutton)} {
            set act [::InstallJammer::AddAction Install AddWidget \
                -parent $pane -title "View Readme Checkbutton"]
            $act set Type checkbutton X 185 Y $y Background #FFFFFF \
                VirtualText ViewReadme
            $act title "View Readme Checkbutton"
            ::InstallJammer::SetVirtualText en $act Text "<%ViewReadmeText%>"

            set con [::InstallJammer::AddCondition FileExistsCondition \
                -parent $act]
            $con set Filename "<%ProgramReadme%>"

            set con [::InstallJammer::AddCondition StringIsCondition \
                -parent $act]
            $con set Operator false
            $con set String "<%InstallStopped%>"
        }

        if {$vars(LaunchAppCheckbutton)} {
            incr y 20
            set act [::InstallJammer::AddAction Install AddWidget \
                -parent $pane -title "Launch Application Checkbutton"]
            $act set Type checkbutton X 185 Y $y Background #FFFFFF \
                VirtualText LaunchApplication
            $act title "Launch Application Checkbutton"
            ::InstallJammer::SetVirtualText en $act \
                Text "<%LaunchApplicationText%>"

            set con [::InstallJammer::AddCondition FileExistsCondition \
                -parent $act]
            $con set Filename "<%ProgramExecutable%>"

            set con [::InstallJammer::AddCondition StringIsCondition \
                -parent $act]
            $con set Operator false
            $con set String "<%InstallStopped%>"
        }

        if {$vars(DesktopShortcutCheckbutton)} {
            incr y 20
            set act [::InstallJammer::AddAction Install AddWidget \
                -parent $pane -title "Desktop Shortcut Checkbutton"]
            $act set Type checkbutton X 185 Y $y Background #FFFFFF \
                VirtualText CreateDesktopShortcut
            ::InstallJammer::SetVirtualText en $act \
                Text "<%CreateDesktopShortcutText%>"

            set con [::InstallJammer::AddCondition FileExistsCondition \
                -parent $act]
            $con set Filename "<%ProgramExecutable%>"

            set con [::InstallJammer::AddCondition StringIsCondition \
                -parent $act]
            $con set Operator false
            $con set String "<%InstallStopped%>"
        }

        if {$vars(QuickLaunchShortcutCheckbutton)} {
            incr y 20
            set act [::InstallJammer::AddAction Install AddWidget \
                -parent $pane -title "Quick Launch Shortcut Checkbutton"]
            $act set Type checkbutton X 185 Y $y Background #FFFFFF \
                VirtualText CreateQuickLaunchShortcut
            ::InstallJammer::SetVirtualText en $act Text \
                "<%CreateQuickLaunchShortcutText%>"

            set con [::InstallJammer::AddCondition PlatformCondition \
                -parent $act]
            $con set Operator "is"
            $con set Platform "Windows"

            set con [::InstallJammer::AddCondition FileExistsCondition \
                -parent $act]
            $con set Filename "<%ProgramExecutable%>"

            set con [::InstallJammer::AddCondition StringIsCondition \
                -parent $act]
            $con set Operator false
            $con set String "<%InstallStopped%>"
        }
    }
}
