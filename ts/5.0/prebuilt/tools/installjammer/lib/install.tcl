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

if {[info exists ::InstallJammer]} { return }

proc ::InstallJammer::UpdateInstallInfo {} {
    global conf
    global info

    set setups    [SetupTypes children]
    set setuptype [::InstallJammer::FindObjByName $info(InstallType) $setups]

    set total      0
    set filegroups ""
    set components ""
    foreach component [$setuptype get Components] {
        if {![$component active]} { continue }

        set name [$component name]
        if {[lsearch -exact $components $name] < 0} { lappend components $name }

        set doSize 1
        set size [$component get Size]
        if {$size ne ""} {
            set doSize 0
            set total [expr {wide($total) + $size}]
        }

        foreach filegroup [$component get FileGroups] {
            if {![$filegroup active]} { continue }

            if {$doSize} {
                set fsize [$filegroup get Size]
                if {$fsize eq ""} { set fsize [$filegroup get FileSize] }

                if {[string is integer -strict $fsize]} {
                    set total [expr {wide($total) + $fsize}]
                }
            }

            set name [$filegroup name]
            if {[lsearch -exact $filegroups $name] < 0} {
                lappend filegroups $name
            }
        }
    }

    set conf(ModifySelectedComponents) 0

    set info(SpaceRequired)      $total
    set info(SelectedFileGroups) $filegroups
    set info(SelectedComponents) $components

    set conf(ModifySelectedComponents) 1

    ::InstallJammer::UpdateWidgets
}

proc ::InstallJammer::SelectComponent { paneId } {
    global info

    ::InstallJammer::UpdateInstallInfo

    set id   $paneId
    set tree [$id widget get ComponentTree]
    set text [$id widget get DescriptionText]
    set node [$tree selection get]
    set desc [::InstallJammer::GetText $node Description]

    ::InstallJammer::SetText $text $desc

    ::InstallJammer::SetVirtualText $info(Language) $id \
        [list DescriptionText $desc]
}

proc ::InstallJammer::ToggleComponent { tree id node } {
    global info

    if {![$node get Selectable]} { return }
    if {[$node get RequiredComponent]} { return }

    set type $info(InstallTypeID)

    if {[$node active]} {
        $node active 0

        foreach component [$node children recursive] {
            if {[$component get RequiredComponent]} { continue }

            $component active 0
            if {[$tree exists $component]} {
                $tree itemconfigure $component -on 0
                
                ## If this child is a radiobutton, we need to grab its
                ## group and set the whole group to an empty string so
                ## that all of the radiobuttons turn off.
                if {[$tree itemcget $component -type] eq "radiobutton"} {
                    set group [$component get ComponentGroup]
                    set ::InstallJammer::Components($tree,$group) ""
                }
            }
        }
    } else {
        $node active 1

        foreach component [$node children recursive] {
            $component active 1
            if {[$tree exists $component]} {
                $tree itemconfigure $component -on 1

                ## If this child is a radiobutton, we need to grab its
                ## group and check the Checked status of it to see if
                ## it's supposed to default on or off.
                if {[$tree itemcget $component -type] eq "radiobutton"} {
                    set group [$component get ComponentGroup]
                    if {[$component get Checked]} {
                        set ::InstallJammer::Components($tree,$group) $component
                    } else {
                        $component active 0
                    }
                }
            }
        }
    }

    if {[$tree itemcget $node -type] eq "radiobutton"} {
        ## If this is a radiobutton, we need to deactivate
        ## all of the others in this group.
        set group [$node get ComponentGroup]
        foreach comp $::InstallJammer::Components($tree,$group,others) {
            if {$comp ne $node} { $comp active 0 }
        }
    }

    ::InstallJammer::UpdateInstallInfo
}

proc ::InstallJammer::SelectSetupType { {node ""} } {
    global info

    set name $info(InstallType)
    if {$node eq "" || [set name [$node name]] ne $info(InstallType)} {
        set info(InstallType) $name
        set obj [::InstallAPI::FindObjects -type setuptype -name $name]
        if {$obj eq ""} { set obj [lindex [SetupTypes children] 0] }
        ::InstallAPI::SetActiveSetupType -setuptype $obj
    }

    if {$node ne "" && [::InstallJammer::WizardExists]} {
        set id [$info(Wizard) raise]
        if {$id eq ""} { return }

        set text [$id widget get DescriptionText]
        set list [$id widget get SetupTypeListBox]
        if {$text eq "" || $list eq ""} { return }

        ::InstallJammer::UpdateInstallInfo

        set desc [::InstallJammer::GetText $node Description]
        ::InstallJammer::SetText $text $desc
        ::InstallJammer::SetVirtualText $info(Language) $id \
            [list DescriptionText $desc]

        $list selection set $node
    }
}

proc ::InstallJammer::PopulateProgramFolders { step } {
    global conf

    set listbox [$step widget get ProgramFolderListBox]

    if {$conf(windows)} {
        set folder [list]
        foreach dir {PROGRAMS COMMON_PROGRAMS} {
            set dir [::InstallJammer::WindowsDir $dir]
            eval lappend folders [glob -nocomplain -type d -dir $dir -tails *]
        }
	eval [list $listbox insert end] [lsort -dict -unique $folders]
    }
}

proc ::InstallJammer::SetProgramFolder { {folder ""} } {
    global conf
    global info

    if {![string length $folder]} {
        set step $info(CurrentPane)
        set listbox [$step widget get ProgramFolderListBox]
        set folder  [$listbox get [$listbox curselection]]

        set list [file split $info(OriginalProgramFolderName)]
        if {[llength $list] > 1} {
            set folder [file join $folder [lindex $list end]]
        } else {
            set folder [file join $folder $info(OriginalProgramFolderName)]
        }
    }

    set info(ProgramFolderName) $folder
}

proc ::InstallJammer::ModifyProgramFolder {} {
    global conf
    global info

    set all $info(ProgramFolderAllUsers)
    if {$conf(vista)} { set all 1 }

    if {!$all} {
        set info(ProgramFolder) "<%PROGRAMS%>/<%ProgramFolderName%>"
    } else {
        set info(ProgramFolder) "<%COMMON_PROGRAMS%>/<%ProgramFolderName%>"
    }
}

proc ::InstallJammer::ModifySelectedComponents {} {
    global conf
    global info

    if {!$conf(ModifySelectedComponents)} { return }
    set conf(ModifySelectedComponents) 0

    set selected $info(SelectedComponents)
    ::InstallAPI::ComponentAPI -components all -active 0
    ::InstallAPI::ComponentAPI -components $selected -active 1

    set conf(ModifySelectedComponents) 1
}

proc ::InstallJammer::ScrollLicenseTextBox { force args } {
    global info

    eval $args

    if {!$force} { return }

    set w   [lindex $args 0]
    lassign [$w yview] y0 y1

    if {$y1 == 1} {
        $info(Wizard) itemconfigure next -state normal
    } else {
        $info(Wizard) itemconfigure next -state disabled
    }
}

proc ::InstallJammer::exit { {prompt 0} } {
    global conf
    global info

    if {$prompt} {
        ::InstallJammer::PauseInstall

        set title   [sub "<%ExitTitle%>"]
        set message [sub "<%ExitText%>"]
        set ans [MessageBox -type yesno -default no \
            -parent [::InstallJammer::TransientParent] \
            -title $title -message $message]

        if {$ans eq "no"} {
            ::InstallJammer::ContinueInstall
            return
        }

        set id [$info(Wizard) raise]
        
        if {$id ne ""} {
            set when "After Pane is Cancelled"

            ::InstallJammer::ExecuteActions $id -when $when

            if {![$id checkConditions $when]} { return }
        }

        set info(WizardCancelled) 1
    }

    if {$info(Installing)} {
        ## If we're still installing, we need to stop the install.
	::InstallJammer::StopInstall

	## Give unpack a chance to die before exiting ourselves.
	vwait ::info(Installing)

        if {[string match "*Continue*" $info(CancelledInstallAction)]} {
            ## FIXME:  Need to finish Continue option for a cancelled install.
        }
    }

    if {$info(InstallStarted)
        && $info(InstallStopped)
        && $info(CleanupCancelledInstall)} {
	## We only want to try to cleanup if we actually started the
	## unpack process at some point in the install.  If not, we
	## haven't really done any work to cleanup.
        ::InstallJammer::CleanupCancelledInstall
    }

    if {!$info(WizardCancelled) && ($info(WizardStarted) || !$info(GuiMode))} {
        ::InstallJammer::ExecuteActions "Finish Actions"

        if {!$info(InstallStopped)} {
            ## Create the install logs and version information.
            ::InstallJammer::StoreVersionInfo
            ::InstallJammer::CreateInstallLog
            ::InstallJammer::CreateApplicationInstallLog

            if {!$info(InstallRegistryInfo)} {
                ::InstallJammer::StoreLogsInUninstall
            }
        }

        if {$info(EnableResponseFiles) && [::InstallAPI::CommandLineAPI \
            -do check -option save-response-file]} {
            ::InstallAPI::ResponseFileAPI -do write \
                -file $info(SaveResponseFile)
        }
    } else {
        ::InstallJammer::ExecuteActions "Cancel Actions"
    }

    ::InstallJammer::CheckAndUpdateInstallRegistry

    ::InstallJammer::CommonExit

    if {[string is integer -strict $conf(ExitCode)]} { ::exit $conf(ExitCode) }
    ::exit $info(WizardCancelled)
}

proc ::InstallJammer::UnpackOutput { line } {
    global conf
    global info

    if {$::verbose >= 2} {
        debug "Unpack Output: $line"
    }

    if {[catch {lindex $line 0} command]} { set command :ERROR }

    switch -- $command {
        ":DONE" {
	    ::InstallJammer::UnpackOutput [list :PERCENT 100]

            set info(FileBeingInstalled)  ""
            set info(GroupBeingInstalled) ""

            set info(Status) "File installation complete..."

            if {![threaded]} { catch { close $conf(UnpackFp) } }
            set info(Installing) 0
        }

        ":LOG" {
            ::InstallJammer::InstallLog [lindex $line 1]
        }

	":GROUP" {
	    set info(GroupBeingInstalled) [lindex $line 1]
            ::InstallJammer::UpdateWidgets -buttons 0 -updateidletasks 1

            if {!$info(GuiMode) && !$info(SilentMode)} {
                set cols [expr {$conf(ConsoleWidth) - 2}]
                ::InstallJammer::ConsoleClearLastLine $cols
                echo <%Status%> 1
            }
	}

	":DIR" {
	    set dir   [lindex $line 1]
	    set perms [lindex $line 2]
	    lappend conf(directoryPermissions) $dir $perms
	}

        ":DISC" {
            set info(RequiredDiscName) [lindex $line 1]
            ::InstallJammer::MessageBox -message [sub <%InsertDiscText%>]
            update
            ::InstallJammer::ContinueInstall
        }

	":FILE" {
            set file [lindex $line 1]
            set ::conf(TMPFILE) $file
	    set info(FileBeingInstalled) $file
            ::InstallJammer::SetVersionInfo $file [lindex $line 2]
            if {$conf(UpdateFileText)} {
                ::InstallJammer::UpdateWidgets -buttons 0 -updateidletasks 1
            }

            if {$::verbose == 1} {
                debug "Installing $file..."
            }
	}

	":PERCENT" {
	    set percent [lindex $line 1]
            set info(InstallPercentComplete) $percent
            if {$info(InstallPercentComplete) != $conf(LastPercent)} {
		if {$info(GuiMode)} {
		    ::InstallJammer::UpdateWidgets -buttons 0 -updateidletasks 1
		} elseif {$info(ConsoleMode) && $conf(ShowConsoleProgress)} {
		    ::InstallJammer::ConsoleProgressBar $percent
		}
		set conf(LastPercent) $percent
            }
	}

        ":ROLLBACK" {
            lappend conf(rollbackFiles) [lindex $line 1]
        }

	":FILEPERCENT" {
            set info(FilePercentComplete) [lindex $line 1]
            if {$conf(UpdateFilePercent)} {
                ::InstallJammer::UpdateWidgets -buttons 0 -updateidletasks 1
            }
	}

	default {
            debug "Unpack Error: $line"
            append info(InstallErrors) $line\n
	}
    }
}

proc ::InstallJammer::ReadUnpack { id } {
    global conf

    if {[gets $conf(UnpackFp) line] < 0} { set line :DONE }
    ::InstallJammer::UnpackOutput $line
}

proc ::InstallJammer::BuildUnpackInfo { groupList groupArray } {
    global conf
    global info
    global versions

    upvar 1 $groupArray groups

    ::InstallJammer::ReadVersionInfo

    set unpack [TmpDir unpack.ini]

    set fp [open_text $unpack w -translation lf -encoding utf-8]

    ## Some pieces of the internal configuration need to be
    ## sent to the unpack process.
    set confArray [array get conf eol,*]
    eval lappend confArray [array get conf Wow64Disabled]

    puts $fp "namespace eval ::InstallJammer {}"
    puts $fp "set info(installer) [list [info nameofexecutable]]"
    puts $fp "array set conf [list $confArray]"
    puts $fp "array set info [list [array get info]]"
    puts $fp "set groups [list $groupList]"
    puts $fp "array set files [list [array get groups]]"
    puts $fp ""
    puts $fp "array set versions [list [array get versions]]"

    puts -nonewline $fp "array set ::InstallJammer::Properties "
    puts $fp "[list [array get ::InstallJammer::Properties]]"

    puts $fp "proc ::InstallJammer::UpdateFiles {} {"
    if {[info exists conf(newFiles)]} {
        foreach obj $conf(newFiles) {
            puts $fp "File $obj [$obj serialize]"
        }
        unset conf(newFiles)
    }
    if {[info exists conf(modifiedFiles)]} {
        foreach obj $conf(modifiedFiles) {
            puts $fp "$obj configure [$obj serialize]"
        }
        unset conf(modifiedFiles)
    }
    puts $fp "}"

    puts $fp $::InstallJammer::files(files.tcl)
    puts $fp $::InstallJammer::files(setup.tcl)
    puts $fp $::InstallJammer::files(components.tcl)

    close $fp

    return $unpack
}

proc ::InstallJammer::BuildUnpack {} {
    global info
    global conf

    if {[info exists conf(UnpackBin)]} { return $conf(UnpackBin) }

    set unpack [TmpDir unpack.tcl]
    set conf(UnpackScript) $unpack

    set fp [open_text $unpack w -translation lf -encoding utf-8]
    puts $fp $::InstallJammer::files(common.tcl)
    puts $fp $::InstallJammer::files(unpack.tcl)
    close $fp

    return $unpack
}

## CleanupCancelledInstall
##
## Read the log and cleanup anything that has already been installed.
## This proc is called if the user cancels an installation half-way
## through, and the builder has opted to clean up cancelled installs.
proc ::InstallJammer::CleanupCancelledInstall {} {
    global conf
    global info

    if {$conf(TMPFILE) eq "" && ![llength $conf(LOG)]} { return }

    set info(Status) "Cleaning up install..."

    set dirs    {}
    set files   {}
    set regkeys {}
    foreach line [lreverse $conf(LOG)] {
	set type [lindex $line 0]
	set args [lrange $line 1 end]
	switch -- $type {
	    ":FILE"	{
                lappend files [lindex $args 0]
            }

	    ":DIR"	{
                lappend dirs $args
            }

	    ":REGISTRY"	{
                lappend regkeys $args
            }
	}
    }

    foreach file $files {
        set roll [::InstallJammer::RollbackName $file]
        if {[file exists $roll]} {
            if {$::verbose == 1} {
                debug "Rolling back file $file"
            }
            file rename -force $roll $file
        } else {
            if {$::verbose == 1} {
                debug "Cleaning up file $file"
            }
            ::InstallJammer::UninstallFile $file
        }
    }

    if {[lsearch -exact $files $::conf(TMPFILE)] < 0} {
        ::InstallJammer::UninstallFile $::conf(TMPFILE)
    }

    foreach dir $dirs {
        if {$::verbose == 1} {
            debug "Cleaning up directory $dir"
        }
        eval ::InstallJammer::UninstallDirectory $dir
    }

    foreach regkey $regkeys {
        if {$::verbose == 1} {
            debug "Cleaning up registry key $regkey"
        }
        eval ::InstallJammer::UninstallRegistryKey $regkey
    }
}

proc ::InstallJammer::CreateApplicationInstallLog {} {
    global conf
    global info

    if {$info(InstallRegistryInfo)} {
        set file [::InstallJammer::InstallInfoDir $info(InstallID).info]
    } else {
        set file [::InstallJammer::TmpDir $info(InstallID).info]
    }

    set fp [open_text $file w -translation lf -encoding utf-8]

    set    string ""
    append string "ApplicationID: <%ApplicationID%>\n"
    append string "Dir:           <%InstallDir%>\n"
    append string "Date:          [clock seconds]\n"
    append string "User:          <%Username%>\n"
    append string "RealUser:      <%RealUsername%>\n"
    append string "Version:       <%InstallVersion%>\n"
    append string "VersionString: <%Version%>\n"
    append string "Source:        <%InstallSource%>\n"
    append string "Executable:    <%Installer%>\n"
    append string "Uninstaller:   <%Uninstaller%>\n"
    append string "UpgradeID:     <%UpgradeApplicationID%>\n"

    puts $fp [::InstallJammer::SubstText $string]

    if {[info exists conf(APPLOG)]} {
        foreach {var val} $conf(APPLOG) {
            puts $fp "$var: $val"
        }
    }

    close $fp
}

proc ::InstallJammer::CreateInstallLog { {file ""} } {
    global conf
    global info

    if {$file eq ""} {
        if {$info(InstallRegistryInfo)} {
            set file [::InstallJammer::InstallInfoDir $info(InstallID).log]
        } else {
            set file [::InstallJammer::TmpDir $info(InstallID).log]
        }
    }

    if {[catch { open_text $file w -translation lf -encoding utf-8 } fp]} {
        return
    }

    ::InstallJammer::LogFile $file

    set checkRemove 0
    if {[info exists conf(RemoveFromUninstall)]} {
        set checkRemove 1
        set pattern [join $conf(RemoveFromUninstall) |]
    }

    foreach line $conf(LOG) {
        if {![info exists done($line)]} {
            set done($line) 1

            if {$checkRemove} {
                set type [lindex $line 0]
                set dir  [lindex $line 1]
                if {($type eq ":DIR" || $type eq ":FILE")
                    && [regexp $pattern $dir]} { continue }
            }

            puts $fp $line
        }
    }
    close $fp
}

proc ::InstallJammer::InstallLog {string} {
    lappend ::conf(LOG) $string
}

proc ::InstallJammer::LogRegistry { args } {
    ::InstallJammer::InstallLog [concat :REGISTRY $args]
}

proc ::InstallJammer::CheckAndUpdateInstallRegistry {} {
    global conf
    global info

    if {[info exists conf(checkAndUpdateRegistry)]} { return }
    set conf(checkAndUpdateRegistry) 1

    ## Setup the directories we need.
    set dir [::InstallJammer::GetInstallInfoDir]

    ## We need to check for older versions of InstallJammer
    ## that stored registry information by the ApplicationID
    ## instead of the InstallID.  If we find one, we're going
    ## to update it to the new method before proceeding.
    if {[file exists [file join $dir install.log]]} {
        ## This is an old registry.  We need to update it.

        ## Create a new InstallID for this old install.
        set newid [::InstallJammer::uuid]

        set file [file join $dir .installinfo]
        if {[file exists $file]} {
            file delete $file
        }

        set file [file join $dir install.log]
        if {[file exists $file]} {
            file rename -force $file [file join $dir $newid.log]

            set file [file join $dir $newid.log]
            foreach x [split [string trim [read_textfile $file]] \n] {
                if {[lindex $x 0] eq ":DIR"} {
                    set installdir [lindex $x 1]

                    set info [file join $dir $newid.info]
                    set fp [open_text $info w -translation lf -encoding utf-8]
                    puts  $fp "ApplicationID: $info(ApplicationID)"
                    puts  $fp "Dir:           $installdir"
                    puts  $fp "Date:          [file mtime $file]"
                    close $fp
                    break
                }
            }
        }
    }
}

proc ::InstallJammer::ReadPreviousInstall {} {
    global conf
    global info

    variable ::InstallJammer::PreviousInstallInfo

    ::InstallJammer::CheckAndUpdateInstallRegistry

    ::InstallAPI::ReadInstallInfo -prefix PreviousInstall \
        -array PreviousInstallInfo

    foreach {var val} [array get PreviousInstallInfo PreviousInstall*] {
        set info($var) $val
        unset PreviousInstallInfo($var)
    }
}

proc ::InstallJammer::StoreVersionInfo { {dir ""} {file ""} } {
    global conf
    global info
    global versions

    if {!$info(InstallVersionInfo)} { return }

    if {$info(InstallRegistryInfo)} {
        if {$dir eq ""} { set dir [::InstallJammer::InstallInfoDir] }
        if {$file eq ""} { set file $info(InstallID).ver }
    } else {
        if {$dir eq ""} { set dir $info(InstallDir) }
        if {$file eq ""} { set file .installinfo }
    }

    set file [file join $dir $file]

    if {[file exists $file]} {
        catch { file delete -force $file }
    }

    debug "Storing version file $file"
    if {[catch {open_text $file w -translation lf -encoding utf-8} fp]} {
        return
    }

    ::InstallJammer::LogFile $file

    foreach filename [array names versions] {
	puts $fp "Ver [list $filename] $versions($filename)"
    }

    catch {close $fp}

    if {![file exists $file] || [file size $file] == 0} {
        debug "Version file failed to create."
    } else {
        debug "Version file created successfully."
    }

    if {$conf(windows)} {
        file attributes $file -hidden 1
    }
}

proc ::InstallJammer::ReadVersionInfo {} {
    global info
    global versions

    ## Look for a file in our install info dir first.
    set dir  [::InstallJammer::GetInstallInfoDir]
    set file [file join $dir $info(InstallID).ver]
    if {![file exists $file]} {
        ## We didn't find one.  See if we can find one in
        ## the installation directory.
        set file [file join $info(InstallDir) .installinfo]
    }

    if {[file exists $file]} {
        set fp [open_text $file]

        while {[gets $fp line] != -1} {
            switch -- [lindex $line 0] {
                "Ver" {
                    lassign $line cmd file ver
                    set versions($file) $ver
                }
            }
        }

        close $fp
    }
}

proc ::InstallJammer::UnpackSolidProgress { in out showGui bytes {error ""} } {
    global conf
    global info

    set top .__solidExtract

    if {$error ne "" || [eof $in]} {
        set conf(solidUnpackDone) 1
    } else {
        set conf(solidDone) [expr {$conf(solidDone) + double($bytes)}]
        if {$conf(solidTotal) > 0} {
            set conf(solidLeft) [expr {wide($conf(solidTotal))
                                       - $conf(solidDone)}]
            set x [expr {round(($conf(solidDone) * wide(100))
                         / $conf(solidTotal))}]
            if {$showGui} {
                $top.p configure -value $x
                wm title $top "$x% Extracting"
                update
            } else {
                set info(InstallPercentComplete) $x
                ::InstallJammer::UpdateWidgets -update 1
            }
        }

        if {$conf(solidLeft) == 0} {
            set conf(solidUnpackDone) 1
            return
        }

        set size [expr {64 * 1024}]
        if {$size > $conf(solidLeft)} {
            set size [expr {round($conf(solidLeft))}]
        }

        ::fcopy $in $out -size $size -command [lrange [info level 0] 0 3]
    }
}

proc ::InstallJammer::UnpackSolidArchives { {showGui 0} } {
    global conf
    global info

    if {!$info(InstallHasSolidArchives) || $info(SolidArchivesExtracted)} {
        return
    }

    set files [list]
    set conf(solidDone)  0
    set conf(solidTotal) 0
    foreach file [glob -nocomplain -dir $conf(vfs) solid.*] {
        lappend files $file
        set conf(solidTotal) [expr {wide($conf(solidTotal))
                                    + [file size $file]}]
    }

    if {![llength $files]} { return }

    if {!$info(GuiMode)} { set showGui 0 }

    if {$showGui} {
        set top .__solidExtract
        toplevel    $top
        wm withdraw $top
        wm title    $top "0% Extracting"
        wm geometry $top 270x60
        wm protocol $top WM_DELETE_WINDOW {#}

        ttk::progressbar $top.p
        pack $top.p -expand 1 -fill both -padx 10 -pady 20

        BWidget::place $top 270 60 center

        wm deiconify $top
        update

        grab $top
    } else {
        set info(Status) "Extracting setup files..."
    }

    if {!$info(GuiMode) && !$info(SilentMode)} {
        puts  stdout [::InstallJammer::SubstText $info(Status)]
        flush stdout
    }

    foreach file $files {
        set temp [TmpDir [file tail $file]]

        set ifp [open $file]
        fconfigure $ifp -translation binary

        set ofp [open $temp w]
        fconfigure $ofp -translation binary

        ::InstallJammer::UnpackSolidProgress $ifp $ofp $showGui 0

        vwait ::conf(solidUnpackDone)

        close $ifp
        close $ofp

        installkit::Mount $temp $conf(vfs)
    }

    if {$showGui} {
        grab release $top
        destroy $top
    }

    set info(SolidArchivesExtracted) 1
}

proc ::InstallJammer::AskUserLanguage {} {
    global conf
    global info

    set list [::InstallJammer::GetLanguages]

    if {[llength $list] < 1} { return }

    set top .__askLanguage

    Dialog $top -title "Language Selection" -default ok -cancel 1
    wm resizable $top 0 0
    wm protocol  $top WM_DELETE_WINDOW {::InstallJammer::exit 1}

    set f [$top getframe]

    ttk::label $f.l -text [::InstallJammer::SubstText <%SelectLanguageText%>]
    pack $f.l -pady 10

    ttk::combobox $f.cb -state readonly \
        -textvariable ::conf(Language) -values $list
    pack $f.cb

    $top add -name ok     -text "OK"
    $top add -name cancel -text "Cancel" -command {::InstallJammer::exit 1}

    foreach code [::msgcat::mcpreferences] {
        set lang [::InstallJammer::GetLanguage $code]
        if {$lang ne ""} {
            set conf(Language) $lang
            break
        }
    }

    $top setfocus 0
    if {[$top draw] == 1} {
        set info(WizardCancelled) 1
        ::InstallJammer::exit
    }

    ::msgcat::mclocale [::InstallJammer::GetLanguageCode $conf(Language)]
    set info(Language) [::msgcat::mclocale]
}

proc ::InstallJammer::InstallMain {} {
    global conf
    global info

    if {$info(SilentMode)} {
        ::InstallJammer::ExecuteActions "Startup Actions"
        ::InstallJammer::ExecuteActions Silent
    } elseif {$info(ConsoleMode)} {
        ::InstallJammer::ConfigureBidiFonts
        ::InstallJammer::ExecuteActions "Startup Actions"
        ::InstallJammer::ExecuteActions Console
    } else {
        if {$info(AllowLanguageSelection)} {
            ::InstallJammer::AskUserLanguage
        }

        ::InstallJammer::ConfigureBidiFonts

        ::InstallJammer::ExecuteActions "Startup Actions"

        set info(WizardStarted) 1
        ::InstallJammer::CenterWindow $info(Wizard)
        raise $info(Wizard)
        ::InstallJammer::Wizard next
    }
}

proc ::InstallJammer::InitInstall {} {
    global conf
    global info

    catch { wm withdraw . }

    ## Check and load the TWAPI extension.
    ::InstallJammer::LoadTwapi

    SourceCachedFile gui.tcl
    SourceCachedFile setup.tcl
    SourceCachedFile files.tcl
    SourceCachedFile components.tcl

    set info(InstallID) [::InstallJammer::uuid]

    set info(RunningInstaller)   1
    set info(RunningUninstaller) 0

    ::InstallJammer::CommonInit

    array set info {
        Installing             0
        InstallStarted         0
        InstallStopped         0
        InstallFinished        0

        LicenseAccepted         No
        FileBeingInstalled      ""
        GroupBeingInstalled     ""
        InstallPercentComplete  0

        PreviousInstallDir      ""
        PreviousInstallCount    0
        PreviousInstallExists   0

        RunningInstaller        1

        SolidArchivesExtracted  0
        InstallHasSolidArchives 0
    }

    set conf(LOG)      {}
    set conf(TMPFILE)  ""
    set conf(mode)     "InstallMode"
    set conf(rollback) [string match "*Rollback*" $info(CancelledInstallAction)]
    set conf(rollbackFiles) {}

    set conf(modes) "Standard Default Silent"
    if {!$conf(windows)} { lappend conf(modes) "Console" }

    set info(Installer)     $conf(exe)
    set info(InstallSource) [file dirname $conf(exe)]

    if {[llength [glob -nocomplain -dir $conf(vfs) solid.*]]} {
        set info(InstallHasSolidArchives) 1
    }

    SafeSet info(UpgradeInstall) \
        [expr {[string trim $info(UpgradeApplicationID)] ne ""}]

    ::InstallJammer::ReadMessageCatalog messages

    ::InstallJammer::ParseCommandLineArguments $::argv

    if {$info(GuiMode)} { ::InstallJammer::InitializeGui }

    ::InstallJammer::CommonPostInit

    ::InstallJammer::MountSetupArchives

    if {$info(ExtractSolidArchivesOnStartup)} {
        ::InstallJammer::UnpackSolidArchives 1
    }

    if {$conf(windows)} {
        ## Commented out for now.
        #if {$info(RequireAdministrator) && !$conf(vista)} {
            #set admin [::twapi::map_account_to_name S-1-5-32-544]
            #set members [::twapi::get_local_group_members $admin]
            #if {[lsearch -glob $members "*\\$info(Username)"] < 0} {
                #::InstallJammer::Message -title "Install Error" -message \
                    #[sub "<%RequireAdministratorText%>"]
                #::exit 1
            #}
        #}
    } elseif {$conf(unix)} {
        if {$info(RequireRoot) && !$info(UserIsRoot)} {
            if {$info(GuiMode) && $info(PromptForRoot)} {
                set msg [sub "<%PromptForAdministratorText%>"]
                set cmd [concat [list [info nameofexecutable]] $::argv]
                ::InstallJammer::ExecAsRoot $cmd -message $msg
                ::exit 0
            }

            set title   [sub "<%RequireRootTitleText%>"]
            set message [sub "<%RequireRootText%>"]
            ::InstallJammer::Message -title $title -message $message
            ::exit 1
        }

        ## If we have a root install dir, and the user is root,
        ## set the install dir to the root install dir.
        variable ::InstallJammer::VirtualTextSetByCommandLine
        if {$info(RootInstallDir) ne "" && $info(UserIsRoot)
            && ![info exists VirtualTextSetByCommandLine(InstallDir)]} {
            set info(InstallDir) $info(RootInstallDir)
        }
    }

    ::InstallJammer::InitSetup
    ::InstallJammer::InitFiles

    ## Setup the default user information under Windows
    if {$conf(windows)} {
	set key {HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion}
	catch {
            set info(UserInfoName)    [registry get $key RegisteredOwner]
            set info(UserInfoCompany) [registry get $key RegisteredOrganization]
        }
    }

    if {$conf(windows)} {
        set dir [::InstallJammer::WindowsDir PROGRAM_FILES]
        set info(InstallDrive) [string range $dir 0 1]
    }

    ## Normalize some of the install variables.
    foreach var [list InstallDir ProgramFolderName] {
        set info($var) [::InstallJammer::SubstText <%$var%>]
        set info(Original$var) $info($var)
    }

    ## Call a proc if the all users value changes.
    ::InstallAPI::SetVirtualText -virtualtext ProgramFolderAllUsers \
    	-command ::InstallJammer::ModifyProgramFolder

    ::InstallAPI::SetVirtualText -virtualtext SelectedComponents \
        -command ::InstallJammer::ModifySelectedComponents

    if {$info(UpgradeInstall)} {
        ::InstallJammer::ReadPreviousInstall
        if {[info exists info(PreviousInstallUninstaller)]} {
            set info(Uninstaller) $info(PreviousInstallUninstaller)
        }
    }

    ::InstallJammer::SelectSetupType
}

::InstallJammer::InitInstall
