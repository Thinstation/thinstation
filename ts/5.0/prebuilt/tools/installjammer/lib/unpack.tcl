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

if {[threaded]} {
    proc output { line } {
        thread::send $::parentThread [list ::InstallJammer::UnpackOutput $line]
    }
} else {
    proc output {string} {
        global conf

        catch { puts $conf(runlogFp) $string }
        puts stdout $string

        catch { flush $conf(runlogFp) }
        flush stdout
    }
}

proc ::InstallJammer::InstallFiles {} {
    global conf
    global info
    global files
    global groups

    set conf(unpackTotal) 0

    ::InstallJammer::CreateDir $info(InstallDir)

    foreach group $groups {
        set name [::InstallAPI::GetDisplayText -object $group]
        output [list :GROUP $name [$group directory]]

        $group install

        ## The group may not have any actual files.
        if {![info exists files($group)]} { continue }

        foreach file $files($group) {
            output [list :FILE [$file destfile] [$file version]]
            if {![$file install]} { return }
        }
    }
}

proc ::InstallJammer::IncrProgress { bytes } {
    global conf
    global info

    if {$info(TotalSize) == 0} {
	output ":PERCENT 100"
	return
    }

    incr0 conf(unpackLeft) -$bytes
    incr0 conf(unpackTotal) $bytes
    incr0 conf(unpackSoFar) $bytes

    if {$info(TotalSize) > 0} {
	set x [expr round(($conf(unpackTotal) * wide(100.0))/$info(TotalSize))]
        if {$x != $conf(lastPercent)} {
            output ":PERCENT $x"
            set conf(lastPercent) $x
        }
    }

    #if {$info(FileSize) > 0} {
	#set x [expr round( ($conf(unpackSoFar) * 100.0) / $info(FileSize) )]
	#output ":FILEPERCENT $x"
    #}
}

proc ::InstallJammer::unpack { src dest {permissions ""} } {
    global conf
    global info

    if {![PauseCheck]} { return }

    if {$conf(rollback) && [file exists $dest]} {
        output [list :ROLLBACK $dest]
        ::InstallJammer::SaveForRollback $dest
    }

    if {$permissions eq ""} { set permissions 0666 }

    # Extract the file and copy it to its location.
    set fin [open $src r]
    if {[catch {open $dest w $permissions} fout]} {
	close $fin
	return -code error $fout
    }

    set intrans  binary
    set outtrans binary
    if {[info exists conf(eol,[file extension $dest])]} {
        set trans $conf(eol,[file extension $dest])
        if {[llength $trans] == 2} {
            set intrans  [lindex $trans 0]
            set outtrans [lindex $trans 1]
        } else {
            set outtrans [lindex $trans 0]
        }
    }

    fconfigure $fin  -translation $intrans  -buffersize $conf(chunk)
    fconfigure $fout -translation $outtrans -buffersize $conf(chunk)

    set conf(unpackLeft)  $info(FileSize)
    set conf(unpackDone)  0
    set conf(unpackSoFar) 0
    set conf(unpackFin)   $fin
    set conf(unpackFout)  $fout
    set conf(lastPercent) 0

    ::InstallJammer::unpackfile $fin $fout 0

    if {!$info(InstallStopped)} {
        vwait ::conf(unpackDone)
    }

    return $dest
}

proc ::InstallJammer::unpackfile { in out bytes {error ""} } {
    global conf

    if {![PauseCheck]} {
        set error "Install Stopped"
    }

    ::InstallJammer::IncrProgress $bytes

    if {$error ne "" || $conf(unpackLeft) <= 0 || [eof $in]} {
	close $in
	close $out
	set conf(unpackDone) $conf(unpackTotal)
    } else {
        set size $conf(chunk)
        if {$size > $conf(unpackLeft)} { set size $conf(unpackLeft) }
	::fcopy $in $out -size $size -command [lrange [info level 0] 0 2]
    }
}

proc ::InstallJammer::InstallLog { string } {
    output [list :LOG $string]
}

proc ::InstallJammer::exit {} {
    global info
    global conf

    if {![threaded]} {
        ::InstallJammer::WriteDoneFile $info(Temp)

        catch { close $conf(runlogFp) }
        catch { close $conf(unpackFin)  }
        catch { close $conf(unpackFout) }

        ::exit
    }

    output ":PERCENT 100"
    output ":DONE"
}

proc ::InstallJammer::UnpackMain {} {
    global conf
    global info

    catch { wm withdraw . }

    ::InstallJammer::CommonInit

    set conf(pwd) [file dirname [info nameofexe]]

    if {![threaded]} { set info(Temp) $conf(pwd) }

    uplevel #0 [list source -encoding utf-8 [lindex $::argv end]]

    set conf(stop)        [TmpDir .stop]
    set conf(pause)       [TmpDir .pause]
    set conf(chunk)       [expr {64 * 1024}]
    set conf(lastPercent) 0

    ::InstallJammer::InitSetup
    ::InstallJammer::InitFiles
    ::InstallJammer::UpdateFiles

    if {![threaded]} {
        set conf(vfs) /installkitunpackvfs
        ::installkit::Mount $info(installer) $conf(vfs)
        set conf(runlogFp) [open [TmpDir run.log] w]

        if {$info(InstallHasSolidArchives)} {
            foreach file [glob -nocomplain -dir [TmpDir] solid.*] {
                installkit::Mount $file $conf(vfs)
            }
        }

        ::InstallJammer::MountSetupArchives
    }

    set conf(rollback) [string match "*Rollback*" $info(CancelledInstallAction)]

    if {$conf(Wow64Disabled)} {
        installkit::Windows::disableWow64FsRedirection
    }

    if {[info exists info(InstallPassword)] && $info(InstallPassword) ne ""} {
        ::InstallAPI::SetInstallPassword -password [sub $info(InstallPassword)]
    }

    ::InstallJammer::InstallFiles

    ::InstallJammer::exit
}

::InstallJammer::UnpackMain
