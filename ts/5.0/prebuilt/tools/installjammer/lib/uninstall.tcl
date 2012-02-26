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

proc ::InstallJammer::UpdateUninstallProgress {} {
    global conf
    global info

    incr0 conf(num)
    set pct [expr ($conf(num) * 100) / $conf(total)]
    if {$pct != $conf(lastPercent)} {
        set info(UninstallPercentComplete) $pct

        if {$info(GuiMode)} {
            ::InstallJammer::UpdateSelectedWidgets
            update
        } elseif {$info(ConsoleMode) && $conf(ShowConsoleProgress)} {
            ::InstallJammer::ConsoleProgressBar $pct
        }
        set conf(lastPercent) $pct
    }
}

proc ::InstallJammer::GetUninstallInfo {} {
    global conf
    global info
    global uninstall

    ## We check first to see if our .info files may be stored
    ## inside the uninstaller itself.  If not, we check for
    ## an InstallJammer registry that we can use.
    set dir   $::installkit::root
    set files [glob -nocomplain -dir $dir *.info]
    set conf(LogsInUninstaller) 1

    if {![llength $files]} {
        set conf(LogsInUninstaller) 0
        set dir   [::InstallJammer::GetInstallInfoDir]
        set files [glob -nocomplain -dir $dir *.info]
    }

    set installdir  $info(InstallDir)
    set uninstaller $info(Uninstaller)

    set conf(uninstall) $uninstaller

    set sort [list]
    foreach file $files {
        ## If there is a .dead file alongside this .info file,
        ## it's our way of marking a file as deleted.
        if {[file exists [file root $file].dead]} { continue }

        set id [file root [file tail $file]]
        ::InstallJammer::ReadPropertyFile $file tmp

        if {![info exists tmp(Uninstaller)]} {
            lappend sort [list $tmp(Date) $id]
            continue
        }

        if {[patheq $installdir $tmp(Dir)]
            || [patheq $uninstaller $tmp(Uninstaller)]} {
            lappend sort [list $tmp(Date) $id]
        }
    }

    set data ""
    foreach list [lsort -integer -index 0 $sort] {
        set id [lindex $list 1]

        lappend conf(UninstallIDs) $id

        set file [file join $dir $id.log]
        if {[file exists $file]} {
            append data [read_textfile $file]
        }
    }

    set uninstall(:DIR)      {}
    set uninstall(:FILE)     {}
    set uninstall(:REGISTRY) {}
    foreach line [split [string trim $data] \n] {
        if {[info exists done($line)]} { continue }
        set done($line) 1
        lappend uninstall([lindex $line 0]) [lrange $line 1 end]
    }
}

proc ::InstallJammer::CleanupInstallInfoDirs {} {
    global info
    global conf

    if {[string is true -strict $info(Testing)]} { return }

    if {![info exists conf(UninstallIDs)]} { return }
    if {[file exists $info(Uninstaller)]
        && ![file writable $info(Uninstaller)]} { return }
    if {[file exists $info(InstallInfoDir)]
        && ![file writable $info(InstallInfoDir)]} { return }

    debug "Cleaning up install registry..."

    set info(Status) "Cleaning up install registry..."
    ::InstallJammer::UpdateWidgets -update 1

    if {!$conf(UninstallRemoved)} {
        ## There was a problem deleting files, so the uninstall
        ## was not fully removed from the system.  We want to
        ## take any leftover bits from the uninstall and store
        ## them inside the uninstaller.

	debug "Uninstaller was not removed."

        if {$conf(LogsInUninstaller)} {
	    debug "Found logs in uninstaller.  Moving them  to new uninstaller."

            ## We already have logs saved in our uninstall, so
            ## we want to find the first .info file and use it
            ## for our future uninstalls.
            foreach id $conf(UninstallIDs) {
                set file [file join $::installkit::root $id.info]

                if {![info exists found]} {
                    ## Take the first .info file we find and use it.
                    set found $id
                    file copy -force $file [::InstallJammer::TmpDir]
                } else {
                    ## Mark all other info files as dead since we
                    ## have no real way of deleting them from the
                    ## uninstaller.
                    close [open [::InstallJammer::TmpDir $id.dead] w]
                }
            }

            set id $found
        } else {
	    debug "Storing install IDs in uninstaller."

            foreach id $conf(UninstallIDs) {
                set file [file join $info(InstallInfoDir) $id.info]
                if {[file exists $file]} {
                    file copy -force $file [::InstallJammer::TmpDir]
                    break
                }
            }
        }

        set log [::InstallJammer::TmpDir $id.log]
        set fp [open_text $log w -translation lf -encoding utf-8]

        foreach var [array names ::leftovers] {
            foreach list [lreverse $::leftovers($var)] {
                puts $fp [concat $var $list]
            }
        }

        close $fp

        if {!$conf(windows)} { ::InstallJammer::StoreLogsInUninstall }
    }

    foreach id $conf(UninstallIDs) {
        foreach ext {.log .ver .info} {
	    set file [file join $info(InstallInfoDir) $id$ext]
	    if {[file exists $file]} {
	    	debug "Deleting $file"
		file delete $file
	    }
        }
    }

    ## If this ApplicationID has no more installations, we can
    ## remove its directory entirely.
    if {[::InstallJammer::DirIsEmpty $info(InstallInfoDir)]} {
    	debug "Deleting empty registry directory $info(InstallInfoDir)."
        catch { file delete -force $info(InstallInfoDir) }
    } else {
    	debug "Will not delete non-empty directory $info(InstallInfoDir)."
    }
}

proc ::InstallJammer::InstallLog {args} {
    ## This is a dummy proc.  We don't actually want
    ## to log anything during an uninstall.
}

proc ::InstallJammer::CleanupTmpDir {} {
    global conf
    global info

    set tmpdir [::InstallJammer::TmpDir]
    if {$conf(windows)} {
        ## On Windows, we sometimes can't rename the uninstaller out
        ## of the way for it to complete.  This happens when the temp
        ## directory is on another drive from the installation directory.
        ## So, we attempted to rename the uninstaller, failed, and now
        ## we need to do cleanup AFTER the uninstall has exited.

        ## We create a tcl script that we're going to execute with a
        ## common installkit after the uninstall exits.  First thing
        ## we do is remove the temporary directory.
        set tmp [::InstallJammer::TmpDir ij[pid]cleanup.tcl]
        set fp [open $tmp w]
        puts $fp "catch {wm withdraw .}"
        puts $fp "set temp [list [::InstallJammer::TmpDir]]"

        if {[info exists conf(uninstall)]} {
            puts $fp "set uninstall [list $conf(uninstall)]"
        }

        if {[info exists conf(uninstall)] && !$conf(UninstallRemoved)} {
            ## The uninstaller was created but was not remvoed.  This
            ## happens when we were unable to delete some file because
            ## of permissions, so we need to store the remainder of our
            ## install info into the uninstaller.  We do that here in
            ## the cleanup because we have to wait until the uninstaller
            ## becomes writable.
            puts $fp {
                set pattern {*[.info|.log|.dead]}
                foreach file [glob -nocomplain -type f -dir $temp $pattern] {
                    lappend files $file
                    lappend names [file tail $file]
                }
                set i 0
                while {[incr i] < 600 && [file exists $uninstall] &&
                    [catch {installkit::addfiles $uninstall $files $names}]} {
                    after 100
                }
            }
        }

        ## Attempt to cleanup our temp directory for about a minute and
        ## then give up and move on.
        puts $fp {
            set i 0
            while {[file exists $temp] && [incr i] < 600} {
                catch {file delete -force -- $temp}
                after 100
            }
        }

        if {$conf(UninstallRemoved) && !$conf(UninstallRenamed)} {
            ## We attempted to rename the uninstaller out of the
            ## way, but it failed.  This usually happens with the
            ## uninstaller and the temp directory are on different
            ## filesystems.

            ## Add the uninstaller to our cleanup script.
            puts $fp {
                set i 0
                while {[file exists $uninstall] && [incr i] < 300} {
                    catch {file delete -force -- $uninstall}
                    after 100
                }
            }

            ## Check to see that the directory the uninstall is in is
            ## actually in our list of directories that failed to be
            ## deleted.  If it's in our error list, it means we tried
            ## to delete it, but we failed, so now we want to try again
            ## from our cleanup script.
            set dir [file normalize [file dirname $conf(uninstall)]]
            if {[lsearch -exact $info(ErrorDirs) $dir] > -1} {
                ## Now that we've determined this directory failed to
                ## be deleted, we want to do a check within the script
                ## itself to make sure that the directory we're about
                ## to delete is actually empty now.  It should be empty
                ## if the uninstall was deleted properly, and we already
                ## know that it failed to delete before, so we can be
                ## reasonably safe that this directory needs to go.

                set dirs [list $dir]

                if {[info exists conf(cleanupCompanyDir)]} {
                    ## The uninstaller left behind a company directory.
                    ## We need to try and clean that up as well.
                    lappend dirs $conf(cleanupCompanyDir)
                }
                puts $fp "set dirs [list $dirs]"
                puts $fp {
                    set i 0
                    while {[incr i] < 300} {
                        set done 0
                        foreach dir $dirs {
                            if {![file exists $dir]} {
                                incr done
                                continue
                            }

                            ## Check to see if the directory is empty.
                            set files [glob -nocomplain -dir $dir *]
                            eval lappend files \
                                [glob -nocomplain -dir $dir -type hidden *]
                            if {![llength $files]} { catch {file delete $dir} }
                        }

                        ## If we've deleted every directory in our list,
                        ## break out so we can exit.
                        if {$done == [llength $dirs]} { break }
                        after 100
                    }
                }
            }
        }
        puts $fp "exit"
        close $fp

        ## Create a common installkit and then launch our script with it.
        ## The script will run for a bit and check at intervals until our
        ## uninstaller here has exited and left everything available.
        set installkit [::InstallJammer::GetCommonInstallkit $conf(uninstall)]
        installkit::Windows::shellExecute -windowstate hidden default \
            $installkit "\"$tmp\""
    } else {
        ## Cleanup on UNIX is just removing the temporary directory and
        ## our cleanup script.  We add a sleep just to give time for the
        ## dust to settle.
        set tmp [file join $info(TempRoot) install[pid]cleanup.sh]
        set fp [open $tmp w]
        puts $fp "sleep 3"
        puts $fp "rm -rf $tmpdir $tmp"
        close $fp

        exec [auto_execok sh] $tmp &
    }
}

proc ::InstallJammer::exit { {prompt 0} } {
    global conf
    global info

    if {$info(WizardStarted) && !$info(WizardCancelled)} {
        ::InstallJammer::ExecuteActions "Finish Actions"
    } else {
        ::InstallJammer::ExecuteActions "Cancel Actions"
    }

    ::InstallJammer::CommonExit 0
    if {!$info(Debugging)} { ::InstallJammer::CleanupTmpDir }

    if {[string is integer -strict $conf(ExitCode)]} { ::exit $conf(ExitCode) }
    ::exit 0
}

proc ::InstallJammer::UninstallMain {} {
    global conf
    global info

    if {$conf(unix)} {
        if {$info(RequireRoot) && !$info(UserIsRoot)} {
            if {$info(GuiMode) && $info(PromptForRoot)} {
                set msg [sub "<%PromptForAdministratorText%>"]
                set cmd [concat [list [info nameofexecutable]] $::argv]
                ::InstallJammer::ExecAsRoot $cmd -message $msg
                ::exit 0
            }

            set title   [sub "<%RequireRootTitleText%>"]
            set message [sub "<%RequireRootUninstallText%>"]
            ::InstallJammer::Message -title $title -message $message
            ::exit 1
        }
    }

    if {$info(SilentMode)} {
        after 1000
        ::InstallJammer::ExecuteActions "Startup Actions"
        ::InstallJammer::ExecuteActions Silent
    } elseif {$info(ConsoleMode)} {
        ::InstallJammer::ExecuteActions "Startup Actions"
        ::InstallJammer::ExecuteActions Console
    } else {
        ::InstallJammer::ExecuteActions "Startup Actions"

        set info(WizardStarted) 1
        ::InstallJammer::CenterWindow $info(Wizard)
        ::InstallJammer::Wizard next
    }
}

proc ::InstallJammer::InitUninstall {} {
    global conf
    global info
    global argv

    catch { wm withdraw . }

    SourceCachedFile common.tcl

    ## Check and load the TWAPI extension.
    ::InstallJammer::LoadTwapi

    unset -nocomplain info(Temp)
    unset -nocomplain info(TempRoot)

    cd [::InstallJammer::TmpDir]

    set info(RunningInstaller)   0
    set info(RunningUninstaller) 1

    ::InstallJammer::CommonInit

    ::InstallJammer::ReadMessageCatalog messages

    set conf(mode)  "UninstallMode"
    set conf(stop)  [::InstallJammer::TmpDir .stop]
    set conf(pause) [::InstallJammer::TmpDir .pause]
    set conf(lastPercent) 0
    set conf(uninstall) [info nameofexecutable]
    set conf(UninstallRemoved) 0
    set conf(UninstallRenamed) 0

    set conf(modes) "Standard Silent"
    if {!$conf(windows)} { lappend conf(modes) "Console" }

    array set info {
        ErrorDirs                 ""
        ErrorFiles                ""
        ErrorsOccurred            0
        RunningUninstaller        1
        FileBeingUninstalled      ""
        GroupBeingUninstalled     ""
        UninstallPercentComplete  0
    }

    set info(Status) "Preparing to uninstall..."

    SafeArraySet info {
        FileBeingUninstalledText  "Removing <%FileBeingUninstalled%>"
        GroupBeingUninstalledText "Removing <%GroupBeingUninstalled%>"
    }

    ::InstallJammer::ParseCommandLineArguments $::argv

    if {$info(GuiMode)} {
        SourceCachedFile gui.tcl
        InitGui
    }

    ::InstallJammer::CommonPostInit

    ::InstallJammer::ConfigureBidiFonts
}

::InstallJammer::InitUninstall
