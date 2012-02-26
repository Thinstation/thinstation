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

proc ::InstallJammer::LoadReservedVirtualText {} {
    global conf
    global info
    global widg

    variable InstallJammerVirtualText

    set virtualtext {
        {AutoFileGroups           1}
        {AutoRefreshFiles         1}
        {BuildFailureAction       1}
        {CommandLineFailureAction 1}
        {CompressionLevel         1}
        {CurrentPane              1}
        {Date                     1}
        {DateFormat               1}
        {DefaultDirectoryLocation 1}
        {DefaultLanguage          1}
        {DefaultMode              1}
        {DefaultToSystemLanguage  1}
        {ErrorsOccurred           1}
        {Ext                      1}
        {FileBeingInstalled       1}
        {FileBeingInstalledText   1}
        {FileBeingUninstalled     1}
        {FileBeingUninstalledText 1}
        {FileSize                 1}
        {GroupBeingInstalled      1}
        {GroupBeingInstalledText  1}
        {GUID                     1}
        {Home                     1}
        {Icon                     1}
        {IgnoreDirectories        1}
        {IgnoreFiles              1}
        {Image                    1}
        {InstallFinished          1}
        {InstallID                1}
        {InstallPercentComplete   1}
        {InstallSource            1}
        {InstallStarted           1}
        {InstallStopped           1}
        {Installer                1}
        {InstallerID              1}
        {Installing               1}
        {InstallPassword          1}
        {Language                 1}
        {LastGUID                 1}
        {LastIgnoreDirectories    1}
        {LastIgnoreFiles          1}
        {LastUUID                 1}
        {LicenseAccepted          1}
        {OriginalInstallDir       1}
        {Platform                 1}
        {PreserveFileAttributes   1}
        {PreserveFilePermissions  1}
        {Project                  1}
        {ProjectDir               1}
        {ProjectFile              1}
        {ProjectID                1}
        {ProjectVersion           1}
        {ScriptExt                1}
        {SelectedComponents       1}
        {SelectedFileGroups       1}
        {SilentMode               1}
        {SkipUnusedFileGroups     1}
        {SaveOnlyToplevelDirs     1}
        {SpaceAvailableText       1}
        {SpaceRequired            1}
        {SpaceRequiredText        1}
        {Status                   1}
        {SystemLanguage           1}
        {Temp                     1}
        {TempRoot                 1}
        {Theme                    1}
        {ThemeDir                 1}
        {ThemeVersion             1}
        {UninstallModes           1}
        {UninstallPercentComplete 1}
        {UserMovedBack            1}
        {UserMovedNext            1}
        {Username                 1}
        {WindowsPlatform          1}
        {WizardHeight             1}
        {WizardWidth              1}
        {WizardFirstStep          1}
        {WizardLastStep           1}
    }

    foreach var [concat $conf(InstallVars) $conf(PlatformVars)] {
        lappend virtualtext [list $var 1]
    }

    foreach code [::InstallJammer::GetLanguageCodes] {
        lappend virtualtext [list Language,$code 1]
    }

    foreach list $virtualtext {
        lassign $list var reserved type
        set InstallJammerVirtualText($var) $reserved
    }
}

proc ::InstallJammer::NewVirtualText { listbox } {
    set desc "User-Defined Virtual Text"
    set item [$listbox insert end root #auto -values [list {} {} $desc]]

    $listbox see  item  $item
    $listbox edit start $item 0
}

proc ::InstallJammer::DeleteVirtualText { listbox } {
    global conf

    variable languages

    set lang $languages($conf(VirtualTextLanguage))

    set items [list]
    foreach item [$listbox selection get] name [$listbox get -selected col 0] {
	if {![IsReservedVirtualText $name]} {
            lappend items $item
            ::msgcat::mcunset $lang $name
        }
    }

    set edit [$listbox edit editing]
    if {$edit ne ""} {
        set name [$listbox get $edit col 0]
        ::msgcar::mcunset $lang $name
        lappend items $edit
    }

    if {[llength $items]} {
        eval [list $listbox delete] $items
        Modified
    }
}

proc ::InstallJammer::LongEditVirtualText { w item } {
    global conf

    set name  [lindex [$w get item $item] 0]
    set value [$w edit editvalue]

    if {[GetPref Editor] ne ""} {
        variable languages
        set lang $languages($conf(VirtualTextLanguage))
        set cmd [list ::InstallJammer::FinishExternalEditVirtualText \
            $w $item $name $lang]
        ::InstallJammer::LaunchExternalEditor $value $cmd
        return
    }

    ClearTmpVars

    set ::TMP $value
    ::editor::new -title "Editing $name" -variable ::TMP
    if {[string index $::TMP end] eq "\n"} {
        set ::TMP [string range $::TMP 0 end-1]
    }
    $w edit editvalue $::TMP
    ClearTmpVars
    $w edit finish
}

proc ::InstallJammer::EditStartVirtualText { w item col } {
    set name [$w get value $item 0]
    if {[IsReservedVirtualText $name]} { return 0 }
    return 1
}

proc ::InstallJammer::EditFinishVirtualText { w item col } {
    global conf
    global info

    variable languages

    set lang   $languages($conf(VirtualTextLanguage))
    set name   [lindex [$w get item $item] 0]
    set oldval [$w edit value]
    set newval [$w edit editvalue]

    if {$newval ne $oldval} {
        if {$col == 0} {
            set names [$w get col 0]
            if {[lsearch -exact $names $newval] > -1
                || [::InstallJammer::IsReservedVirtualText $newval]} {
                ::InstallJammer::Error -message \
                    "A virtual text variable with that name already exists."
                $w edit cancel
                return 1
            }

            set val ""
            if {[::msgcat::mcexists $oldval $lang]} {
                set val [::msgcat::mcget $lang $oldval]
            }

            ::msgcat::mcset   $lang $newval $val
            ::msgcat::mcunset $lang $oldval
        } else {
            ::msgcat::mcset $lang $name $newval
        }

        Modified
    }

    if {[info exists conf(locations)]
        && [lsearch -glob $conf(locations) "*<%$name%>*"] > -1} {
        ::InstallJammer::RedrawFileTreeNodes
    }

    return 1
}

proc ::InstallJammer::FinishExternalEditVirtualText {w item name lang old new} {
    if {[$w edit current] eq $item} {
        $w edit editvalue $new
        set entry [$w edit entrypath]
        $entry selection range 0 end
        after idle [list focus $entry]
    } else {
        ::msgcat::mcset $lang $name $new
        if {[$w exists $item]} {
            $w itemconfigure $item -values [list $name $new]
        }
    }

    Modified
}

proc ::InstallJammer::LoadVirtualText {} {
    global conf
    global info
    global widg

    variable languages

    if {![info exists widg(VirtualTextTable)]} { return }

    set table $widg(VirtualTextTable)

    ::InstallJammer::ClearVirtualText

    ::InstallJammer::LoadReservedVirtualText

    if {$conf(VirtualTextLanguage) eq "None"} {
        foreach var [lsort [array names info]] {
            if {![::InstallJammer::IsReservedVirtualText $var]} {
                $table insert end root #auto -values [list $var $info($var)]
            }
        }
    } else {
        set lang $languages($conf(VirtualTextLanguage))
        array set msg [::msgcat::mcgetall $lang]
        foreach var [lsort [array names msg]] {
            if {[string first , $var] < 0} {
                $table insert end root #auto -values [list $var $msg($var)]
            }
        }
    }
}

proc ::InstallJammer::ClearVirtualText {} {
    global widg

    if {[info exists widg(VirtualTextTable)]} {
        $widg(VirtualTextTable) clear
    }
}

proc ::InstallJammer::UpdateReservedVirtualText {} {
    global info
    global widg

    set table $widg(VirtualTextTable)

    set row 0
    foreach item [$table items root] {
        set name [$table get value $item 0]
	if {![IsReservedVirtualText $name]} { continue }
	if {![info exists info($name)]} { continue }
        $table set $row,1 $info($name)
        incr row
    }
}

proc ::InstallJammer::IsReservedVirtualText {name} {
    variable InstallJammerVirtualText
    if {[info exists InstallJammerVirtualText($name)]} {
        return $InstallJammerVirtualText($name)
    }
    return 0
}
