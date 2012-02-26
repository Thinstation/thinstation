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

namespace eval ::InstallAPI {}
namespace eval ::InstallJammer {}
namespace eval ::InstallJammer::subst {}

rename ::source ::tcl_source
proc source {args} {
    if {[llength $args] == 1} {
        uplevel 1 [list ::tcl_source [lindex $args 0]]
    } elseif {[llength $args] == 3 && [lindex $args 0] eq "-encoding"} {
        set enc [encoding system]
        encoding system [lindex $args 1]
        uplevel 1 [list ::tcl_source [lindex $args 2]]
        encoding system $enc
    } else {
        return -code error \
            {wrong # args: should be "source ?-encoding encodingName? fileName"}
    }
}

proc lempty { list } {
    if {[catch {expr [llength $list] == 0} ret]} { return 0 }
    return $ret
}

proc lassign { list args } {
    foreach elem $list varName $args {
    	upvar 1 $varName var
	set var $elem
    }
}

proc lremove { list args } {
    foreach arg $args {
	set x [lsearch -exact $list $arg]
        if {$x > -1} { set list [lreplace $list $x $x] }
    }
    return $list
}

proc lreverse { list } {
    set new [list]
    set len [llength $list]
    for {set i [expr $len - 1]} {$i >= 0} {incr i -1} {
	lappend new [lindex $list $i]
    }
    return $new
}

proc lassign_array {list arrayName args} {
    upvar 1 $arrayName array
    foreach elem $list var $args {
	set array($var) $elem
    }
}

proc incr0 { varName {n 1} } {
    upvar 1 $varName var
    if {![info exists var]} { set var 0 }
    set var [expr {wide($var) + $n}]
}

proc iincr { varName {n 1} } {
    upvar 1 $varName var
    if {![info exists var]} { set var 0 }
    set var [expr {$var + $n}]
}

proc patheq {path1 path2} {
    global conf

    set path1 [::InstallJammer::Normalize $path1]
    set path2 [::InstallJammer::Normalize $path2]
    if {$conf(windows)} { return [string equal -nocase $path1 $path2] }
    return [string equal $path1 $path2]
}

proc recursive_glob {dir pattern} {
    set files [glob -nocomplain -type f -dir $dir $pattern]
    foreach dir [glob -nocomplain -type d -dir $dir *] {
        eval lappend files [recursive_glob $dir $pattern]
    }
    return $files
}

proc noop {args} {}

proc open_text {file {mode "r"} args} {
    set fp [open $file $mode]
    eval fconfigure $fp $args

    if {![catch {fileevent $fp readable}]} {
        ## Look for an options: line followed by a blank line.
        gets $fp line
        if {[string match "# options: -*" $line] && [gets $fp] eq ""} {
            eval fconfigure $fp [lrange $line 2 end]
        } else {
            seek $fp 0 start
        }
    }

    if {[llength $args] && ![catch {fileevent $fp writable}]} {
        puts $fp "# options: $args"
        puts $fp ""
    }

    return $fp
}

proc read_file { file args } {
    set fp [open $file]
    eval [list fconfigure $fp] $args
    set x [read $fp]
    close $fp
    return $x
}

proc read_textfile {file args} {
    set fp [eval open_text [list $file] $args]
    set x [read $fp]
    close $fp
    return $x
}

proc verbose {} {
    if {[info exists ::verbose]} { return $::verbose }
    return 0
}

proc debugging { {value ""} {level ""} {file ""} } {
    if {$value eq "state"} {
        if {$::debug || $::info(Debugging)} { return 1 }
        return 0
    } elseif {[string is true -strict $value]} {
        if {$level eq "" || $level eq "console"} {
            set ::debug 1
        } elseif {$level eq "file"} {
            set ::info(Debugging) 1
            if {$file eq ""} {
                set file [::InstallJammer::TmpDir debug.log]
            }
            if {[info exists ::debugfp]} {
                catch { close $::debugfp }
                set ::debugfp ""
            }
            set ::info(DebugLog) $file
            set ::debugfp [open $file w]
        } else {
            return -code error "bad debugging option \"$level\":\
                should be console or file"
        }
    } elseif {[string is false -strict $value]} {
        if {$level eq ""} {
            set ::debug 0
            set ::info(Debugging) 0
            if {[info exists ::debugfp]} {
                catch { close $::debugfp }
                set ::debugfp ""
            }
        } elseif {$level eq "console"} {
            set ::debug 0
        } elseif {$level eq "file"} {
            set ::info(Debugging) 0
            if {[info exists ::debugfp]} {
                catch { close $::debugfp }
                set ::debugfp ""
            }
        }
    } elseif {$value eq "level"} {
        if {$level eq ""} {
            if {!$::debug} { return 0 }
            return [expr {$::verbose + 1}]
        } else {
            if {$level < 0 || $level > 3} {
                return -code error "invalid debug level \"$level\":\
                    should be 0, 1, 2 or 3"
            }

            if {$level == 0} {
                set ::debug "off"
                set ::info(Debugging) 0
            } else {
                set ::debug "on"
                set ::info(Debugging) 1
                set ::verbose [incr level -1]
            }
        }
    } elseif {$value ne ""} {
        return -code error "usage: debugging ?on|off? ?file|console? ?logfile?"
    }

    if {$::debug || $::info(Debugging)} {
        echo "Debugging is turned on"
    } else {
        echo "Debugging is turned off"
    }
    if {$::debug} {
        echo "Debug output is being written to the console"
    }
    if {$::info(Debugging)} {
        echo "Debug output is being saved to a debug log file"
        echo "Debug log file is <%DebugLog%>" 1
    }
}

proc debug { message {id ""} } {
    global info

    ## We don't output debugging in the builder.
    if {[info exists ::InstallJammer]} { return }

    if {![string is true -strict $::debug]
        && ![string is true -strict $info(Debugging)]} { return }

    set time [clock format [clock seconds] -format "%m/%d/%Y %H:%M:%S%p"]
    set string "$time - $message"

    if {[set x [::InstallJammer::SubstText $message]] ne $message} {
        append string "\n$time - ** $x"
    }

    if {$id ne "" && [$id get Comment comment] && $comment ne ""} {
        append string "\n$time - # $comment"
        if {[set x [::InstallJammer::SubstText $comment]] ne $comment} {
            append string "\n$time - ** $x"
        }
    }

    if {![info exists ::InstallJammer]} {
        if {[string is true -strict $::debug]} {
            puts  stderr $string
            flush stderr
        }

        if {[string is true -strict $info(Debugging)]} {
            if {![info exists ::debugfp]} {
                set ::debugfp [open [::InstallJammer::TmpDir debug.log] w]
            } elseif {$::debugfp eq ""} {
                set ::debugfp [open [::InstallJammer::TmpDir debug.log] a]
            }

            puts  $::debugfp $string
            flush $::debugfp
        }
    }
}

proc threaded {} {
    global conf

    if {![info exists conf(threaded)]} {
        set conf(threaded) [info exists ::tcl_platform(threaded)]
        if {$conf(threaded)} {
            package require Thread
            if {[catch {thread::send [thread::id] #}]} { set conf(threaded) 0 }
        }
    }
    return $conf(threaded)
}

proc ::echo { string {subst 0} } {
    if {$subst} { set string [::InstallJammer::SubstText $string] }
    puts  stdout $string
    flush stdout
}

proc ::more { args } {
    global conf

    if {[expr {[llength $args] % 2}]} {
        set text [lindex $args end]
        set args [lrange $args 0 end-1]
    }

    array set _args {
        -file      ""
        -width     0
        -height    0
        -allowquit 1
    }
    array set _args $args

    if {$_args(-file) ne ""} {
        set text [read_file $_args(-file)]
    }

    set height $_args(-height)
    if {$height == 0} {
        set height 24
        if {[info exists conf(ConsoleHeight)]} {
            set height $conf(ConsoleHeight)
        } else {
            if {![catch { exec stty size } result]} {
                set height [lindex $result 0]
            }
        }
    }

    incr height -1

    if {$_args(-width) > 0} {
        set text [::InstallJammer::WrapText $text $_args(-width)]
    }

    catch { exec stty raw -echo <@stdin }

    if {!$_args(-allowquit)} {
        set prompt [::InstallJammer::SubstText "<%ConsolePauseText%>"]
    } else {
        set prompt [::InstallJammer::SubstText "<%ConsolePauseQuitText%>"]
    }

    catch { 
        set i 0
        foreach line [split $text \n] {
            puts stdout $line

            if {[incr i] >= $height} {
                puts -nonewline stdout $prompt
                flush stdout

                while {1} {
                    set x [read stdin 1]
                    if {$_args(-allowquit) && $x eq "q" || $x eq "Q"} {
                        return
                    } elseif {$x eq " "} {
                        break
                    }
                }

                puts  stdout ""
                flush stdout

                set i 0
            }
        }
    }

    catch { exec stty -raw echo <@stdin }

    return
}

proc ::tk_safeDialog {command opts safeOpts} {
    set args {}
    array set _args $opts
    foreach opt $safeOpts {
        if {[info exists _args($opt)]} {
            if {$opt eq "-parent" && ![winfo exists $_args($opt)]} { continue }
            if {$opt eq "-initialdir" && ![file exists $_args($opt)]} {continue}
            lappend args $opt $_args($opt)
        }
    }
    return [eval $command $args]
}

proc ::ij_chooseDirectory {args} {
    ::tk_safeDialog ::tk_chooseDirectory $args \
        {-initialdir -mustexist -parent -title}
}

proc ::ij_getOpenFile {args} {
    ::tk_safeDialog ::tk_getOpenFile $args \
        {-defaultextension -filetypes -initialdir -initialfile \
              -message -multiple -parent -title -typevariable}
}

proc ::ij_getSaveFile {args} {
    ::tk_safeDialog ::tk_getSaveFile $args \
        {-defaultextension -filetypes -initialdir -initialfile \
              -message -multiple -parent -title -typevariable}
}

if {[info exists ::conf(unix)] && $::conf(unix)} {
    ## Repace the core Tk get file dialogs with our own that looks nicer.
    proc ::tk_getOpenFile { args } {
        return [eval ChooseFile .__tk_getOpenFile $args -type open]
    }

    proc ::tk_getSaveFile { args } {
        return [eval ChooseFile .__tk_getSaveFile $args -type save]
    }

    proc ::tk_messageBox { args } {
        return [eval ::InstallJammer::MessageBox $args]
    }
}

proc SafeSet { varName value } {
    upvar 1 $varName var
    if {![info exists var]} { set var $value }
    return $value
}

proc SafeArraySet { arrayName list } {
    upvar 1 $arrayName array
    foreach {varName elem} $list {
	if {![info exists array($varName)]} { set array($varName) $elem }
    }
}

package require msgcat

## We're going to redefine some of Tcl's msgcat commands in the
## name of simplifying things.
proc ::msgcat::mc { src args } {
    foreach loc [::msgcat::mcpreferences] {
        if {[info exists ::msgcat::Msgs_${loc}($src)]} { break }
    }
    return [eval [list ::msgcat::mcget $loc $src] $args]
}

proc ::msgcat::mcexists { src {locales {}} } {
    if {![llength $locales]} {
        set locales [::msgcat::mcpreferences]
    }
    foreach locale $locales {
        if {$locale eq "None"} {
            upvar #0 ::info msgs
        } else {
            upvar #0 ::msgcat::Msgs_${locale} msgs
        }

        if {[info exists msgs($src)]} { return 1 }
    }
    return 0
}

proc msgcat::mclocale { args } {
    variable Locale
    variable Loclist

    if {[llength $args] == 1 && [lindex $args 0] eq ""} {
        set Loclist {}
        return
    }

    if {[llength $args]} {
        foreach locale $args {
            set loc  {}
            set word ""
            foreach part [split [string tolower $locale] _] {
                set word [string trimleft "${word}_${part}" _]
                if {[set x [lsearch -exact $Loclist $word]] > -1} {
                    set Loclist [lreplace $Loclist $x $x]
                }
                set Loclist [linsert $Loclist 0 $word]
            }
        }
        set Locale $locale
    }
    return $Locale
}

proc ::msgcat::mcset { locale src {dest ""} } {
    if {$locale eq "None"} {
        upvar #0 ::info msgs
    } else {
        upvar #0 ::msgcat::Msgs_${locale} msgs
    }

    if {[llength [info level 0]] == 3} { set dest $src }
    set msgs($src) $dest
}

proc ::msgcat::mcunset { locale src } {
    if {$locale eq "None"} {
        upvar #0 ::info msgs
    } else {
        upvar #0 ::msgcat::Msgs_${locale} msgs
    }

    array unset msgs $src
}

proc ::msgcat::mcmset { locale pairs } {
    if {$locale eq "None"} {
        upvar #0 ::info msgs
    } else {
        upvar #0 ::msgcat::Msgs_${locale} msgs
    }

    array set msgs $pairs
}

proc ::msgcat::mcgetall { locale } {
    if {$locale eq "None"} {
        upvar #0 ::info msgs
    } else {
        upvar #0 ::msgcat::Msgs_${locale} msgs
    }

    return [array get msgs]
}

proc ::msgcat::mcget { locale src args } {
    if {$locale eq "None"} {
        upvar #0 ::info msgs
    } else {
        upvar #0 ::msgcat::Msgs_${locale} msgs
    }

    if {![info exists ::msgcat::renderer($locale)]} {
        set ::msgcat::renderer($locale) \
            [expr {[info commands ::${locale}::render] ne ""}]
    }

    if {[info exists msgs($src)]} {
        set src $msgs($src)

        if {$::msgcat::renderer($locale)} {
            set src [::${locale}::render $src]
        }
    }

    if {[llength $args]} {
        return [uplevel 1 [linsert $args 0 ::format $src]]
    } else {
        return $src
    }
}

proc ::msgcat::mcclear { locale } {
    unset -nocomplain ::msgcat::Msgs_${locale}
}

## Procs for testing

proc inject {cmd args} {
    variable ::InstallJammer::tests

    switch -- $cmd {
        "before" - "after" {
            lassign $args id script
            set id [::InstallJammer::ID $id]
            lappend tests($cmd,$id) $script
        }

        "enter" - "leave" {
            lassign $args proc script
            trace add exec $proc $cmd [list inject run $script] }

        "run" {
            set test [lindex $args 0]
            if {[info exists tests($test)]} {
                foreach script $tests($test) {
                    uplevel #0 $script
                }
            } else {
                uplevel #0 $test
            }
        }
    }
}

proc test_pressButton {button} {
    set found 0
    foreach top [::InstallJammer::Grab stack] {
        foreach w [::InstallJammer::GetAllWidgets $top] {
            set c [winfo class $w]
            if {$c eq "Button" || $c eq "TButton"} {
                if {[$w cget -text] eq $button} {
                    set found 1
                    $w invoke
                    break
                }
            }
        }
        if {$found} { break }
    }
}

namespace eval ::InstallJammer {}
namespace eval ::InstallJammer::actions {}
namespace eval ::InstallJammer::conditions {}

proc ::InstallJammer::CommonInit {} {
    global info
    global conf

    if {[info exists conf(commonInit)]} { return }

    set conf(osx)       [string equal $::tcl_platform(os) "Darwin"]
    set conf(unix)      [string equal $::tcl_platform(platform) "unix"]
    set conf(windows)   [string equal $::tcl_platform(platform) "windows"]
    set conf(windows98) [expr {$conf(windows)
                           && $::tcl_platform(osVersion) < 5.0}]
    set conf(vista)     [expr {$conf(windows)
                           && $::tcl_platform(osVersion) >= 6.0}]
    set conf(wine)      [expr {$conf(windows) && [info exists ::env(_)]
                         && [file tail $::env(_)] eq "wine"}]

    array set conf {
	commonInit   1

        logInit      0

        ExitCode     ""

        ObjectStack   {}
        ParentWindow  {}
        UpdateWidgets {}
        ButtonWidgets {BackButton NextButton CancelButton}

        UserRCFiles {~/.bashrc ~/.cshrc ~/.tcshrc ~/.zshrc ~/.kshrc ~/.profile}
        SystemRCFiles {/etc/bashrc /etc/csh.cshrc /etc/zshrc /etc/profile}

        ShowConsoleProgress 1

        UpdateWindowsRegistry 0

        ModifySelectedComponents 1

        ComponentTrees  {}
        SetupTypeTrees  {}

        SaveResponseVars {
            "CreateDesktopShortcut boolean"
            "CreateQuickLaunchShortcut boolean"
            "InstallDir string"
            "InstallMode string"
            "InstallType string"
            "LaunchApplication boolean"
            "ProgramFolderName string"
            "SelectedComponents list"
            "ViewReadme boolean"
        }

        VirtualTextMap            {}
	VirtualTextRecursionLimit 10
    }

    lappend conf(VirtualTextMap) "\\" "\\\\" "\[" "\\\["
    lappend conf(VirtualTextMap) "<%" {[::InstallJammer::SubstVar [list }
    lappend conf(VirtualTextMap) "%>" {]]}

    if {[info exists ::installkit::root]} {
        set conf(vfs) $::installkit::root
    }
    set conf(exe)      [info nameofexecutable]
    set conf(script)   [info script]

    if {$conf(windows)} {
        set info(Ext)       ".exe"
        set info(ScriptExt) ".bat"
    } else {
        set info(Ext)       ""
        set info(ScriptExt) ".sh"
    }

    array set ::InstallJammer::PropertyMap {
        Include {
            "Always include"
            "Include only when testing"
            "Include only when not testing"
        }

        ExecuteAction {
            "After Pane is Cancelled"
            "After Pane is Displayed"
            "After Pane is Finished"
            "Before Next Pane is Displayed"
            "Before Pane is Cancelled"
            "Before Pane is Displayed"
            "Before Pane is Finished"
            "Before Previous Pane is Displayed"
        }

        FileUpdateMethod {
            "Update files with more recent dates"
            "Update files with a newer version"
            "Always overwrite files"
            "Never overwrite files"
        }

        CheckCondition {
            "After Pane is Cancelled"
            "Before Next Pane is Displayed"
            "Before Pane is Cancelled"
            "Before Pane is Displayed"
            "Before Pane is Finished"
            "Before Previous Pane is Displayed"
            "Before Action is Executed"
            "Before Next Action is Executed"
        }
    }

    ## Append some default directories to the PATH so that
    ## we can find tools we're looking for even if the user
    ## running the installer doesn't include these directoris.
    if {!$conf(windows)} {
        append ::env(PATH) ":/bin:/sbin:/usr/bin:/usr/sbin"
        append ::env(PATH) ":/usr/local/bin:/usr/local/sbin"

        ## Include KDE4 paths to get kdesu.
        append ::env(PATH) ":/usr/lib/kde4/libexec"
        append ::env(PATH) ":/usr/lib64/kde4/libexec"
    }

    ::InstallJammer::InitializeMessageCatalogs

    set conf(NativeChooseFile)       [expr {!$conf(unix)}]
    set conf(NativeMessageBox)       [expr {!$conf(unix)}]
    set conf(NativeChooseDirectory)  [expr {!$conf(unix)}]

    msgcat::Init
    if {[info exists ::InstallJammer]} {
        msgcat::mclocale en
    } else {
        ## Running from an installer or uninstaller

        ## Setup common variables for an install or uninstall.
        set ::debug "off"

        array set conf {
            ConsoleWidth      80
            ConsoleHeight     24
            NativeMessageBox  0
            panesToSkip       {}
        }
        set conf(NativeChooseDirectory) $conf(osx)

        SafeArraySet conf {
            twapi               0
            Wow64Disabled       0
        }

        array set info {
            Wizard             .wizard
            WizardFirstStep    0
            WizardLastStep     0
            WizardStarted      0
            WizardFinished     0
            WizardCancelled    0

	    Errors             ""

            SilentMode         0
            DefaultMode        0

            UserMovedBack      0
            UserMovedNext      0

            ShowConsole        0

            Debugging          0
            Testing            0
        }

	SafeArraySet info {
            AllowLanguageSelection 1
            PromptForRoot          1

            Language                "en"
            DefaultToSystemLanguage "Yes"

            InstallMode            "Standard"
            UninstallMode          "Standard"

            FallBackToConsole      0

            InstallVersionInfo     1
            InstallRegistryInfo    1

            RunningInstaller       0
            RunningUninstaller     0

            SpaceRequiredText      "<%DiskSpace <%SpaceRequired%>%>"
            SpaceAvailableText     "<%DiskSpace <%SpaceAvailable%>%>"
	}

        set info(Home) [::InstallJammer::HomeDir]

        if {$info(RunningInstaller)} {
            if {[info exists info(DefaultLanguage)]} {
                set info(Language) [GetLanguageCode $info(DefaultLanguage)]
            }

            set info(SystemLanguage) [::msgcat::mclocale]
            set codes [::InstallJammer::GetLanguageCodes]
            foreach lang [::msgcat::mcpreferences] {
                if {[lsearch -exact $codes $lang] > -1} {
                    set info(SystemLanguage) $lang
                    if {$info(DefaultToSystemLanguage)} {
                        set info(Language) $lang
                    }
                    break
                }
            }

            set info(InstallStartupDir) [pwd]
        } elseif {$info(RunningUninstaller)} {
            set info(UninstallStartupDir) [pwd]
        }

        if {$conf(windows)} {
            set info(Username)      $::tcl_platform(user)
            set info(PathSeparator) \;

            set info(Desktop) <%DESKTOP%>

            ::InstallJammer::SetWindowsPlatform
            ::InstallJammer::SetupRegVirtualText
        } else {
            set info(Username)        [id user]
            set info(PathSeparator)   :
            set info(HasKDEDesktop)   [::InstallJammer::HasKDEDesktop]
            set info(HasGnomeDesktop) [::InstallJammer::HasGnomeDesktop]

            switch -- [::InstallJammer::GetDesktopEnvironment] {
                "KDE" {
                    set info(Desktop) <%KDEDesktop%>
                }

                "Gnome" {
                    set info(Desktop) <%GnomeDesktop%>
                }
            }

            set info(HaveTerminal) [expr {[catch { exec tty }] == 0}]
        }

        if {[info exists info(Language)]} {
            ::InstallAPI::LanguageAPI -do setlanguage -language $info(Language)
        }

        set info(UserIsRoot)   [string equal $info(Username) "root"]
        set info(RealUsername) $::tcl_platform(user)

        ## Setup <%Status%> to automatically update the screen when modified.
        ::InstallAPI::SetVirtualText -virtualtext Status -value "" -autoupdate 1

        ## Call a command when <%InstallDir%> is modified.
        ::InstallAPI::SetVirtualText -virtualtext InstallDir \
            -command ::InstallJammer::ModifyInstallDir

        ## Change the main window title when <%InstallTitleText%> is changed.
        ::InstallAPI::SetVirtualText -virtualtext Language \
            -command ::InstallJammer::ModifyInstallTitle
        ::InstallAPI::SetVirtualText -virtualtext InstallTitleText \
            -command ::InstallJammer::ModifyInstallTitle
        ::InstallAPI::SetVirtualText -virtualtext InstallTitleText \
            -language all -command ::InstallJammer::ModifyInstallTitle

        ::InstallAPI::VirtualTextAPI -do settype -type directory -virtualtext {
	    CommonStartMenu
            Desktop
            FileBeingInstalled
	    GnomeCommonStartMenu
	    GnomeDesktop
	    GnomeStartMenu
	    Home
	    InstallDir
	    Installer
	    InstallLogDirectory
	    InstallSource
	    KDECommonStartMenu
	    KDEDesktop
	    KDEStartMenu
            ProgramReadme
            ProgramLicense
	    ProgramExecutable
	    ProgramFolder
	    Uninstaller
	    UninstallDirectory
	}
    }

    SafeArraySet info {
        Date            "<%Date <%DateFormat%>%>"
        DateFormat      "%Y%m%d"
    }
}

proc ::InstallJammer::CommonPostInit {} {
    global conf
    global info

    set conf(stop)  [::InstallJammer::TmpDir .stop]
    set conf(pause) [::InstallJammer::TmpDir .pause]

    if {[info exists conf(vfs)]} {
        set bin    [file join $conf(vfs) lib bin]
        set tmpbin [::InstallJammer::TmpDir bin]
        if {[file exists $bin] && ![file exists $tmpbin]} {
            set ::env(PATH) "$tmpbin$info(PathSeparator)$::env(PATH)"
            file copy -force $bin $tmpbin
            if {!$conf(windows)} {
                foreach file [glob -dir $tmpbin *] {
                    file attributes $file -permissions 0755
                }
            }
        }
    }
}

proc ::InstallJammer::InitializeGui {} {
    global conf
    global info

    if {[info exists ::InstallJammer]} { return }
    if {[info exists conf(InitializeGui)]} { return }
    set conf(InitializeGui) 1

    SourceCachedFile gui.tcl
    InitGui

    ## InitGui might fail because Tk cannot be loaded or because
    ## we don't have a DISPLAY to display to.  If that happens,
    ## we don't want to keep going with the rest of the init.
    if {!$info(GuiMode)} { return }

    set key Control
    if {$conf(osx)} { set key Command }

    bind Text <$key-a>   "%W tag add sel 1.0 end"
    bind Text <$key-Tab> [bind Text <Tab>]
    bind Text <Tab> "# nothing"
    bind Text <Shift-Tab> ""

    wm protocol $info(Wizard) WM_DELETE_WINDOW ::InstallJammer::CloseButton
}

proc ::InstallJammer::CloseButton {} {
    global info

    if {[grab current] eq "" || [grab current] eq $info(Wizard)} {
        $info(Wizard) cancel 1
    }
}

proc ::InstallJammer::InitializeMessageCatalogs {} {
    global conf
    global info

    variable languages
    variable languagecodes

    if {[info exists ::InstallJammer]} {
        set langfile [file join $conf(lib) msgs languages.txt]
        if {[file exists $langfile]} {
            array set ::InstallJammer::languagecodes [read_file $langfile]
        }
    }

    if {![array exists languagecodes]} {
        array set languagecodes {
            de      "German"
            en      "English"
            es      "Spanish"
            fr      "French"
            pl      "Polish"
            pt_br   "Brazilian Portuguese"
        }
    }

    if {[info exists info(Languages)]} {
        array set languagecodes $info(Languages)
    }

    foreach var [array names languagecodes] {
        set languages($languagecodes($var)) $var
    }
    set languages(None) None

    return [lsort [array names languagecodes]]
}

proc ::InstallJammer::GetLanguageCode { lang } {
    set lang [string tolower $lang]

    set codes [::InstallJammer::GetLanguageCodes]
    if {[set x [lsearch -exact [string tolower $codes] $lang]] > -1} {
        return [lindex $codes $x]
    }

    set langs [::InstallJammer::GetLanguages]
    if {[set x [lsearch -exact [string tolower $langs] $lang]] > -1} {
        return $::InstallJammer::languages([lindex $langs $x])
    }
}

proc ::InstallJammer::GetLanguageCodes {} {
    return [lsort [array names ::InstallJammer::languagecodes]]
}

proc ::InstallJammer::GetLanguage { code } {
    set code [string tolower $code]

    set langs [::InstallJammer::GetLanguages]
    if {[set x [lsearch -exact [string tolower $langs] $code]] > -1} {
        return [lindex $langs $x]
    }

    set codes [::InstallJammer::GetLanguageCodes]
    if {[set x [lsearch -exact [string tolower $codes] $code]] > -1} {
        return $::InstallJammer::languagecodes([lindex $codes $x])
    }
}

proc ::InstallJammer::GetLanguages { {includeNone 0} } {
    variable languages
    set list [lremove [lsort [array names languages]] None]
    if {$includeNone} { set list [linsert $list 0 None] }
    return $list
}

proc ::InstallJammer::ConfigureBidiFonts {} {
    if {$::info(Language) eq "ar"} {
        foreach font [font names] {
            font configure $font -family Arial -size 10
        }
    }
}

proc ::InstallJammer::LoadTwapi {} {
    global conf

    ## Check to see if the user included the TWAPI extension
    ## and that we're on Windows XP or higher.  If so, require
    ## the extension to load the commands.
    set conf(twapi) 0
    if {$conf(windows)
        && $::tcl_platform(osVersion) >= 5.0
        && [info exists ::installkit::root]
        && [llength [package versions twapi]]} {
        ## Set a variable to trick TWAPI.
        namespace eval ::twapi {
            set temp_dll_dir [::InstallJammer::TmpDir]
        }

        package require twapi
        set conf(twapi) 1
    }
}

proc ::InstallJammer::InitializeCommandLineOptions {} {
    global conf
    global info

    if {[info exists conf(initializeCommandLine)]} { return }
    set conf(initializeCommandLine) 1

    variable ::InstallJammer::CommandLineOptions

    ## Setup the default options that all InstallJammer installers have.
    ## These options should not be removed by the developer.

    set CommandLineOptions(help) {
        {} Switch 0 0 {}
        "display this information" 
    }

    set CommandLineOptions(temp) {
        TempRoot String 0 0 {}
        "set the temporary directory used by this program"
    }

    set CommandLineOptions(version) {
        {} Switch 0 0 {}
        "display installer version information"
    }

    if {$info(EnableResponseFiles)} {
        set CommandLineOptions(response-file) {
            ResponseFile String 0 0 {}
            "a file to read installer responses from"
        }

        set CommandLineOptions(save-response-file) {
            SaveResponseFile String 0 0 {}
            "a file to write installer responses to when the installer exits"
        }
    }

    ## Make all the options case-insensitive.

    foreach opt [array names CommandLineOptions] {
        set name [string tolower $opt]
        set CommandLineOptions($name) [concat $opt $CommandLineOptions($opt)]
        if {$opt ne $name} { unset CommandLineOptions($opt) }

        lassign $CommandLineOptions($name) x var type debug hide values desc
        if {$type eq "Prefix"} {
            lappend CommandLineOptions(PREFIX) $name
        }
    }
}

proc ::InstallJammer::HideMainWindow {} {
    global conf
    global info

    if {[info exists ::tk_patchLevel]} {
        ## Hide the . window so no one will ever find it.
        wm geometry . 0x0+-10000+-10000
        ::InstallJammer::ModifyInstallTitle
        if {!$conf(windows) || !$info(GuiMode)} { wm overrideredirect . 1 }

        if {$info(GuiMode)} { wm deiconify . }
    }
}

proc ::InstallJammer::NewStyle { newStyle oldStyle args } {
    style layout $newStyle [style layout $oldStyle]
    eval [list style configure $newStyle] [style configure $oldStyle] $args
    return $newStyle
}

proc ::InstallJammer::CreateDir { dir {log 1} } {
    variable CreateDir

    if {![info exists CreateDir($dir)]} {
        set list [file split $dir]

        for {set i 0} {$i < [llength $list]} {incr i} {
            lappend dirlist [lindex $list $i]
            set dir [eval file join $dirlist]
            if {![info exists CreateDir($dir)]} {
                set CreateDir($dir) 1
                if {![file exists $dir]} {
                    file mkdir $dir
                    if {$log} { ::InstallJammer::LogDir $dir }
                }
            }
        }
    }

    return $dir
}

proc ::InstallJammer::DirIsEmpty { dir } {
    set list1 [glob -nocomplain -directory $dir *]
    set list2 [glob -nocomplain -directory $dir -types hidden *]
    set list  [lremove [concat $list1 $list2] $dir/. $dir/..]
    return    [lempty $list]
}

proc ::InstallJammer::PlaceWindow { id args } {
    set id [::InstallJammer::ID $id]
    set anchor center

    if {[winfo exists $id]} {
        set target $id
    } else {
        set target [$id window]
        if {![$id get Anchor anchor]} { set anchor center }
    }

    array set data "
	-anchor $anchor
	-width  [winfo reqwidth  $target]
	-height [winfo reqheight $target]
    "

    array set data $args

    set w  $data(-width)
    set h  $data(-height)
    set sw [winfo screenwidth $target]
    set sh [winfo screenheight $target]
    lassign [wm maxsize .] maxw maxh
    set anchor $data(-anchor)
    switch -- $anchor {
	"center" {
	    set x0 [expr ($sw - $w) / 2 - [winfo vrootx $target]]
	    set y0 [expr ($sh - $h) / 2 - [winfo vrooty $target]]
	}

	"n" {
	    set x0 [expr ($sw - $w)  / 2 - [winfo vrootx $target]]
	    set y0 20
	}

	"ne" {
	    set x0 [expr $maxw - $w - 40]
	    set y0 20
	}

	"e" {
	    set x0 [expr $maxw - $w - 40]
	    set y0 [expr ($sh - $h) / 2 - [winfo vrooty $target]]
	}

	"se" {
	    set x0 [expr $maxw - $w - 40]
	    set y0 [expr $maxh - $h - 80]
	}

	"s" {
	    set x0 [expr ($sw - $w)  / 2 - [winfo vrootx $target]]
	    set y0 [expr $maxh - $h - 80]
	}

	"sw" {
	    set x0 20
	    set y0 [expr $maxh - $h - 80]
	}

	"w" {
	    set x0 20
	    set y0 [expr ($sh - $h) / 2 - [winfo vrooty $target]]
	}

	"nw" {
	    set x0 20
	    set y0 20
	}

	default {
	    append msg "bad anchor \"$anchor\": must be"
	    append msg "n, ne, e, se, s, sw, w, nw or center"
	    return -code error $msg
	}
    }

    set x "+$x0"
    set y "+$y0"
    if { $x0+$w > $sw } {set x "-0"; set x0 [expr {$sw-$w}]}
    if { $x0 < 0 }      {set x "+0"}
    if { $y0+$h > $sh } {set y "-0"; set y0 [expr {$sh-$h}]}
    if { $y0 < 0 }      {set y "+0"}

    wm geometry $target $x$y
    update
}

proc ::InstallJammer::CenterWindow { target {w 473} {h 335} {lower 0} } {
    set args [list -width $w -height $h]
    if {$lower} { lappend args -anchor s }
    eval [list PlaceWindow $target] $args
}

proc ::InstallJammer::ID { args } {
    set alias [string trim [join $args]]
    if {[info exists ::InstallJammer::aliases($alias)]} {
        return $::InstallJammer::aliases($alias)
    }
    return $alias
}

proc ::InstallJammer::FindCommonPane { pane } {
    foreach id [Common children] {
        if {[string equal [$id component] $pane]} { return $id }
    }
}

proc ::InstallJammer::FindObjByName { name objects } {
    foreach object $objects {
        if {[string equal [$object name] $name]} { return $object }
    }
}

proc ::InstallJammer::GetPaneProc { id prefix } {
    set proc $prefix.$id
    if {![::InstallJammer::CommandExists $proc]} {
    	set proc $prefix.[$id component]
    }
    if {[::InstallJammer::CommandExists $proc]}  { return $proc }
}

proc ::InstallJammer::CurrentObject { {command "get"} {id ""} } {
    global conf
    global info

    if {$command eq "get"} {
        set id [lindex $conf(ObjectStack) end]
    } elseif {$command eq "pop"} {
        set id [lindex $conf(ObjectStack) end]
        set conf(ObjectStack) [lrange $conf(ObjectStack) 0 end-1]
    } elseif {$command eq "push" && $id ne ""} {
        lappend conf(ObjectStack) $id
    }

    set info(CurrentObject) [lindex $conf(ObjectStack) end]

    return $id
}

proc ::InstallJammer::ExecuteActions { id args } {
    global conf
    global info

    array set _args {
        -when       ""
        -type       ""
        -parent     ""
        -conditions 1
    }
    array set _args $args

    set id [::InstallJammer::ID $id]

    if {![::InstallJammer::ObjExists $id]} { return 1 }

    if {[$id is action]} {
        set idlist [list $id]
    } else {
        set idlist [$id children]
    }

    if {![llength $idlist]} { return 1 }

    set msg "Executing actions $id"
    if {![catch { $id title } title]} { append msg " - $title" }
    if {$_args(-when) ne ""} { append msg " - $_args(-when)" }
    debug $msg

    set res 1
    set conf(moveToPane) ""
    foreach id $idlist {
        if {![$id active]} { continue }

        set obj  $id
        set type [$obj component]

        if {$_args(-type) ne "" && $type ne $_args(-type)} { continue }

        if {[$id type] eq "actiongroup"} {
            eval ::InstallJammer::ExecuteActions [list $id] $args
            continue
        }

        ## If we have a parent, it means that we're an ExecuteAction
        ## action that is calling another action, which can also be
        ## an action group.  We want the action we're executing
        ## to have the attributes of the parent action, so we create
        ## a temporary object that inherits the attributes of the
        ## parent and execute that in place of the original object.

        if {$_args(-parent) ne ""} {
            set obj [::InstallJammer::CreateTempAction $_args(-parent) $id]
            lappend tempObjects $obj
        }

        if {$_args(-when) ne ""
            && [$obj get ExecuteAction when]
            && ![string equal -nocase $_args(-when) $when]} { continue }

        set info(CurrentAction) $id
        ::InstallJammer::CurrentObject push $id

        $obj executed 0

        set when "Before Action is Executed"
        if {$_args(-conditions) && ![$obj checkConditions $when]} {
            debug "Skipping action $id - [$id title] - conditions failed"
            ::InstallJammer::CurrentObject pop
            continue
        }

        set when "Before Next Action is Executed"
        while {1} {
            $obj execute
            
            ## Check the after conditions.  If the conditions fail,
            ## we want to repeat the action until they succeed.
            ## This is mainly for console actions to repeat if their
            ## conditions fail, like the user entered bad data or
            ## select a bad option.
            if {!$_args(-conditions) || [$obj checkConditions $when]} { break }
        }

        ::InstallJammer::CurrentObject pop
        if {$conf(moveToPane) ne ""} {
            set res  0
            set pane $conf(moveToPane)
            if {$pane eq "stop"} {
                ## Do nothing.
            } elseif {$pane eq "next"} {
                ::InstallJammer::Wizard next 1
            } else {
                if {$pane eq $info(CurrentPane)} {
                    ::InstallJammer::Wizard reload
                } else {
                    ::InstallJammer::Wizard raise $pane
                }
            }
            break
        }
    }

    if {[info exists tempObjects]} {
        eval itcl::delete object $tempObjects
    }

    return $res
}

proc ::InstallJammer::CreateTempAction { id child } {
    set obj [InstallComponent ::#auto -temp 1 -parent [$id parent] \
        -setup [$id setup] -type action -id $child -name [$child name] \
        -component [$child component] -conditions [$child conditions] \
        -operator [$child operator]]

    return $obj
}

## Uses the wizard's -backcommand option.
proc ::InstallJammer::BackCommand { wizard id } {
    global info

    set when "Before Previous Pane is Displayed"

    if {![$id checkConditions $when]} { return 0 }

    set res [::InstallJammer::ExecuteActions $id -when $when]

    set info(UserMovedBack) 1
    set info(UserMovedNext) 0

    return $res
}

## This command is executed when the user hits next but before
## the next pane is displayed.
## Uses the wizard's -nextcommand option.
proc ::InstallJammer::NextCommand { wizard id } {
    global info

    set when "Before Next Pane is Displayed"

    if {![$id checkConditions $when]} { return 0 }

    set res [::InstallJammer::ExecuteActions $id -when $when]

    set info(UserMovedBack) 0
    set info(UserMovedNext) 1

    return $res
}

## This command is executed before the installer is cancelled.
## Uses the wizard's -cancelcommand option.
proc ::InstallJammer::CancelCommand { wizard id } {
    set when "Before Pane is Cancelled"

    if {![$id checkConditions $when]} { return 0 }

    return [::InstallJammer::ExecuteActions $id -when $when]
}

## Uses the wizard's <<WizardCancel>> event.
proc ::InstallJammer::CancelEventHandler { wizard } {
    #set id [$wizard raise]

    #set when "After Pane is Cancelled"
    #::InstallJammer::ExecuteActions $id -when $when

    if {[$wizard itemcget cancel -state] eq "normal"} {
        ::InstallJammer::exit 1
    }
}

## This command is executed before the installer is finished.
## Uses the wizard's -finishcommand option.
proc ::InstallJammer::FinishCommand { wizard id } {
    set when "Before Pane is Finished"

    if {![$id checkConditions $when]} { return 0 }

    return [::InstallJammer::ExecuteActions $id -when $when]
}

## Uses the wizard's <<WizardFinish>> event.
proc ::InstallJammer::FinishEventHandler { wizard } {
    set id [$wizard raise]

    set when "After Pane is Finished"
    ::InstallJammer::ExecuteActions $id -when $when

    ::InstallJammer::exit
}

## Uses the wizard's <<WizardStep>> event.
proc ::InstallJammer::RaiseEventHandler { wizard } {
    global conf
    global info

    set id [$wizard raise]

    set info(CurrentPane) $id

    set conf(skipPane) 0
    set when "Before Pane is Displayed"
    if {![$id active]} {
        set conf(skipPane) 1
        set msg "pane is inactive"
    } elseif {![$id checkConditions $when]} {
        set conf(skipPane) 1
        set msg "conditions failed"
    } elseif {[lsearch -exact $conf(panesToSkip) $id] > -1} {
        set conf(skipPane) 1
        set msg "skipped by action or API"
    } else {
        set component [$id component]
        if {[info exists ::InstallJammer::tests(before,$id)]} {
            inject run before,$id
        } elseif {[info exists ::InstallJammer::tests(before,$component)]} {
            inject run before,$component
        }

        ::InstallJammer::ExecuteActions $id -when $when
        set msg "skipped by actions"
    }

    if {$conf(skipPane) || [lsearch -exact $conf(panesToSkip) $id] > -1} {
        debug "Skipping pane $id - [$id title] - $msg" $id
        $wizard order [lrange [$wizard order] 0 end-1]
        ::InstallAPI::WizardAPI -do next
        return
    }

    ## If the wizard isn't currently displaying our object, then
    ## that means that the previous actions have moved us somewhere
    ## else in the wizard.  We want to just stop.
    if {$id ne [$wizard raise]} { return }

    debug "Displaying pane $id - [$id title]" $id

    ## If the last step we displayed was a window and not part
    ## of the wizard, we need to withdraw the window as we move on.
    if {[info exists conf(LastStepId)] && [$conf(LastStepId) is window]} {
        set window [$conf(LastStepId) window]
        ::InstallJammer::TransientParent $window 1
        wm withdraw $window
    } else {
        ::InstallJammer::TransientParent $wizard 1
    }

    ## If this component is a window, we need to withdraw the
    ## wizard and display it.
    if {[$id is window]} {
        set base [$id window]
        ::InstallJammer::TransientParent $base

        wm withdraw $wizard 

        ::InstallJammer::UpdateWidgets

        if {![$id get Modal  modal]}  { set modal  0 }
        if {![$id get Dialog dialog]} { set dialog 0 }

        if {[winfo exists $base]} {
            wm deiconify $base
            raise $base
            if {$modal} { ::InstallJammer::Grab set $base }
        }

        update

        set when "After Pane is Displayed"
        ::InstallJammer::ExecuteActions $id -when $when

        if {[winfo exists $base]} {
            if {$dialog} {
                if {[$id get DialogVairiable varName]} {
                    tkwait variable $varName
                } else {
                    tkwait window $base
                }
            }

            if {$modal} { ::InstallJammer::Grab release $base }
        }
    } else {
        ::InstallJammer::TransientParent $wizard
        ::InstallJammer::UpdateWidgets -wizard $wizard -step $id -buttons 1

        $wizard show
        focus [$wizard widget get next]
        update

        set when "After Pane is Displayed"
        ::InstallJammer::ExecuteActions $id -when $when
    }

    if {[info exists ::InstallJammer::tests(after,$id)]} {
        inject run after,$id
    } elseif {[info exists ::InstallJammer::tests(after,$component)]} {
        inject run after,$component
    }

    set info(WizardLastStep)  0
    set info(WizardFirstStep) 0

    set conf(LastStepId) $id
}

proc ::InstallJammer::UpdateWizardButtons { args } {
    global info

    if {[llength $args]} {
        lassign $args wizard id
    } else {
        set wizard $info(Wizard)
        set id [$wizard raise]
    }

    if {![$id get Buttons buttons]} { return }

    foreach button [list back next cancel finish help] {
        if {![$wizard exists $button]} { continue }

        set text [string totitle $button]
        if {[string match "*$text*" $buttons]} {
            $wizard itemconfigure $button -hide 0

            set w [$wizard widget get $button -step $id]
            ::InstallJammer::SetText $w $id [string toupper $button 0]Button
        } else {
            $wizard itemconfigure $button -hide 1
        }
    }
}

proc ::InstallJammer::Wizard { args } {
    global info

    set wizard $info(Wizard)

    if {![llength $args]} { return $wizard }

    set command [lindex $args 0]
    set args    [lrange $args 1 end]

    set id [::InstallJammer::ID [lindex $args 0]]

    switch -- $command {
        "back" {
            if {![llength $args]} { set args 1 }
            eval [list $info(Wizard) back] $args
        }

        "next" {
            if {![llength $args]} { set args 1 }
            eval [list $info(Wizard) next] $args
        }

        "create" {
            ::InstallJammer::CreateWindow $wizard $id
        }

        "raise" {
            set args [lreplace $args 0 0 $id]
            if {[llength $args] == 1} { lappend args 1 }
            $info(Wizard) order [concat [$info(Wizard) order] $id]
            eval [list $info(Wizard) raise] $args
        }

        "reload" {
            event generate $info(Wizard) "<<WizardStep>>"
        }

        "show" {
            $wizard show
        }

        "hide" {
            if {$id eq ""} {
                $wizard hide
            } else {
                wm withdraw [$id window]
            }
        }
    }
}

proc ::InstallJammer::CreateWindow { wizard id {preview 0} } {
    set id    [::InstallJammer::ID $id]
    set pane  [$id component]
    set istop [$id is window]

    set base  .[$id name]

    if {$istop} {
        if {[winfo exists $base]} { return $base }
    } else {
        if {[$wizard exists $id] && ($preview || [$id created])} {
            return [$wizard widget get $id]
        }
    }

    set parent [$id parent]

    if {$preview && ![$wizard exists $id]} {
        set parent root
        $id get WizardOptions opts
        eval [list $wizard insert step end $parent $id] $opts
    }

    if {!$preview && [$wizard exists $id]} {
        $wizard itemconfigure $id \
            -backcommand   [list ::InstallJammer::BackCommand  $wizard $id]  \
            -nextcommand   [list ::InstallJammer::NextCommand  $wizard $id]  \
            -cancelcommand [list ::InstallJammer::CancelCommand $wizard $id] \
            -finishcommand [list ::InstallJammer::FinishCommand $wizard $id]

        bind $wizard <<WizardStep>>   "::InstallJammer::RaiseEventHandler  %W"
        bind $wizard <<WizardCancel>> "::InstallJammer::CancelEventHandler %W"
        bind $wizard <<WizardFinish>> "::InstallJammer::FinishEventHandler %W"

        bind $wizard <<WizardLastStep>>  "set ::info(WizardLastStep)  1"
        bind $wizard <<WizardFirstStep>> "set ::info(WizardFirstStep) 1"

        $id created 1
    }

    set proc [GetPaneProc $id CreateWindow]

    if {[string length $proc]} {
        if {!$istop} {
            $wizard createstep $id

            $proc $wizard $id
            set base [$wizard widget get $id]
            $id window $base
        } else {
            $id window $base
            $proc $wizard $id
        }
    }

    return $base
}

proc ::InstallJammer::TransientParent { {parent ""} {remove 0} } {
    global conf

    if {$parent ne ""} {
        if {$remove} {
            set conf(ParentWindow) [lremove $conf(ParentWindow) $parent]
        } else {
            lappend conf(ParentWindow) $parent
        }
    }

    set parent "."
    if {[info exists conf(ParentWindow)]} {
        set windows $conf(ParentWindow)
        set conf(ParentWindow) [list]

        ## Strip out any windows that have been destroyed.
        foreach window $windows {
            if {[winfo exists $window]} {
                lappend conf(ParentWindow) $window
            }
        }

        ## Find the first parent that is actually visible.
        foreach window [lreverse $conf(ParentWindow)] {
            if {[wm state $parent] eq "normal"} {
                set parent $window
                break
            }
        }
    }

    if {[wm state $parent] ne "normal"} { set parent "" }

    return $parent
}

proc ::InstallJammer::ParseArgs { arrayName arglist args } {
    upvar 1 $arrayName a

    array set _args $args

    if {[info exists _args(-switches)]} {
        foreach switch $_args(-switches) {
            set a($switch) 0
            set s($switch) 1
        }
    }

    if {[info exists _args(-options)]} {
        array set o $_args(-options)
        foreach {option default} $_args(-options) {
            set a($option) $default
        }
    }

    set a(_ARGS_) [list]

    set len [llength $arglist]
    for {set i 0} {$i < $len} {incr i} {
        set arg [lindex $arglist $i]

        if {[info exists s($arg)]} {
            set a($arg) 1
        } elseif {[info exists o($arg)]} {
            set a($arg) [lindex $arglist [incr i]]
        } else {
            set a(_ARGS_) [lrange $arglist $i end]
            break
        }
    }
}

proc ::InstallJammer::SetObjectProperties { id args } {
    variable ::InstallJammer::Properties

    ::InstallJammer::ParseArgs _args $args -switches {-safe -nocomplain}

    set args $_args(_ARGS_)

    if {[llength $args] == 1} { set args [lindex $args 0] }
    if {[llength $args] == 1} {
        set property [lindex $args 0]
        if {[info exists Properties($id,$property)]} {
            return $Properties($id,$property)
        }

        if {!$_args(-nocomplain)} {
            return -code error "invalid property '$property'"
        }

        return
    }

    foreach {property value} $args {
        if {!$_args(-safe) || ![info exists Properties($id,$property)]} {
            if {$property eq "Alias"} {
		catch { $id alias $value }

		if {[info exists ::InstallJammer::aliasmap($id)]} {
		    $id CleanupAlias
		}

		if {$value ne ""} {
		    set ::InstallJammer::aliases($value) $id
		    set ::InstallJammer::aliasmap($id) $value
		}
            }

            if {$property eq "Active"} { $id active $value }

            if {![info exists ::InstallJammer]} {
                variable ::InstallJammer::PropertyMap
                if {[info exists PropertyMap($property)]} {
                    set n $value
                    if {![string is integer -strict $n]} {
                        set n [lsearch -exact $PropertyMap($property) $value]
                        if {$n < 0} {
                            return -code error [BWidget::badOptionString value \
                                $value $PropertyMap($property)]
                        }
                    }
                    set value $n
                }
            }
            set Properties($id,$property) $value
        }
    }

    return $Properties($id,$property)
}

proc ::InstallJammer::GetObjectProperty { id property {varName ""} } {
    set value  ""
    set exists [info exists ::InstallJammer::Properties($id,$property)]
    if {$exists} {
        set value $::InstallJammer::Properties($id,$property)
        if {[info exists ::InstallJammer::PropertyMap($property)]
            && [string is integer -strict $value]} {
            set value [lindex $::InstallJammer::PropertyMap($property) $value]
        }
    }

    if {$varName ne ""} {
        upvar 1 $varName var
        set var $value
        return $exists
    } else {
        return $value
    }
}

proc ::InstallJammer::ObjectProperties { id arrayName args } {
    upvar 1 $arrayName array
    variable ::InstallJammer::Properties

    ::InstallJammer::ParseArgs _args $args -options {-prefix "" -subst 0}

    set slen 0
    if {[info exists _args(-subst)]} {
        set subst $_args(-subst)
        set slen  [llength $subst]
    }

    set props $_args(_ARGS_)
    if {![llength $props]} {
        foreach varName [array names Properties $id,*] {
            lappend props [string map [list $id, ""] $varName]
        }
    }

    set vars {}
    foreach prop $props {
        if {![info exists Properties($id,$prop)]} { continue }

        set val $Properties($id,$prop)
        if {$slen && ($subst eq "1" || [lsearch -exact $subst $prop] > -1)} {
            set val [::InstallJammer::SubstText $val]
        }
        if {[info exists ::InstallJammer::PropertyMap($prop)]
            && [string is integer -strict $val]} {
            set val [lindex $::InstallJammer::PropertyMap($prop) $val]
        }
        set prop $_args(-prefix)$prop
        lappend vars $prop
        set array($prop) $val
    }

    return $vars
}

proc ::InstallJammer::ObjectChildrenRecursive { object } {
    set children [list]

    foreach child [$object children] {
        lappend children $child
        eval lappend children [::InstallJammer::ObjectChildrenRecursive $child]
    }

    return $children
}

proc ::InstallJammer::SetTitle { w id } {
    set id [::InstallJammer::ID $id]
    set title [::InstallJammer::GetText $id Title]
    wm title $w $title
}

proc ::InstallJammer::SetVirtualText { languages window args } {
    if {[llength $args] == 1} { set args [lindex $args 0] }

    if {[string equal -nocase $languages "all"]} {
        set languages [::InstallJammer::GetLanguageCodes]
    }

    foreach lang $languages {
        if {$lang eq "None"} {
            global info
            foreach {name value} $args {
                set info($name) $value
                debug "Virtual Text $name is now set to $value"
            }
        } else {
            set lang [::InstallJammer::GetLanguageCode $lang]
            foreach {name value} $args {
                ::msgcat::mcset $lang $window,$name $value
            }
        }
    }
}

proc ::InstallJammer::GetText { id field args } {
    global info

    array set _args {
        -subst      1
        -language   ""
        -forcelang  0
        -forcesubst 0
    }
    array set _args $args

    set languages {}
    if {$_args(-language) ne ""} {
        foreach lang $_args(-language) {
            lappend languages [::InstallJammer::GetLanguageCode $lang]
        }
    }
    if {!$_args(-forcelang)} {
        eval lappend languages [::msgcat::mcpreferences]
    }

    if {[string equal -nocase $_args(-language) "all"]} {
        foreach lang [::InstallJammer::GetLanguageCodes] {
            set text [::InstallJammer::GetTextForField $id $field $lang]
            if {[info exists last] && $last ne $text} { return }
            set last $text
        }
        if {$_args(-subst)} { set text [::InstallJammer::SubstText $text] }
        return $text
    }

    set found 0
    foreach lang $languages {
        set text [::InstallJammer::GetTextForField $id $field $lang]
        if {$text ne ""} {
            set found 1
            break
        }
    }

    if {$found} {
	if {$_args(-forcesubst)
	    || ($_args(-subst) && [$id get $field,subst subst] && $subst)} {
	    set text [::InstallJammer::SubstText $text]
	}

	return $text
    }
}

proc ::InstallJammer::GetTextForField { id field lang } {
    set id   [::InstallJammer::ID $id]
    set item [$id component]
    set text [::msgcat::mcget $lang $id,$field]
    if {$text eq "$id,$field"} {
        set text [::msgcat::mcget $lang $item,$field]
    }
    if {$text ne "$item,$field"} {
        return $text
    }
}

proc ::InstallJammer::SetText { args } {
    if {[llength $args] == 3} {
        lassign $args w id field
        set id   [::InstallJammer::ID $id]
        set text [::InstallJammer::GetText $id $field]
    } elseif {[llength $args] == 2} {
        lassign $args w text
    }

    if {![winfo exists $w]} { return }

    set class [winfo class $w]

    if {$class eq "Frame" || $class eq "TFrame"} {
    	foreach child [winfo children $w] {
	    set class [winfo class $child]
	    if {$class eq "Label" || $class eq "TLabel"} {
	    	set w $child
		break
	    }
	}
    }

    if {$class eq "Text"} {
        ## We're using the -maxundo property as a trick for other
        ## code to tell us not to update this widget.
        if {![$w cget -maxundo]} {
            set state [$w cget -state]
            if {$state eq "disabled"} { $w configure -state normal }
            if {$state eq "readonly"} {
                $w clear
                $w Insert end $text
            } else {
                $w delete 0.0 end
                $w insert end $text
            }
            if {$state eq "disabled"} { $w configure -state disabled }
        }
    } elseif {($class eq "Label" || $class eq "TLabel")
    	&& [string length [$w cget -textvariable]]} {
        set [$w cget -textvariable] $text
    } else {
	$w configure -text $text
    }
}

proc ::InstallJammer::Image { id image } {
    global images

    set id    [::InstallJammer::ID $id]
    set image $id,$image

    if {![ImageExists $image]} { set image [$id component],$image }
    if {![ImageExists $image]} { return }

    set x [::InstallJammer::SubstText $images($image)]
    if {[string index $x 0] eq "@"} { set x [string range $x 1 end] }
    set x [::InstallJammer::ID $x]
    set x [::InstallJammer::Normalize $x unix]
    if {[info exists images($x)]} { return $images($x) }

    if {[::InstallJammer::IsID $x] && [::InstallJammer::ObjExists $x]} {
        set images($x) [image create photo -file [$x srcfile]]
    } elseif {[file exists $x]} {
        set images($x) [image create photo -file $x]
    }

    if {[info exists images($x)]} { return $images($x) }
}

proc ::InstallJammer::SetImage { w id image } {
    set image [::InstallJammer::Image $id $image]
    if {[winfo class $w] eq "TLabel"} { set image [list $image] }
    $w configure -image $image
}

proc ::InstallJammer::ImageExists {img} {
    global images
    return [info exists images($img)]
}

proc ::InstallJammer::GetWidget { widget {id ""} } {
    global info

    if {![info exists info(Wizard)] || ![winfo exists $info(Wizard)]} { return }

    if {$id eq ""} { set id [$info(Wizard) raise] }
    if {$id eq ""} { return }

    while {![$id ispane]} {
        if {$id eq ""} { return }
        set id [$id parent]
    }

    set widget [join [string trim $widget] ""]

    switch -- $widget {
        "BackButton" - "NextButton" - "CancelButton" {
            set widget [string tolower [string range $widget 0 end-6]]
            set widget [$info(Wizard) widget get $widget]
        }

        default {
            if {![winfo exists $widget]} {
                set widget [$id widget get $widget]
            }
        }
    }

    return $widget
}

proc ::InstallJammer::FindUpdateWidgets { textList args } {
    global conf
    global info

    if {![info exists ::tk_patchLevel]} { return }
    if {![info exists info(Wizard)]} { return }

    set _args(-wizard)  $info(Wizard)
    array set _args $args

    set wizard $_args(-wizard)
    if {![winfo exists $wizard]} { return }

    if {![info exists _args(-step)]} { set _args(-step) [$wizard raise] }
    set step $_args(-step)

    if {$step eq ""} { return }

    set widgets [concat [$step widgets] $conf(ButtonWidgets)]

    ## Remove the trace on the info array so that we don't accidentally
    ## trigger something with our testing.
    trace remove variable ::info write ::InstallJammer::VirtualTextTrace

    set include {}
    foreach virtualtext $textList {
        unset -nocomplain orig
        if {[info exists info($virtualtext)]} { set orig $info($virtualtext) }

        foreach widget $widgets {
            set info($virtualtext) TEST1
            set text1 [::InstallJammer::GetText $step $widget]

            set info($virtualtext) TEST2
            set text2 [::InstallJammer::GetText $step $widget]

            if {$text1 ne $text2} { lappend include $widget }
        }

        if {[info exists orig]} {
            set info($virtualtext) $orig
        } else {
            unset info($virtualtext)
        }
    }

    ## Reset the trace on the info array.
    trace add variable ::info write ::InstallJammer::VirtualTextTrace

    return $include
}

proc ::InstallJammer::UpdateSelectedWidgets { {widgets {}} args } {
    if {![info exists ::tk_patchLevel]} { return }

    if {![llength $widgets]} { set widgets $::conf(UpdateWidgets) }

    if {[llength $args]} {
        set wizard [lindex $args 0]
        set step   [lindex $args 1]
        if {![winfo exists $wizard]} { return }
    } else {
        set wizard $::info(Wizard)
        if {![winfo exists $wizard]} { return }

        set step   [$wizard raise]
    }

    foreach widget $widgets {
        if {[lsearch -exact $::conf(ButtonWidgets) $widget] > -1} {
            set name [string tolower [string map {Button ""} $widget]]
            if {[$wizard exists $name]} {
                set w [$wizard widget get $name -step $step]
                ::InstallJammer::SetText $w $step $widget
            }
        } else {
            set w [$step widget get $widget]

            if {![winfo exists $w]} { continue }

            switch -- [$step widget type $widget] {
                "progress" {
                    set value [::InstallJammer::GetText $step $widget]
                    if {[string is double -strict $value]} {
                        $w configure -value $value
                    }
                }

                "image" {
                    ::InstallJammer::SetImage $w $step $widget
                }

                "text" {
                    ::InstallJammer::SetText $w $step $widget
                }

                "usertext" {
                    if {![$w cget -maxundo]} {
                        $w clear
                        $w insert end [::InstallJammer::GetText $step $widget]
                    }
                }
            }
        }
    }
}

proc ::InstallJammer::UpdateWidgets { args } {
    global conf
    global info

    if {![info exists ::tk_patchLevel]} { return }
    if {![info exists info(Wizard)]} { return }

    array set _args {
        -update          0
        -buttons         0
        -widgets         {}
        -updateidletasks 0
    }
    set _args(-wizard)  $info(Wizard)
    set _args(-widgets) $conf(UpdateWidgets)

    array set _args $args

    set wizard $_args(-wizard)
    if {![winfo exists $wizard]} { return }

    if {![info exists _args(-step)]} { set _args(-step) [$wizard raise] }
    set step $_args(-step)

    if {$step eq ""} { return }

    if {![llength $_args(-widgets)]} { set _args(-widgets) [$step widgets] }
    
    ::InstallJammer::UpdateSelectedWidgets $_args(-widgets) $wizard $step

    if {$_args(-buttons)} { ::InstallJammer::UpdateWizardButtons $wizard $step }

    set update     $_args(-update)
    set updateIdle $_args(-updateidletasks)
    if {[info exists conf(update)]} {
        set update     $conf(update)
        set updateIdle $conf(update)
    }
    if {$update} { update; set updateIdle 0 }
    if {$updateIdle} { update idletasks }
}

proc ::InstallJammer::DirIsWritable {dir} {
    global conf

    ## Assume wine is always writable.
    if {$conf(wine)} { return 1 }
    if {$conf(windows98)} { return [expr {![catch {file attributes $dir}]}] }
    return [file writable $dir]
}

proc ::InstallJammer::Normalize { file {style ""} } {
    global conf

    if {$file ne ""} {
        set file [eval file join [file split $file]]

        if {[string match "p*" $style]} {
            ## platform
            set style $::tcl_platform(platform)
        }

        switch -glob -- $style {
            "u*" {
                ## unix
                set style forwardslash
                if {[string index $file 1] == ":"} {
                    set file [string range $file 2 end]
                }
            }

            "w*" {
                ## windows
                set style backslash
                if {[string index $file 1] == ":"} {
                    set file [string toupper $file 0]
                }
            }
        }

        switch -glob -- $style {
            "f*" {
                ## forward
                set file [string map [list \\ /] $file]
            }

            "b*" {
                ## backward
                set file [string map [list / \\] $file]
            }
        }
    }

    return $file
}

proc ::InstallJammer::RelativeFile { file {relativeDir "<%InstallDir%>"} } {
    if {[file pathtype $file] eq "relative"} {
        set file [::InstallJammer::SubstText "$relativeDir/$file"]
    }
    return [::InstallJammer::Normalize $file]
}

proc ::InstallJammer::RollbackName { file } {
    global info
    return [file join [file dirname $file] .$info(InstallID).[file tail $file]]
}

proc ::InstallJammer::SaveForRollback {file} {
    file rename -force $file [::InstallJammer::RollbackName $file]
}

proc ::InstallJammer::GetShellFolder { folder } {
    set folder [string toupper $folder]
    array set map {DESKTOP DESKTOPDIRECTORY MYDOCUMENTS PERSONAL}
    if {[info exists map($folder)]} { set folder $map($folder) }
    if {[catch {twapi::get_shell_folder csidl_[string tolower $folder]} path]} {
        return [installkit::Windows::getFolder $folder]
    }
    return $path
}

proc ::InstallJammer::WindowsDir { dir } {
    set dir [string toupper $dir]

    ## We can't trust the WINDOWS directory on some systems apparently,
    ## so it's safer to trust the windir or SYSTEMROOT environment variables.
    if {$dir eq "WINDOWS"
        || [catch { ::InstallJammer::GetShellFolder $dir } windir]} {
        set windir ""
    }

    if {$windir ne ""} { return [::InstallJammer::Normalize $windir windows] }

    ## We couldn't find the directory they were looking for.
    ## See if we can give them something.

    if {[string match "COMMON_*" $dir]} {
        ## Windows 9x doesn't support COMMON_* directories, so let's
        ## see if we can give them the normal one.
        set chk [string range $dir 7 end]
        if {[catch { ::installkit::Windows::getFolder $chk } windir]} {
            set windir ""
        }
        if {[string length $windir]} {
            return [::InstallJammer::Normalize $windir windows]
        }
    }

    set curr {Software\Microsoft\Windows\CurrentVersion}
    set key  "HKEY_LOCAL_MACHINE\\$curr"

    switch -- $dir {
	"MYDOCUMENTS" {
	    set windir [::InstallJammer::WindowsDir PERSONAL]
	}

	"WINDOWS" {
	    if {[info exists ::env(SYSTEMROOT)]} {
		set windir $::env(SYSTEMROOT)
            } elseif {[info exists ::env(windir)]} {
		set windir $::env(windir)
	    } elseif {![catch {registry get $key SystemRoot} result]} {
		set windir $result
	    } else {
		set windir "C:\\Windows"
	    }
	}

	"PROGRAM_FILES" {
	    if {[info exists ::env(ProgramFiles)]} {
		set windir $::env(ProgramFiles)
	    } elseif {![catch {registry get $key ProgramFilesDir} result]} {
		set windir $result
	    } else {
		set windir "C:\\Program Files"
	    }
	}

	"SYSTEM" {
	    set windir [file join [WindowsDir WINDOWS] system]
	}

	"SYSTEM32" {
	    set windir [file join [WindowsDir WINDOWS] system32]
	}

	"QUICK_LAUNCH" {
	    set windir [WindowsDir APPDATA]
	    set windir [file join $windir \
	    	"Microsoft" "Internet Explorer" "Quick Launch"]
	}

	"COMMON_QUICK_LAUNCH" {
	    set windir [WindowsDir COMMON_APPDATA]
	    set windir [file join $windir \
	    	"Microsoft" "Internet Explorer" "Quick Launch"]
	}

	"WALLPAPER" {
	    set windir [registry get $key WallPaperDir]
	}

	default {
            ## We couldn't find the directory.  Let's try one more
            ## time by looking through the known registry values.

            array set regkeys {
                ADMINTOOLS        {USER "Administrative Tools"}
                APPDATA           {USER AppData}
                CACHE             {USER Cache}
                CDBURN_AREA       {USER "CD Burning"}
                COOKIES           {USER Cookies}
                DESKTOP           {USER Desktop}
                FAVORITES         {USER Favorites}
                FONTS             {USER Fonts}
                HISTORY           {USER History}
                INTERNET_CACHE    {USER Cache}
                LOCAL_APPDATA     {USER "Local AppData"}
                LOCAL_SETTINGS    {USER "Local Settings"}
                MYDOCUMENTS       {USER Personal}
                MYMUSIC           {USER "My Music"}
                MYPICTURES        {USER "My Pictures"}
                MYVIDEO           {USER "My Video"}
                NETHOOD           {USER NetHood}
                PERSONAL          {USER Personal}
                PRINTHOOD         {USER PrintHood}
                PROGRAMS          {USER Programs}
                RECENT            {USER Recent}
                SENDTO            {USER SendTo}
                STARTMENU         {USER "Start Menu"}
                STARTUP           {USER Startup}
                TEMPLATES         {USER Templates}

                COMMON_ADMINTOOLS {SYS "Common Administrative Tools"}
                COMMON_APPDATA    {SYS "Common AppData"}
                COMMON_DESKTOP    {SYS "Common Desktop"}
                COMMON_DOCUMENTS  {SYS "Common Documents"}
                COMMON_FAVORITES  {SYS "Common Favorites"}
                COMMON_MUSIC      {SYS CommonMusic}
                COMMON_PICTURES   {SYS CommonPictures}
                COMMON_PROGRAMS   {SYS "Common Programs"}
                COMMON_STARTMENU  {SYS "Common Start Menu"}
                COMMON_STARTUP    {SYS "Common Startup"}
                COMMON_TEMPLATES  {SYS "Common Templates"}
                COMMON_VIDEO      {SYS CommonVideo}
            }

            set SYS  "HKEY_LOCAL_MACHINE\\$curr\\Explorer\\Shell Folders"
            set USER "HKEY_CURRENT_USER\\$curr\\Explorer\\Shell Folders"

            if {[info exists regkeys($dir)]} {
                upvar 0 [lindex $regkeys($dir) 0] regkey
                set val [lindex $regkeys($dir) 1]
                set windir [::installkit::Windows::GetKey $regkey $val]
            }

            ## We still found nothing.  Return the virtual text string.
            if {$windir eq ""} { return <%$dir%> }
	}
    }

    return [::InstallJammer::Normalize $windir windows]
}

proc ::InstallJammer::SetupRegVirtualText {} {
    global info

    set env        {HKEY_LOCAL_MACHINE}
    set user       {HKEY_CURRENT_USER}
    set current    {HKEY_LOCAL_MACHINE}
    append env     {\SYSTEM\CurrentControlSet\Control\Session Manager}
    append current {\Software\Microsoft\Windows\CurrentVersion}

    set info(REG_USER_ENV)        "$user\\Environment"
    set info(REG_SYSTEM_ENV)      "$env\\Environment"
    set info(REG_UNINSTALL)       "$current\\Uninstall"
    set info(REG_CURRENT_VERSION) "$current"

    return
}

proc ::InstallJammer::SetWindowsPlatform {} {
    global conf
    global info

    set string Windows

    if {$conf(windows)} {
        switch -- $::tcl_platform(os) {
            "Windows 95" { set string "Win95" }
            "Windows 98" { set string "Win98" }
            "Windows NT" {
                switch -- $::tcl_platform(osVersion) {
                    "4.0" { set string "WinNT" }
                    "4.9" { set string "WinME" }
                    "5.0" { set string "Win2k" }
                    "5.1" { set string "WinXP" }
                    "5.2" { set string "Win2003" }
                    "6.0" { set string "Vista" }
                    "6.1" { set string "Windows7" }
                }
            }
        }
    }

    set info(WindowsPlatform) $string
}

proc ::InstallJammer::SubstVar { var } {
    global conf
    global info

    ## If this variable exists in the info array, return its value.
    if {[info exists info($var)]} {
	set string $info($var)
        if {[info exists ::InstallJammer::VTTypes($var)]} {
            if {$::InstallJammer::VTTypes($var) eq "boolean"} {
                set string [string is true $string]
            } elseif {$::InstallJammer::VTTypes($var) eq "directory"} {
                set string [::InstallJammer::Normalize $string platform]
            }
	}
   	return $string
    }

    ## See if this is a virtual text variable that exists in
    ## our message catalog.  If it does, we want to use the
    ## language-specific version instead of a generic.
    if {[::msgcat::mcexists $var]} { return [::msgcat::mc $var] }

    if {![info exists ::InstallJammer::subst]} {
        foreach proc [info commands ::InstallJammer::subst::*] {
            set ::InstallJammer::subst([namespace tail $proc]) $proc
        }
    }

    set idx  [string wordend $var 0]
    set word [string range $var 0 [expr {$idx - 1}]]
    set args [string trim [string range $var $idx end]]

    if {[info exists ::InstallJammer::subst($word)]} {
        return [eval ::InstallJammer::subst::$word $args]
    }

    if {$var ne "" && $var eq [string toupper $var]} {
        ## If the string is all uppercase and we haven't matched
        ## something yet, it's a Windows directory.
        return [::InstallJammer::WindowsDir $var]
    }

    return "<%$var%>"
}

proc ::InstallJammer::subst::Date { args } {
    set secs [lindex $args 0]
    if {[string is integer -strict $secs]} {
        set format [join [lrange $args 1 end]]
    } else {
        set secs   [clock seconds]
        set format [join $args]
    }

    return [clock format $secs -format $format]
}

proc ::InstallJammer::subst::Dir { args } {
    set dir      [lindex $args 0]
    set platform [lindex $args 1]
    if {$platform eq ""} { set platform $::tcl_platform(platform) }
    return [::InstallJammer::Normalize $dir $platform]
}

proc ::InstallJammer::subst::Dirname { args } {
    return [file dirname [join $args]]
}

proc ::InstallJammer::subst::DiskSpace { args } {
    return [::InstallJammer::FormatDiskSpace [join $args]]
}

proc ::InstallJammer::subst::DOSName { args } {
    global conf

    set file [join $args]

    if {$conf(windows) && [file exists $file]} { 
        set file [file attributes $file -shortname]
        set file [::InstallJammer::Normalize $file windows]
    }

    return $file
}

proc ::InstallJammer::subst::Env { args } {
    set var [lindex $args 0]
    if {[info exists ::env($var)]} { return $::env($var) }
}

proc ::InstallJammer::subst::FileGroup { args } {
    set group [join $args]
    set obj [::InstallJammer::FindObjByName $group [FileGroups children]]
    if {$obj ne ""} {
        set str [$obj directory]
        set str [::InstallJammer::Normalize $str $::tcl_platform(platform)]
        return $str
    }
}

proc ::InstallJammer::subst::FormatDescription { args } {
    set lines  [join $args]
    set string ""
    foreach line [split [string trim $lines] \n] {
        if {[string trim $line] eq ""} { set line "." }
        append string " $line\n"
    }
    return $string
}

proc ::InstallJammer::subst::GUID { args } {
    global info
    set info(LastGUID) [::InstallJammer::guid]
    return $info(LastGUID)
}

proc ::InstallJammer::subst::InstallInfoDir { args } {
    return [::InstallJammer::InstallInfoDir]
}

proc ::InstallJammer::subst::Property { args } {
    set property [lindex $args end]
    if {[llength $args] == 1} {
        set object [::InstallJammer::CurrentObject]
    } else {
        set object [::InstallJammer::ID [lindex $args 0]]
    }

    return [$object get $property]
}

proc ::InstallJammer::subst::RegValue { args } {
    set key  [lindex $args 0]
    set val  [lindex $args 1]
    return [::installkit::Windows::GetKey $key $val]
}

proc ::InstallJammer::subst::SpaceAvailable { args } {
    global info
    set dir [join $args]
    if {$dir eq ""} { set dir $info(InstallDir) }
    return [::InstallJammer::GetFreeDiskSpace $dir]
}

proc ::InstallJammer::subst::Tail { args } {
    return [file tail [join $args]]
}

proc ::InstallJammer::subst::Temp { args } {
    return [::InstallJammer::TmpDir]
}

proc ::InstallJammer::subst::Tolower { args } {
    return [string tolower $args]
}

proc ::InstallJammer::subst::Toupper { args } {
    return [string toupper $args]
}

proc ::InstallJammer::subst::UUID { args } {
    global info
    set info(LastUUID) [::InstallJammer::uuid]
    return $info(LastUUID)
}

proc ::InstallJammer::SubstForEval { string } {
    set map [list "<%" "\[::InstallJammer::SubstText \{<%" "%>" "%>\}\]"]
    return [string map $map $string]
}

proc ::InstallJammer::SubstForPipe { string } {
    set list [list]
    foreach arg $string {
        lappend list [::InstallJammer::SubstText $arg]
    }
    return $list
}

proc ::InstallJammer::SubstText { str {num 0} } {
    global conf

    if {$num > $conf(VirtualTextRecursionLimit)} { return $str }

    if {$str eq ""} { return }

    set s $str
    set s [string map $conf(VirtualTextMap) $s]
    set s [subst -novariables $s]
    if {$str ne $s} { set s [::InstallJammer::SubstText $s [incr num]] }

    return $s
}
interp alias {} sub {} ::InstallJammer::SubstText

proc settext {var val} {
    set ::info($var) $val
}

proc getobj {text} {
    if {[info exists ::InstallJammer::aliases($text)]} {
        return $::InstallJammer::aliases($text)
    } elseif {[info exists ::InstallJammer::names($text)]} {
        return $::InstallJammer::names($text)
    }
}

proc vercmp {ver1 ver2} {
    foreach v1 [split $ver1 ._-] v2 [split $ver2 ._-] {
        if {$v1 eq ""} { set v1 0 }
        if {$v2 eq ""} { set v2 0 }
        if {$v1 < $v2} { return -1 }
        if {$v1 > $v2} { return 1 }
    }
    return 0
}

proc ::InstallJammer::HasVirtualText { string } {
    return [string match "*<%*%>*" $string]
}

proc ::InstallJammer::TmpDir { {file ""} } {
    global conf
    global info

    if {![info exists info(TempRoot)] || ![file exists $info(TempRoot)]} {
        set dirs [list]
	if {[info exists ::env(TEMP)]} { lappend dirs $::env(TEMP) }
	if {[info exists ::env(TMP)]}  { lappend dirs $::env(TMP)  }
        if {$conf(windows)} {
            set local [::InstallJammer::WindowsDir LOCAL_APPDATA]
            lappend dirs [file join [file dirname $local] Temp]

            lappend dirs [::InstallJammer::WindowsDir INTERNET_CACHE]

	    lappend dirs C:/Windows/Temp
	    lappend dirs C:/WINNT/Temp
            lappend dirs C:/Temp

	} else {
	    lappend dirs /tmp /usr/tmp /var/tmp
	}

	foreach dir $dirs {
	    if {[DirIsWritable $dir]} {
                if {[info exists ::InstallJammer]} {
                    if {$file ne ""} { set dir [file join $dir $file] }
                    return $dir
                }
                set info(TempRoot) [::InstallJammer::Normalize $dir forward]
                break
            }
        }

        if {![info exists info(TempRoot)]} {
            if {[info exists ::env(TMP)]} { set tmp $::env(TMP) }
            if {[info exists ::env(TEMP)]} { set tmp $::env(TEMP) }
            if {![info exists tmp] || [catch {file mkdir $tmp}]} {
                return -code error \
                    "could not find a suitable temporary directory"
            }
            set info(TempRoot) $tmp
        }
    }

    if {![info exists info(Temp)]} {
        set info(Temp) [::InstallJammer::Normalize \
            [file join $info(TempRoot) ijtmp_[::InstallJammer::uuid]]]
    }

    if {![file exists $info(Temp)]} { file mkdir $info(Temp) }

    if {$file ne ""} {
	return [::InstallJammer::Normalize [file join $info(Temp) $file]]
    }

    return $info(Temp)
}

proc ::InstallJammer::TmpFile {} {
    global conf
    return [::InstallJammer::TmpDir [pid]-[incr0 conf(tmpFileCount)]]
}

proc ::InstallJammer::TmpMount {} {
    variable tmpMountCount

    if {![info exists tmpMountCount]} { set tmpMountCount 0 }

    while {1} {
        set mnt /installjammervfs[incr tmpMountCount]
        if {![file exists $mnt]} { break }
    }

    return $mnt
}

proc ::InstallJammer::ModifyInstallDir {} {
    global conf
    global info

    set dir [::InstallJammer::SubstText $info(InstallDir)]

    if {[info exists info(InstallDirSuffix)]} {
        set suf [::InstallJammer::SubstText $info(InstallDirSuffix)]

        set dir [::InstallJammer::Normalize $dir forward]
        set suf [::InstallJammer::Normalize $suf forward]
        if {![string match "*$suf" $dir]} { set dir [file join $dir $suf] }
    }

    if {[file pathtype $dir] eq "relative"} { set dir [file normalize $dir] }

    set info(InstallDir) [::InstallJammer::Normalize $dir platform]

    if {$conf(windows)} {
        set info(InstallDrive) [string range $info(InstallDir) 0 1]
    }
}

proc ::InstallJammer::ModifyInstallTitle {} {
    if {[info exists ::tk_patchLevel]} {
        set title [::InstallJammer::SubstText "<%InstallTitleText%>"]
        wm title . $title
        if {[info exists ::info(Wizard)] && [winfo exists $::info(Wizard)]} {
            $::info(Wizard) configure -title $title
        }
    }
}

proc ::InstallJammer::GetInstallInfoDir { {create 0} } {
    global conf
    global info

    if {![info exists info(InstallJammerRegistryDir)]} {
        if {$conf(windows)} {
            set root [::InstallJammer::WindowsDir PROGRAM_FILES]
            if {![::InstallJammer::DirIsWritable $root]} {
                ## If the Program Files directory is not writable
                ## it means this user has no permissions on this
                ## system.  We need to store our registry in the
                ## Application Data directory.
                set root [::InstallJammer::WindowsDir APPDATA]
            }

            set dir  [file join $root "InstallJammer Registry"]
        } else {
            if {[id user] eq "root"} {
                set dir "/var/lib/installjammer"
            } else {
                set dir "[::InstallJammer::HomeDir]/.installjammerinfo"
            }
        }

        set info(InstallJammerRegistryDir) [::InstallJammer::Normalize $dir]
    }

    if {![info exists info(InstallInfoDir)]} {
        set id $info(ApplicationID)
        if {[info exists info(UpgradeInstall)] && $info(UpgradeInstall)} {
            set id $info(UpgradeApplicationID)
        }

        set dir [file join $info(InstallJammerRegistryDir) $id]
        set info(InstallInfoDir) [::InstallJammer::Normalize $dir]
    }

    if {$create && ![file exists $info(InstallInfoDir)]} {
        ::InstallJammer::CreateDir $info(InstallInfoDir) 0
        if {$conf(windows)} {
            file attributes [file dirname $info(InstallInfoDir)] -hidden 1
        }
    }

    if {[info exists ::InstallJammer]} {
        set infodir $info(InstallInfoDir)
        unset info(InstallInfoDir) info(InstallJammerRegistryDir)
        return $infodir
    } else {
        return $info(InstallInfoDir)
    }
}

proc ::InstallJammer::InstallInfoDir { {file ""} } {
    set dir [::InstallJammer::GetInstallInfoDir 1]
    if {[string length $file]} { append dir /$file }
    return $dir
}

proc ::InstallJammer::SetPermissions { file perm } {
    if {$perm eq ""} { return }

    if {$::tcl_platform(platform) eq "windows"} {
	if {[string length $perm] > 4} { return }
	lassign [split $perm ""] a h r s
	file attributes $file -archive $a -hidden $h -readonly $r -system $s
    } else {
        file attributes $file -permissions $perm
    }
}

proc ::InstallJammer::WriteDoneFile { {dir ""} } {
    if {$dir eq ""} { set dir [::InstallJammer::TmpDir] }
    close [open [file join $dir .done] w]
}

## This proc attempts to find any InstallJammer temporary directories laying
## around and clean them up.  If a file called .done is in the directory,
## we know the InstallJammer program using that directory has finished with it,
## and it's ok to remove.
proc ::InstallJammer::CleanupTmpDirs {} {
    global info

    if {[string is true -strict $info(Debugging)]} { return }

    set tmp  [file dirname [TmpDir]]
    set time [expr {[clock seconds] - 86400}]
    foreach dir [glob -nocomplain -type d -dir $tmp ijtmp_*] {
        if {[DirIsEmpty $dir]
	    || [file exists [file join $dir .done]]
	    || [file mtime $dir] < $time} {
            catch { file delete -force $dir }
        }
    }
}

proc ::InstallJammer::EvalCondition { condition } {
    if {[string is true  $condition]} { return 1 }
    if {[string is false $condition]} { return 0 }

    set test [::InstallJammer::SubstForEval $condition]

    if {![string length $test]} { return 1 }
    if {[catch {expr [subst $test]} result]} {
        set msg "Error in condition '$condition'\n\n$::errorInfo"
        return -code error $msg
    }
    return $result
}

proc ::InstallJammer::HomeDir { {file ""} } {
    set return [file normalize ~]
    if {$file ne ""} { set return [file join $return $file] }
    return $return
}

proc ::InstallJammer::PauseInstall {} {
    global conf
    if {[info exists conf(pause)]} {
        ::InstallJammer::TmpDir
        close [open $conf(pause) w]
    }
}

proc ::InstallJammer::ContinueInstall {} {
    global conf
    if {[info exists conf(pause)]} { file delete $conf(pause) }
}

proc ::InstallJammer::StopInstall {} {
    global conf
    global info
    if {[info exists conf(stop)]} {
        ::InstallJammer::TmpDir
        close [open $conf(stop) w]
        set info(InstallStopped) 1
    }
}

proc ::InstallJammer::PauseCheck {} {
    global conf
    global info

    if {$info(InstallStopped)} { return 0 }

    while {[file exists $conf(pause)]} {
	if {[file exists $conf(stop)]} {
	    set info(InstallStopped) 1
            return 0
	}
	after 500
    }

    return 1
}

proc ::InstallJammer::UninstallFile {file} {
    file delete -force $file
}

proc ::InstallJammer::UninstallDirectory { dir {force ""} } {
    file delete $force $dir
}

## Uninstall a registry key.  If value is specified, we only want to delete
## that value from the registry key.  If, once the value has been deleted,
## the registry key is empty, we will delete that as well.
proc ::InstallJammer::UninstallRegistryKey {key {value ""}} {
    if {![lempty $value]} {
	catch { registry delete $key $value }
	if {[catch { registry keys $key } keys]} { return }
	if {[catch { registry values $key } values]} { return }
	if {[lempty $keys] && [lempty $values]} {
	    UninstallRegistryKey $key
	}
    } else {
	catch { registry delete $key }
    }
}

proc ::InstallJammer::LogDir { dir } {
    global conf
    global info

    if {!$conf(logInit)} {
        set conf(logInit) 1
        ::InstallJammer::TmpDir
        ::InstallJammer::GetInstallInfoDir
    }

    set dir [::InstallJammer::Normalize $dir forward]
    if {![string match $info(InstallInfoDir)* $dir]
        && ![string match $info(Temp)* $dir]} {
        ::InstallJammer::InstallLog [list :DIR $dir]
    }
}

proc ::InstallJammer::LogFile { file } {
    global conf
    global info

    if {!$conf(logInit)} {
        set conf(logInit) 1
        ::InstallJammer::TmpDir
        ::InstallJammer::GetInstallInfoDir
    }

    set file [::InstallJammer::Normalize $file forward]
    if {![string match $info(InstallInfoDir)* $file]
        && ![string match $info(Temp)* $file]} {
        ::InstallJammer::InstallLog [list :FILE $file]
    }
}

proc ::InstallJammer::SetVersionInfo { file {version ""} } {
    global info
    global versions
    if {$version eq ""} { set version $info(InstallVersion) }
    set versions($file) $version
}

proc ::InstallJammer::StoreLogsInUninstall {} {
    global conf
    global info

    if {[info exists conf(uninstall)]} {
        set tmp [::InstallJammer::TmpDir]

        foreach file [glob -nocomplain -dir $tmp *.info] {
            lappend files $file
            lappend names [file tail $file]

            set file [file root $file].log

            if {[file exists $file]} {
                lappend files $file
                lappend names [file tail $file]
            }
        }

        foreach file [glob -nocomplain -dir $tmp *.dead] {
            lappend files $file
            lappend names [file tail $file]
        }

        installkit::addfiles $conf(uninstall) $files $names
    }
}

proc ::InstallJammer::SetDialogArgs {which arrayName} {
    global conf
    upvar 1 $arrayName _args

    set parent [::InstallJammer::TransientParent]

    set _args(-parent)        $parent
    set _args(-transient)     [expr {$parent ne ""}]
    set _args(-usenative)     $conf(Native$which)
    set _args(-placerelative) [expr {$parent ne "" && $parent ne "."}]
}

proc ::InstallJammer::MessageBox { args } {
    global conf
    global widg

    if {$conf(windows)} { ::InstallJammer::InitializeGui }

    set win  .__message_box

    array set _args {
        -type        "ok"
        -buttonwidth 12
    }
    ::InstallJammer::SetDialogArgs MessageBox _args

    if {[info exists ::InstallJammer]} {
        set _args(-title) "InstallJammer"
    } else {
        set _args(-title) [::InstallJammer::SubstText "<%AppName%>"]
    }

    array set _args $args
    if {$_args(-title) eq ""} { set _args(-title) " " }

    set type $_args(-type)
    if {!$_args(-usenative) && $type ne "user"} {
        set idx 0

        set cancel     -1
        set default    -1
        set buttonlist {Retry OK Yes No Cancel}
        switch -- $type {
            "abortretryignore" {
                set default 0
                set buttonlist {Abort Retry Ignore}
            }

            "ok"          { set default 0 }
            "okcancel"    { set default 0; set cancel 1 }
            "retrycancel" { set default 0; set cancel 1 }
            "yesno"       { set default 0; set cancel 1 }
            "yesnocancel" { set default 0; set cancel 2 }
        }

        if {![info exists _args(-cancel)]} { set _args(-cancel) $cancel }
        if {![info exists _args(-default)]} { set _args(-default) $default }

        foreach button $buttonlist {
            set lbutton [string tolower $button]
            if {[string first $lbutton $type] > -1} {
                lappend buttons $lbutton
                lappend _args(-buttons) [::InstallJammer::SubstText <%$button%>]

                if {[info exists _args(-default)]
                    && $_args(-default) eq $lbutton} {
                    set _args(-default) $idx
                }

                incr idx
            }
        }

        if {[llength $buttons] == 1} { set _args(-default) 0 }

        set _args(-type) user
    }

    set result [eval [list MessageDlg $win] [array get _args]]

    if {!$_args(-usenative) && $type ne "user"} {
        return [lindex $buttons $result]
    }
    return $result
}

proc ::InstallJammer::Message { args } {
    set gui [info exists ::tk_patchLevel]

    if {[info exists ::InstallJammer]
        && $::tcl_platform(platform) eq "windows"
        && [file extension [info nameof]] eq ".com"} { set gui 0 }

    if {$gui} {
        if {[catch { eval ::InstallJammer::MessageBox $args } error]} {
            if {[info exists ::conf(unix)] && $::conf(unix)} {
                catch {rename ::tk_messageBox ""}
            }
            eval tk_messageBox -title "InstallJammer" $args
        }
    } else {
        set _args(-icon) "info"
	array set _args $args
	if {![info exists _args(-message)]} { return }

        set chan stdout
        if {$_args(-icon) eq "error"} { set chan stderr }

        puts  $chan "$_args(-message)"
        flush $chan
    }
}

proc ::InstallJammer::HandleThreadError { tid errorMsg } {
    global info

    set message "Error in thread $tid: $errorMsg"
    if {$info(Installing)} {
        ::InstallJammer::UnpackOutput $message
        ::InstallJammer::UnpackOutput :DONE
    } else {
        ::InstallJammer::MessageBox -message $message
    }
}

proc ::InstallJammer::ChooseDirectory { args } {
    global conf

    ::InstallJammer::SetDialogArgs ChooseDirectory _args

    set _args(-title) \
        [::InstallJammer::SubstText "<%PromptForDirectoryTitle%>"]
    set _args(-message) \
        [::InstallJammer::SubstText "<%PromptForDirectoryMessage%>"]
    set _args(-newfoldertext) \
        [::InstallJammer::SubstText "<%PromptForDirectoryNewFolderText%>"]
    set _args(-oktext)     [::InstallJammer::SubstText "<%OK%>"]
    set _args(-canceltext) [::InstallJammer::SubstText "<%Cancel%>"]
    array set _args $args

    if {[info exists _args(-command)]} {
        set command $_args(-command)
        unset _args(-command)
    }

    if {[info exists _args(-variable)]} {
        upvar 1 $_args(-variable) dir
        unset _args(-variable)

        if {![info exists _args(-initialdir)] && [info exists dir]} {
            set _args(-initialdir) $dir
        }
    }

    if {$_args(-usenative)} {
        set _args(-title) $_args(-message) 
        set res [eval ij_chooseDirectory [array get _args]]
    } else {
        unset -nocomplain _args(-usenative)
        if {[llength $conf(ParentWindow)] > 1} {
            wm withdraw [lindex $conf(ParentWindow) end]
        }

        set res [eval ::ChooseDirectory .__choose_directory [array get _args]]

        if {[llength $conf(ParentWindow)] > 1} {
            wm deiconify [lindex $conf(ParentWindow) end]
        }
    }

    if {$res ne ""} {
        set dir $res
        if {[info exists command]} { uplevel #0 $command }
        return $dir
    }
}

proc ::InstallJammer::ChooseFile { args } {
    global conf

    ::InstallJammer::SetDialogArgs ChooseFile _args
    array set _args $args

    if {[info exists _args(-command)]} {
        set command $_args(-command)
        unset _args(-command)
    }

    if {[info exists _args(-variable)]} {
        upvar 1 $_args(-variable) file
        unset _args(-variable)
    }

    if {$_args(-usenative)} {
        set type Open
        if {[info exists _args(-type)]} {
            set type [string toupper $_args(-type) 0]
        }
        set res [eval [list ij_get${type}File] [array get _args]]
    } else {
        unset -nocomplain _args(-usenative)
        if {[llength $conf(ParentWindow)] > 1} {
            wm withdraw [lindex $conf(ParentWindow) end]
        }

        set res [eval ::ChooseFile .__choose_file [array get _args]]

        if {[llength $conf(ParentWindow)] > 1} {
            wm deiconify [lindex $conf(ParentWindow) end]
        }
    }

    if {$res ne ""} {
        set file $res
        if {[info exists command]} { uplevel #0 $command }
        return $file
    }
}

proc ::InstallJammer::CommandExists { proc } {
    return [string length [info commands $proc]]
}

proc ::InstallJammer::uuid {} {
    global conf

    if {$conf(windows)} {
        return [string range [::InstallJammer::guid] 1 end-1]
    }

    set sha [sha1 -string [info hostname][clock seconds][pid][info cmdcount]]

    set i 0
    foreach x {8 4 4 4 12} {
        lappend list [string range $sha $i [expr {$i + $x - 1}]]
        incr i $x
    }

    return [string toupper [join $list -]]
}

proc ::InstallJammer::guid {} {
    global conf
    if {$conf(windows)} {
        return [string toupper [::installkit::Windows::guid]]
    }
    return \{[string toupper [::InstallJammer::uuid]]\}
}

proc ::InstallJammer::IsID { id } {
    if {[string length $id] != 36} { return 0 }
    set list [split $id -]
    if {[llength $list] != 5} { return 0 }
    set i 0
    foreach n {8 4 4 4 12} {
        if {[string length [lindex $list $i]] != $n} { return 0 }
        incr i
    }
    return 1
}

proc ::InstallJammer::ObjExists { obj } {
    return [info exists ::InstallJammer::ObjMap([namespace tail $obj])]
}

proc ::InstallJammer::ReadMessageCatalog { catalog } {
    set catalog [file join $::installkit::root catalogs $catalog]
    eval [read_textfile $catalog]
}

proc ::InstallJammer::Wrap { args } {
    global conf
    global info

    set include 1
    if {[set x [lsearch -exact $args -noinstall]] > -1} {
        set include 0
        set args [lreplace $args $x $x]
    }

    if {$include} {
        set pkgdir [file join $::installkit::root lib InstallJammer]
        set args [linsert $args 0 -package $pkgdir]
    }

    eval ::installkit::wrap $args
}

proc ::InstallJammer::Grab { command args } {
    variable GrabStack

    if {![info exists GrabStack]} {
        global info
        set GrabStack [list]
        if {[info exists info(Wizard)]} { lappend GrabStack $info(Wizard) }
        bind GrabWindow <Destroy> [list ::InstallJammer::Grab release %W]
    }

    ## Cleanup the stack before we do anything.
    set stack {}
    foreach w $GrabStack {
        if {[winfo exists $w]} { lappend stack $w }
    }
    set GrabStack $stack

    switch -- $command {
        "current" {
            return [grab current]
        }

        "stack" {
            return $GrabStack
        }

        "release" {
            set window [lindex $args 0]
            grab release $window
            set GrabStack [lremove $GrabStack $window]
            if {[llength $GrabStack] && [grab current] eq ""} {
                grab [lindex $GrabStack end]
            }
        }

        "set" {
            set window [lindex $args 0]
            grab $window
            set tags [bindtags $window]
            if {[lsearch -exact $tags GrabWindow] < 0} {
                bindtags $window [concat $tags GrabWindow]
            }
            set x [lsearch -exact $GrabStack $window]
            if {$x > -1} { set GrabStack [lreplace $GrabStack $x $x] }
            lappend GrabStack $window
        }

        default {
            ::InstallJammer::Grab set $command
        }
    }

    return
}

proc ::InstallJammer::HasKDEDesktop {} {
    global info

    set home [::InstallJammer::HomeDir]
    set kde  [file join $home .kde]

    if {![file exists $kde]} { return 0 }

    if {![info exists info(KDEDesktop)] || [lempty $info(KDEDesktop)]} {
	set globals [file join $kde share config kdeglobals]
	set desktop [file join $home Desktop]
	if {[catch {open $globals} fp]} { return 0 }
	while {[gets $fp line] != -1} {
	    if {[regexp {^Desktop=([^\n].*)\n} $line\n trash desktop]} {
		regsub -all {\$([A-Za-z0-9]+)} $desktop {$::env(\1)} desktop
		break
	    }
	}
	close $fp
	set info(KDEDesktop) $desktop
    }

    return [file exists $info(KDEDesktop)]
}

proc ::InstallJammer::HasGnomeDesktop {} {
    global info

    set home [::InstallJammer::HomeDir]

    foreach dir [list .gnome-desktop Desktop] {
        set desktop [file join $home $dir]
        if {[file exists $desktop]} {
            set info(GnomeDesktop) $desktop
            break
        }
    }

    if {[info exists info(GnomeDesktop)] && [file exists $info(GnomeDesktop)]} {
        return 1
    }
    return 0
}

proc ::InstallJammer::GetDesktopEnvironment {} {
    global env

    ## KDE
    if {[info exists env(DESKTOP)] && $env(DESKTOP) eq "kde"} { return KDE }
    if {[info exists env(KDE_FULL_SESSION)]} { return KDE }

    ## Gnome
    if {[info exists env(GNOME_DESKTOP_SESSION_ID)]} { return Gnome }

    if {[info exists env(DESKTOP_SESSION)]} {
        switch -glob -- $env(DESKTOP_SESSION) {
            "*KDE*"   { return KDE }
            "*GNOME*" { return Gnome }
        }
    }

    return "Unknown"
}

proc ::InstallJammer::GetLinuxDistribution {} {
    set lsb_release [auto_execok lsb_release]
    if {[file executable $lsb_release]} {
        if {![catch { exec $lsb_release -i -s } distrib]} { return $distrib }
    }

    foreach lsb_release [list /etc/lsb-release /etc/lsb_release] {
	if {[file readable $lsb_release]} {

	}
    }

    set check {
	/etc/mandrake-release    Mandrake
	/etc/fedora-release      Fedora
	/etc/SuSE-release        SuSE
	/etc/debian_version      Debian
	/etc/gentoo-release      Gentoo
	/etc/slackware-version   Slackware
	/etc/turbolinux-release  TurboLinux
	/etc/yellowdog-release   YellowDog
	/etc/connectiva-release  Connectiva
	/etc/redhat-release      Redhat
    }
}

proc ::InstallJammer::GetFreeDiskSpace { dir } {
    global conf

    if {$conf(windows)} {
        set drive [lindex [file split $dir] 0]
        return [::installkit::Windows::drive freespace $drive]
    }

    set df [auto_execok df]
    if {[file exists $df]} {
        while {![file exists $dir]} {
            set dir [file dirname $dir]
        }
        catch { exec $df -k $dir } output

        set line [join [lrange [split $output \n] 1 end] " "]
        if {![catch { expr {[lindex $line 3] * wide(1024)} } avail]} {
            return $avail
        }
    }

    return -1
}

proc ::InstallJammer::FormatDiskSpace { space } {
    if {$space < 1048576} {
        return [format "%2.2f KB" [expr {$space / 1024.0}]]
    }
    if {$space < 1073741824} {
        return [format "%2.2f MB" [expr {$space / 1048576.0}]]
    }
    return [format "%2.2f GB" [expr {$space / 1073741824.0}]]
}

proc ::InstallJammer::unpack { src dest {permissions ""} } {
    if {![string length $permissions]} { set permissions "0666" }

    # Extract the file and copy it to its location.
    set fin [open $src r]
    if {[catch {open $dest w $permissions} fout]} {
	close $fin
	return -code error $fout
    }

    set intrans  binary
    set outtrans binary
    if {[info exists ::conf(eol,[file extension $dest])]} {
        set trans $::conf(eol,[file extension $dest])
        if {[llength $trans] == 2} {
            set intrans  [lindex $trans 0]
            set outtrans [lindex $trans 1]
        } else {
            set outtrans [lindex $trans 0]
        }
    }

    fconfigure $fin  -translation $intrans
    fconfigure $fout -translation $outtrans

    fcopy $fin $fout

    close $fin
    close $fout
}

proc ::InstallJammer::ExecAsRoot { command args } {
    global conf
    global info

    array set _args {
        -title   ""
        -message "<%PromptForRootText%>"
    }
    array set _args $args

    set wait 0
    if {[info exists _args(-wait)]} { set wait $_args(-wait) }

    set cmd   [list]
    set msg   [sub $_args(-message)]
    set title [sub $_args(-title)]

    set i 0
    set x [llength $command]
    foreach arg $command {
        if {[string first " " $arg] > -1} {
            append cmdline '$arg'
        } else {
            append cmdline $arg
        }
        if {[incr i] < $x} { append cmdline " " }
    }

    if {$info(GuiMode)} {
        ## Try to find a graphical SU utility we can use.
        if {[::InstallJammer::GetDesktopEnvironment] eq "Gnome"} {
            set list {gksudo gksu gnomesu kdesudo kdesu xsu}
        } else {
            set list {kdesudo kdesu gksudo gksu gnomesu xsu}
        }

        foreach app $list {
            if {[auto_execok $app] eq ""} { continue }
            
            set cmd [list $app $cmdline]
            catch {exec $app --help} help
            if {$app eq "kdesu" || $app eq "kdesudo"} {
                set cmd [linsert $cmd 1 -d -c]
                if {$msg ne "" && [string match "*--comment*" $help]} {
                    set cmd [linsert $cmd 1 --comment $msg]
                }
            } elseif {$app eq "gksu" || $app eq "gksudo"} {
                if {$msg ne "" && [string match "*--message*" $help]} {
                    set cmd [linsert $cmd 1 --message $msg]
                }
            }

            if {!$wait} { lappend cmd & }
            catch { eval exec $cmd }
            return 1
        }
    }

    ## If we didn't find a GUI we could use, and we don't have a
    ## terminal to talk to, we really can't do anything.
    if {!$info(HaveTerminal)} { return 0 }

    ## We never found a good GUI to ask for the root password,
    ## so we'll just ask on the command line.

    if {[string is punct [string index $msg end]]} {
        set msg [string range $msg 0 end-1]
    }

    if {[auto_execok sudo] ne ""} {
        ## Always invalidate the sudo timestamp.  We don't want
        ## someone running an installer as root without knowing it.
        if {[catch {exec sudo -k} err]} { return 0 }

        set cmd [list sudo]
        if {$msg ne ""} { lappend cmd -p "\[sudo\] $msg: " }
        if {$wait} {
            eval exec $cmd $command
        } else {
            if {[catch {eval exec $cmd -v} err]} { return 0 }
            set res [catch {eval system sudo $cmdline &} err]
        }
    } else {
        puts  stdout "$msg\n\[su root\] "
        flush stdout
        if {!$wait} { append cmdline " &" }
        set res [system su -c \"$cmdline\"]
    }

    return 1
}

proc ::InstallJammer::GetFilesForPattern { patternString args } {
    set relative    1
    set patterns    [list]
    set installdir  [::InstallJammer::SubstText <%InstallDir%>]
    set patternlist [split [::InstallJammer::SubstText $patternString] \;]

    foreach pattern $patternlist {
        set pattern [string trim [::InstallJammer::SubstText $pattern]]
        if {$pattern eq ""} { continue }

        if {[file pathtype $pattern] ne "relative"} {
            set relative 0
            set pattern [::InstallJammer::Normalize $pattern]
        }

        lappend patterns $pattern
    }

    if {![llength $patterns]} { return }

    if {$relative} {
        ## All of our patterns are relative, so we can do a single, quick
        ## glob to find everything relative to the <%InstallDir%>.
        set opts $args
        lappend opts -dir $installdir

        set files [eval glob -nocomplain $opts $patterns]
    } else {
        set files [list]
        foreach pattern $patterns {
            set opts $args
            if {[file pathtype $pattern] eq "relative"} {
                lappend opts -dir $installdir
            }
            eval lappend files [eval glob -nocomplain $opts [list $pattern]]
        }
    }

    return $files
}

proc ::InstallJammer::StartProgress { varName total {current 0} } {
    global conf
    set conf(ProgressCurr)    0
    set conf(ProgressLast)    0
    set conf(ProgressTotal)   $total
    set conf(ProgressVarName) $varName
}

proc ::InstallJammer::ResetProgress {} {
    global conf
    set conf(ProgressLast) 0
}

proc ::InstallJammer::UpdateProgress { args } {
    set total   $::conf(ProgressTotal)
    set varName $::conf(ProgressVarName)
    set current [lindex $args end]

    set bytes [expr {$current - $::conf(ProgressLast)}]
    set ::conf(ProgressLast) $current

    incr ::conf(ProgressCurr) $bytes

    if {$varName ne ""} {
        set $varName [expr {round( ($::conf(ProgressCurr) * 100.0) / $total )}]
    }
}

proc ::InstallJammer::ReadProperties { data arrayName } {
    upvar 1 $arrayName array

    foreach line [split [string trim $data] \n] {
        set line [string trim $line]
        if {[set x [string first : $line]] >= 0} {
            set var [string trim [string range $line 0 [expr {$x-1}]]]
            set val [string trim [string range $line [expr {$x+1}] end]]
            set array($var) $val
        }
    }
}

proc ::InstallJammer::ReadPropertyFile { file arrayName } {
    upvar 1 $arrayName array
    ::InstallJammer::ReadProperties [read_textfile $file] array
}

proc ::InstallJammer::ShowUsageAndExit { {message ""} {title ""} } {
    global conf
    global info

    variable ::InstallJammer::CommandLineOptions

    ::InstallJammer::InitializeCommandLineOptions

    set head --
    if {$conf(windows)} { set head / }

    set usage ""

    if {$message ne ""} { append usage "$message\n\n" }
    append usage "Usage: [file tail [info nameofexecutable]] \[options ...\]"
    append usage "\n\nAvailable Options:"

    set len 0
    foreach option [array names CommandLineOptions] {
        if {$option eq "PREFIX"} { continue }

        lassign $CommandLineOptions($option) name var type x hide values desc

        if {$type eq "Boolean"} {
            set desc "$name <Yes or No>"
        } elseif {$type eq "Prefix"} {
            set desc "$name<OPTION> \[ARG\]"
        } elseif {$type eq "Switch"} {
            set desc $name
        } else {
            set desc "$name \[ARG\]"
        }

        set options($option) $desc

        if {[string length $desc] > $len} {
            set len [string length $desc]
        }
    }

    incr len 4
    set  pad [expr {$len + 3}]

    foreach option [lsort -dict [array names options]] {
        lassign $CommandLineOptions($option) name var type x hide values desc

        if {$hide} { continue }

        set desc   [::InstallJammer::SubstText $desc]
        set values [::InstallJammer::SubstText $values]

        set line "  [format %-${len}s $head$options($option)] $desc"

        append usage "\n[::InstallJammer::WrapText $line 0 $pad]"

        if {$type eq "Choice"} {
            set values  [lsort -dict $values]
            set last    [lindex $values end]
            set values  [lrange $values 0 end-1]
            set choices [string tolower "[join $values ", "] or $last"]

            set line "[string repeat " " $pad]Available values: $choices"
            append usage "\n[::InstallJammer::WrapLine $line 0 $pad]"
        }
    }

    append usage \n

    if {$conf(windows) || !$info(HaveTerminal)} {
        if {$title eq ""} { set title "Invalid Arguments" }
        ::InstallJammer::MessageBox -icon error -font "Courier 8" \
            -title $title -message $usage
    } else {
        puts $usage
    }

    ::exit [expr {$message eq "" ? 0 : 1}]
}

proc ::InstallJammer::ParseCommandLineArguments { argv } {
    global conf
    global info

    variable ::InstallJammer::CommandLineOptions
    variable ::InstallJammer::PassedCommandLineOptions
    variable ::InstallJammer::VirtualTextSetByCommandLine

    ::InstallJammer::ExecuteActions "Command Line Actions"

    ::InstallJammer::InitializeCommandLineOptions

    set i 0
    foreach arg $argv {
        if {[string tolower [string trimleft $arg -/]] eq "response-file"} {
            ::InstallAPI::ResponseFileAPI -do read -file [lindex $argv [incr i]]
            break
        }
        incr i
    }

    set len [llength $argv]
    for {set i 0} {$i < $len} {incr i} {
        set arg [lindex $argv $i]
        set opt [string tolower [string trimleft $arg -/]]

        ## The first argument of argv can be the name of our
        ## executable, so we need to check and skip it.
        if {$i == 0 && [file normalize $arg] eq [file normalize [info name]]} {
            continue
        }

        if {$opt eq "help" || $opt eq "?"} {
            ::InstallJammer::ShowUsageAndExit "" "Help"
        }

        if {$opt eq "v" || $opt eq "version"} {
            set message "InstallJammer Installer version $conf(version)\n\n"
            if {$info(RunningInstaller)} {
                append message "<%VersionHelpText%>"
            } else {
                append message "<%AppName%> <%Version%>"
            }

            if {$conf(windows)} {
                ::InstallJammer::MessageBox -default ok \
                    -title "InstallJammer Installer" -message [sub $message]
            } else {
                puts [sub "<%Version%> (<%InstallVersion%>)"]
                puts ""
                puts [sub $message]
            }

            ::exit 0
        }

        if {![info exists CommandLineOptions($opt)]} {
            set found 0

            if {[info exists CommandLineOptions(PREFIX)]} {
                foreach prefix $CommandLineOptions(PREFIX) {
                    if {[string match -nocase $prefix* $opt]} {
                        set found 1

                        set opt       [string trimleft $arg -/]
                        set xlen      [string length $prefix]
                        set prefixopt [string range $opt $xlen end]

                        set opt $prefix
                        break
                    }
                }
            }

            if {!$found} {
                ::InstallJammer::ShowUsageAndExit "invalid option '$arg'"
                return
            }
        }

        lassign $CommandLineOptions($opt) name var type debug hide value desc
        set choices [::InstallJammer::SubstText $value]

        if {$type eq "Switch"} {
            if {$value eq ""} {
                set val 1
            } else {
                set val $value
            }
        } else {
            if {[incr i] == $len} {
                ## Option without an argument.
                ::InstallJammer::ShowUsageAndExit \
                    "no argument given for option '$arg'"
            }

            set val [lindex $argv $i]

            if {$type eq "Choice"} {
                set val  [string tolower $val]
                set vals [string tolower $choices]
                if {[set x [lsearch -exact $vals $val]] < 0} {
                    ::InstallJammer::ShowUsageAndExit \
                        "invalid value given for option '$arg'"
                }

                set val [lindex $choices $x]
            } elseif {$type eq "Boolean"} {
                if {![string is boolean -strict $val]} {
                    ::InstallJammer::ShowUsageAndExit \
                        "invalid value given for option '$arg'"
                }

                if {$value ne ""} {
                    if {[string is true $val]} {
                        set val [lindex $value 0]
                    } else {
                        set val [lindex $value 1]
                    }
                }
            } elseif {$type eq "Prefix"} {
                if {![info exists prefixopt]}  {
                    ::InstallJammer::ShowUsageAndExit \
                        "no option specified for '$arg'"
                }

                set suffix $prefixopt

                if {$value ne ""} {
                    set opt     [string tolower $prefixopt]
                    set choices [string tolower $choices]
                    if {[set x [lsearch -exact $choices $opt]] < 0} {
                        ::InstallJammer::ShowUsageAndExit \
                            "invalid option '$prefixopt'"
                    }

                    set suffix [lindex $value $x]
                }

                append var $suffix
            }
        }

        set info($var) $val
        set PassedCommandLineOptions($opt) $val
        set VirtualTextSetByCommandLine($var) $val
    }

    ::InstallJammer::SetupModeVariables

    ::InstallJammer::ExecuteActions "Setup Actions"

    if {$info(ShowConsole)} {
        ::InstallJammer::InitializeGui
        if {!$conf(windows)} { SourceCachedFile console.tcl }
        console show
        debugging on
    }

    if {!$info(GuiMode) && !$conf(windows)} {
        if {![catch { exec stty size } result]
            && [scan $result "%d %d" height width] == 2} {
            set conf(ConsoleWidth)  $width
            set conf(ConsoleHeight) $height
        }
    }
}

proc ::InstallJammer::SetupModeVariables {} {
    global conf
    global info

    ## If the command-line arguments have given us a mode that
    ## doesn't exist in our list of possible modes, use whatever
    ## the default mode is (Standard).
    if {[lsearch -exact $conf(modes) $info($conf(mode))] < 0} {
        set mode [lindex $conf(modes) 0]
        debug "Bad $conf(mode) \"$info($conf(mode))\": using $mode mode"
        set info($conf(mode)) $mode
    }

    set mode $info($conf(mode))
    set info(GuiMode)     [expr {$mode eq "Default" || $mode eq "Standard"}]
    set info(SilentMode)  [string equal $mode "Silent"]
    set info(DefaultMode) [string equal $mode "Default"]
    set info(ConsoleMode) [string equal $mode "Console"]
}

proc ::InstallJammer::CommonExit { {cleanupTmp 1} } {
    global conf

    catch { 
        if {$conf(windows) && $conf(UpdateWindowsRegistry)} {
            registry broadcast Environment -timeout 1
        }
    }

    catch {
        if {$conf(RestartGnomePanel)
            && [::InstallJammer::GetDesktopEnvironment] eq "Gnome"} {
            set pid [::InstallAPI::FindProcesses -name gnome-panel]
            if {$pid ne ""} { catch {exec kill -HUP $pid} }
        }
    }

    catch { ::InstallJammer::ExecuteActions "Exit Actions" }

    catch {
        foreach chan [file channels] {
            if {[string match "std*" $chan]} { continue }
            catch {close $chan}
        }
    }

    if {$cleanupTmp} {
        catch {
            ::InstallJammer::WriteDoneFile
            ::InstallJammer::CleanupTmpDirs
        }
    }

    if {[info exists ::debugfp]} { catch { close $::debugfp } }
}

proc ::InstallJammer::WrapText { string {width 0} {start 0} } {
    global conf

    if {$width == 0} { set width $conf(ConsoleWidth) }

    set splitstring {}
    foreach line [split $string "\n"] {
	lappend splitstring [::InstallJammer::WrapLine $line $width $start]
    }
    return [join $splitstring "\n"]
}

proc ::InstallJammer::WrapLine { line {width 0} {start 0} } {
    global conf

    if {$width == 0} { set width $conf(ConsoleWidth) }

    set slen  0
    set words [split $line " "]
    set line  [lindex $words 0]
    set lines [list]
    foreach word [lrange $words 1 end] {
	if {[string length $line] + [string length " $word"] > $width} {
	    lappend lines $line

            set slen $start
	    set line [string repeat " " $slen]$word
	} else {
            append line " $word"
        }
    }

    if {$line ne ""} { lappend lines $line }

    return [join $lines "\n"]
}

proc ::InstallJammer::DisplayConditionFailure { id } {
    set string [::InstallJammer::SubstText [$id get FailureMessage]]
    set list   [split $string |]

    set icon    ""
    set title   ""
    set message [string trim $string]

    if {[llength $list] == 2} {
        set title   [string trim [lindex $list 0]]
        set message [string trim [lindex $list 1]]
    } elseif {[llength $list] >= 3} {
        set icon    [string trim [lindex $list 0]]
        set title   [string trim [lindex $list 1]]
        set message [string trim [join [lrange $list 2 end] |]]
    }

    if {$icon eq ""} { set icon "error" }
    if {$title eq ""} { set title [sub "<%ErrorTitle%>"] }

    if {$message ne ""} {
        ::InstallJammer::Message -icon $icon -title $title -message $message
    }

    set focus [string trim [$id get FailureFocus]]
    if {$focus ne "" && [::InstallJammer::InGuiMode]} {
        set focus [::InstallAPI::GetWidgetPath -widget $focus]
        if {[winfo exists $focus]} { focus -force $focus }
    }
}

proc ::InstallJammer::GetAllTreeNodes { tree {parent "root"} } {
    set nodes {}
    foreach node [$tree nodes $parent] {
        lappend nodes $node
        eval lappend nodes [::InstallJammer::GetAllTreeNodes $tree $node]
    }
    return $nodes
}

proc ::InstallJammer::IsValidFilename {name} {
    return [expr {[regexp {[:\*\?\"<>|]} $name] == 0}]
}

proc ::InstallJammer::IsValidPath {path} {
    global conf

    set list [file split $path]
    if {$conf(windows) && [string match {[a-zA-Z]:/} [lindex $list 0]]} {
        set list [lrange $list 1 end]
    }
    foreach name $list {
        if {![::InstallJammer::IsValidFilename $name]} { return 0 }
    }
    return 1
}

proc ::InstallJammer::InGuiMode {} {
    return [info exists ::tk_patchLevel]
}

proc ::InstallJammer::WizardExists {} {
    global info
    if {![::InstallJammer::InGuiMode]} { return 0 }
    return [expr {[info exists info(Wizard)] && [winfo exists $info(Wizard)]}]
}

proc ::InstallJammer::ConsoleClearLastLine { {len 0} } {
    global conf
    if {!$len} {
        if {[info exists conf(ConsoleProgressLastLen)]} {
            set len $conf(ConsoleProgressLastLen)
            if {!$len} { return }
        } else {
            return
        }
    }
    puts -nonewline [string repeat   $len]
    puts -nonewline [string repeat " " $len]
    puts -nonewline [string repeat   $len]
}

proc ::InstallJammer::ConsoleProgressBar { percent } {
    global conf

    if {![info exists conf(ConsoleProgressWidth)] || $percent == 0} {
        SafeSet conf(ConsoleProgressNewline) 0
	SafeSet conf(ConsoleProgressFormat) {[%s%s] %d%%}
	set s [string map {%s "" %d "" %% %} $conf(ConsoleProgressFormat)]
	set conf(ConsoleProgressWidth) [string length $s]
        set conf(ConsoleProgressLastLen) 0
	SafeSet conf(ConsoleProgressCompletedHash) =
	SafeSet conf(ConsoleProgressIncompleteHash) -
    }

    set len  0
    set cols $conf(ConsoleWidth)
    ::InstallJammer::ConsoleClearLastLine

    set width [expr {$cols - 2 - $conf(ConsoleProgressWidth)}]
    if {[string match "*%d*" $conf(ConsoleProgressFormat)]} { incr width -3 }
    set pct   [expr {(100 * $percent) / 100}]
    set cnt   [expr {($width * $percent) / 100}]
    set done  [expr {$width - $cnt}]
    set args  [list $conf(ConsoleProgressFormat)]
    if {$conf(ConsoleProgressCompletedHash) ne ""} {
	lappend args [string repeat $conf(ConsoleProgressCompletedHash) $cnt]
    }
    if {$conf(ConsoleProgressIncompleteHash) ne ""} {
	lappend args [string repeat $conf(ConsoleProgressIncompleteHash) $done]
    }
    if {[string match "*%d*" $conf(ConsoleProgressFormat)]} {
	lappend args $pct
    }

    set string [eval format $args]
    puts -nonewline $string
    set conf(ConsoleProgressLastLen) [string length $string]

    if {$percent == 100} {
        ::InstallJammer::ConsoleClearLastLine
        if {$conf(ConsoleProgressNewline)} { puts "" }
    }
    flush stdout
}

proc ::InstallJammer::MountSetupArchives {} {
    global conf
    global info

    set found 0
    if {[info exists info(ArchiveFileList)]} {
        foreach file $info(ArchiveFileList) {
            set file [file join $info(InstallSource) $file]
            if {[file exists $file]} {
                set found 1
                installkit::Mount $file $conf(vfs)
            }
        }
    }
    return $found
}

proc ::InstallJammer::GetCommonInstallkit { {base ""} } {
    global info
    ::InstallJammer::InstallInfoDir
    set kit [file join $info(InstallJammerRegistryDir) \
        $info(Platform) installkit$info(Ext)]
    set opts [list -noinstall -o $kit]
    if {$base ne ""} { lappend opts -w $base }
    file mkdir [file dirname $kit]

    set main [::InstallJammer::TmpDir main[pid].tcl]
    set fp [open $main w]
    puts $fp {
        if {[llength $argv]} {
            uplevel #0 [list source [lindex $argv end]]
        }
    }
    close $fp
    return  [eval ::InstallJammer::Wrap $opts [list $main]]
}

proc ::InstallJammer::GetAllWidgets {parent} {
    set widgets [list $parent]
    foreach w [winfo children $parent] {
        lappend widgets $w
        eval lappend widgets [::InstallJammer::GetAllWidgets $w]
    }
    return $widgets
}

package require Itcl

proc ::InstallJammer::Class { name body } {
    set matches [regexp -all -inline {\s+writable attribute\s+([^\s]+)} $body]
    foreach {match varName} $matches {
        append body "method $varName {args} { cfgvar $varName \$args }\n"
    }

    set matches [regexp -all -inline {\s+readable attribute\s+([^\s]+)} $body]
    foreach {match varName} $matches {
        append body "method $varName {args} { set $varName }\n"
    }

    set map [list]
    lappend map "writable attribute" "public variable"
    lappend map "readable attribute" "private variable"

    set body [string map $map $body]

    itcl::class ::$name $body
}

::itcl::class Object {
    constructor {args} {
        eval configure $args
        set ::InstallJammer::ObjMap([namespace tail $this]) [incr objc]
    }

    destructor {
        unset ::InstallJammer::ObjMap([namespace tail $this])
    }

    method destroy {} {
        ::itcl::delete object $this
    }

    method cfgvar { args } {
        set option -[lindex $args 0]
        if {[llength $args] == 2} {
            configure $option [lindex $args 1]
            if {![catch {$this type} type] && $type eq "file"} {
                lappend ::conf(modifiedFiles) $this
            }
        }
        return [cget $option]
    }

    method serialize {} {
        set return [list]
        foreach list [configure] {
            set opt [lindex $list 0]
            set def [lindex $list end-1]
            set val [lindex $list end]
            if {$def == $val} { continue }
            lappend return $opt $val
        }
        return $return
    }

    common objc 0
} ; ## ::itcl::class Object

::itcl::class TreeObject {
    inherit Object

    constructor { args } {
        set id [namespace tail $this]

        eval configure $args

        if {!$temp && $parent ne ""} {
            if {![::InstallJammer::ObjExists $parent]} {
                ## If our parent doesn't exist, we don't exist.
                destroy
            } else {
                $parent children insert $index $id
            }
        }
        if {$name ne ""} { set ::InstallJammer::names($name) $id }
    }

    destructor {
        if {!$temp && $parent ne "" && [::InstallJammer::ObjExists $parent]} {
            $parent children remove $id
        }

        foreach child $children {
            $child destroy
        }

        if {!$temp} { CleanupAlias }
    }

    method serialize {} {
        set return [list]
        foreach list [configure] {
            set opt [lindex $list 0]
            if {$opt eq "-id" || $opt eq "-index"} { continue }
            set def [lindex $list end-1]
            set val [lindex $list end]
            if {$opt eq "-name" && $val eq [string tolower $id]} { continue }
            if {$def == $val} { continue }
            lappend return $opt $val
        }
        return $return
    }

    method CleanupAlias {} {
        variable ::InstallJammer::aliases
        variable ::InstallJammer::aliasmap

        if {[info exists aliasmap($id)]} {
            unset -nocomplain aliases($aliasmap($id))
            unset aliasmap($id)
            set ::InstallJammer::Properties($id,Alias) ""
        }
    }

    method parent { args } {
        if {[lempty $args]} { return $parent }

        if {![string equal $args "recursive"]} {
            return [set parent [lindex $args 0]]
        }

        set x    $parent
        set list [list]
        while {[string length $x]} {
            set list [linsert $list 0 $x]
            set x [$x parent]
        }
        return $list
    }

    method reparent { newParent } {
        ## If this is already our parent, don't do anything.
        if {$parent eq $newParent} { return }

        ## If we have an old parent, remove us from their children.
        if {$parent ne ""} { $parent children remove $id }

        ## Add ourselves to the new parent.
        set parent $newParent
        if {$parent ne ""} { $parent children add $id }
    }

    method children { args } {
        if {![llength $args]} { return $children }

        lassign $args command obj
        switch -- $command {
            "add" {
                children insert end $obj
            }

            "index" {
                return [lsearch -exact $children $obj]
            }

            "insert" {
                lassign $args command index obj
                if {$index eq "end"} {
                    lappend children $obj
                } else {
                    set children [linsert $children $index $obj]
                }
            }

            "remove" - "delete" {
                set children [lremove $children $obj]
            }

            "reorder" {
                if {[llength $obj]} { set children $obj }
            }

            "recursive" {
                return [::InstallJammer::ObjectChildrenRecursive $this]
            }
        }
    }

    method is { args } {
        if {[llength $args] == 1} {
            return [string equal [type] [lindex $args 0]]
        } else {
            return [expr {[lsearch -exact $args [type]] > -1}]
        }
    }

    method index {} {
        if {[string length $parent]} { return [$parent children index $id] }
    }

    method component {} {
        return "ClassObject"
    }

    method id        { args } { eval cfgvar id        $args }
    method name      { args } { eval cfgvar name      $args }
    method type      { args } { eval cfgvar type      $args }
    method alias     { args } { eval cfgvar alias     $args }
    method active    { args } { eval cfgvar active    $args }
    method comment   { args } { eval cfgvar comment   $args }
    method platforms { args } { eval cfgvar platforms $args }

    public variable id      ""
    public variable temp    0
    public variable name    ""
    public variable type    ""
    public variable index   "end"
    public variable active  1
    public variable parent  ""
    public variable comment ""

    public variable platforms [list]

    protected variable children [list]

    private variable oldalias ""
    public variable alias "" {
	if {$oldalias ne ""} {
	    $this CleanupAlias
	}
	set oldalias $alias

	if {$alias ne ""} {
	    set ::InstallJammer::aliases($alias) $id
	    set ::InstallJammer::aliasmap($id) $alias
            set ::InstallJammer::Properties($id,Alias) $alias
	}
    }
}

::itcl::class InstallType {
    inherit TreeObject

    constructor { args } {
        eval configure $args
    } {
        set type installtype
        eval configure $args
    }

    method class {} {
        return ::InstallType
    }

    method widget { args } {}
    method setup  { args } { eval cfgvar setup $args }
    method component {} {}

    public variable setup  ""
}

itcl::class File {
    inherit TreeObject

    constructor {args} {
	eval configure $args
    } {
        eval configure $args
    }

    method class {} {
        return ::File
    }

    method srcfile {} {
        if {$srcfile eq ""} { ::set srcfile [file join $::conf(vfs) $id] }
        return $srcfile
    }

    method checkFileMethod { dest } {
        ::set method [filemethod]
        if {$method eq ""} { ::set method [$parent filemethod] }

        ::set doInstall 1

        if {![info exists exists] && $method ne "Always overwrite"} {
            ::set exists [file exists $dest]
        }

        switch -- $method {
            "Update files with more recent dates" {
                ## We only want to overwrite if the file we have is newer
                ## than the one already installed.  If the one we have is
                ## older, skip it.
                if {$exists && [file mtime $dest] >= $mtime} {
                    ::set doInstall 0
                }
            }

            "Update files with a newer version" {
                ## We want to overwrite the file if we have a newer version
                ## than the one stored.  If there isn't one stored, we'll go
                ## ahead and store ours.
                global versions
                if {$exists && [info exists versions($dest)]} {
                    ::set c [package vcompare $version $versions($dest)]
                    if {$c == 0 || $c == -1} { ::set doInstall 0 }
                }
            }

            "Always overwrite files" {
                ## We want to always overwrite the file.
                ## This is the default action, so we do nothing.
            }

            "Never overwrite files" {
                ## We don't want to overwrite.  If the file exists, skip it.
                if {$exists} { ::set doInstall 0 }
            }

            "Prompt user" {
                if {$exists} {
                    ::set txt "<%FileOverwriteText%>"
                    ::set msg [::InstallJammer::SubstText $txt]
                    ::set ans [::InstallJammer::MessageBox -type yesno \
                        -name FileOverwrite -title "File Exists" \
                        -message $msg]
                    ::set doInstall [expr {$ans eq "yes"}]
                }
            }
        }

        return $doInstall
    }

    method destdir {} {
        return [::InstallJammer::SubstText [destdirname]]
    }

    method destdirname {} {
        return $directory
    }

    method destfile {} {
	return [file join [destdir] [destfilename]]
    }

    method destfilename {} {
	if {$targetfilename eq ""} {
	    return [file tail $name]
	} else {
	    return [::InstallJammer::SubstText $targetfilename]
	}
    }

    method srcfilename {} {
    	return [file tail $name]
    }

    method createdir {} {
	::InstallJammer::CreateDir [destdir]
    }

    method install {} {
	global conf

	if {![::InstallJammer::PauseCheck]} { return 0 }

        ::set dest [install[type]]

	if {![::InstallJammer::PauseCheck]} { return 0 }

        if {$conf(windows)} {
            ::InstallJammer::SetPermissions $dest $attributes
        } else {
            if {$permissions eq ""} {
                ::set permissions $::info(DefaultDirectoryPermission)
            }

            if {[type] eq "dir" && [info commands output] eq "output"} {
                output [list :DIR $dest $permissions]
                ::InstallJammer::SetPermissions $dest 00777
            } else {
                ::InstallJammer::SetPermissions $dest $permissions
            }
        }

        return 1
    }

    method installdir {} {
        createdir
    }

    method installlink {} {
        ::set dest [destfile]

        if {![checkFileMethod $dest]} { return }

        createdir

        if {[file exists $dest] && [catch { file delete -force $dest } error]} {
            return -code error $error
        }

        if {[catch { exec ln -s $linktarget $dest } error]} {
            return -code error $error
        }

        if {$version eq ""} {
            ::set version $::info(InstallVersion)
        } else {
            ::set version [::InstallJammer::SubstText $version]
        }

        ::InstallJammer::LogFile $dest
        ::InstallJammer::SetVersionInfo $dest $version

        return $dest
    }

    method installfile { {dest ""} {createDir 1} {checkMethod 1} {logFile 1} } {
	global conf
	global info

        if {$createDir} {
            createdir
        }

	::set src [srcfile]
        if {![file exists $src] && [info exists info(ArchiveFileList)]} {
            while {![file exists $src]} {
                ::InstallJammer::PauseInstall
                output [list :DISC [[parent] name]]
                ::InstallJammer::MountSetupArchives
            }
        }

        if {$dest eq ""} { ::set dest [destfile] }

        if {$version eq ""} {
            ::set version $::info(InstallVersion)
        } else {
            ::set version [::InstallJammer::SubstText $version]
        }

        ::set doInstall 1
        if {$checkMethod} {
            ::set doInstall [checkFileMethod $dest]
        }

	::set info(FileSize) $size
	if {!$doInstall} {
            ::set progress ::InstallJammer::IncrProgress
            if {[::InstallJammer::CommandExists $progress]} { $progress $size }
	    return $dest
	}

        if {$permissions eq ""} {
            if {$conf(windows)} {
                ::set permissions 0666
            } else {
                ::set permissions $info(DefaultFilePermission)
            }
        }

	if {!$size} {
            ## Empty file.
	    if {[catch { open $dest w $permissions } err]} {
		return -code error $err
	    }
	    close $err
	} else {
	    ::InstallJammer::unpack $src $dest $permissions
	}

        if {$info(InstallStopped)} { return }

        ## Set the modified time to the one we have stored.
        if {$mtime} {
            file mtime $dest $mtime
        }

        if {$logFile} {
            ::InstallJammer::LogFile $dest
            ::InstallJammer::SetVersionInfo $dest $version
        }

	return $dest
    }

    method group {} {
        return [lindex [parent recursive] 1]
    }

    method set { args } {
        return [eval ::InstallJammer::SetObjectProperties $id $args]
    }

    method get { property {varName ""} } {
        if {[string length $varName]} {
            upvar 1 $varName var
            return [::InstallJammer::GetObjectProperty $id $property var]
        } else {
            return [::InstallJammer::GetObjectProperty $id $property]
        }
    }

    method isfile {} {
        return [is file link]
    }

    method object {} {
        return ::FileObject
    }

    method filemethod { {newMethod ""} } {
        if {$newMethod ne ""} {
            if {![info exists ::InstallJammer]} {
                variable ::InstallJammer::PropertyMap
                ::set n [lsearch -exact $PropertyMap(FileUpdateMethod) \
                    $newMethod]
                if {$n < 0} {
                    return -code error [BWidget::badOptionString method \
                        $newMethod $PropertyMap(FileUpdateMethod)]
                }
                ::set newMethod $n
            }
            ::set filemethod $newMethod
        }

        if {[string is integer -strict $filemethod]} {
            return [lindex $::InstallJammer::PropertyMap(FileUpdateMethod) \
                $filemethod]
        }
        return $filemethod
    }

    method component {} {}

    method name               { args } { eval cfgvar name              $args }
    method size               { args } { eval cfgvar size              $args }
    method mtime              { args } { eval cfgvar mtime             $args }
    method version            { args } { eval cfgvar version           $args }
    method location           { args } { eval cfgvar location          $args }
    method directory          { args } { eval cfgvar directory         $args }
    method savefiles          { args } { eval cfgvar savefiles         $args }
    method linktarget         { args } { eval cfgvar linktarget        $args }
    method attributes         { args } { eval cfgvar attributes        $args }
    method permissions        { args } { eval cfgvar permissions       $args }
    method targetfilename     { args } { eval cfgvar targetfilename    $args }
    method compressionmethod  { args } { eval cfgvar compressionmethod $args }

    public variable type               "file"
    public variable name               ""
    public variable size               0
    public variable mtime              0
    public variable srcfile            ""
    public variable version            ""
    public variable location           ""
    public variable directory          ""
    public variable savefiles          ""
    public variable linktarget         ""
    public variable filemethod         ""
    public variable attributes         ""
    public variable permissions        ""
    public variable targetfilename     ""
    public variable compressionmethod  ""

    private variable exists

} ; ## itcl::class File

::itcl::class InstallComponent {
    inherit TreeObject

    constructor { args } { 
        eval configure $args
    } {
        ::set name [string tolower $id]

        eval configure $args

        ## If this is a temporary object, we don't want to append
        ## it to the lists or do any further setup.
        if {$temp} {
            if {[string length $parent]} { $parent children remove $id }
            return
        }

        if {![info exists ::InstallJammer] && [get Include incl]} {
            if {$::info(Testing) && $incl eq "Include only when not testing"
                || !$::info(Testing) && $incl eq "Include only when testing"} {
                destroy
                return
            }
        }

        if {[info exists ::InstallJammer::Properties($id,Alias)]
            && [string length $::InstallJammer::Properties($id,Alias)]} {
            $this set Alias $::InstallJammer::Properties($id,Alias)
        }

        ## Do some special setup if this is a pane, and we're
        ## building it from within an installer.
        if {![info exists ::InstallJammer] && [ispane]} {
            ::set install $parent
            ::set wizard  $::info(Wizard)

            ::set node $parent
            if {[$parent is installtype]} { ::set node root }

            if {[string equal $install "Common"]} {
                ::InstallJammer::CreateWindow $wizard $id
            } elseif {[string equal $install $::info($::conf(mode))]} {
                ::set create \
                    [list ::InstallJammer::CreateWindow $wizard $id]

                get WizardOptions stepopts
                eval [list $wizard insert step end $node $id \
                    -createcommand $create] $stepopts

                if {[is window]} {
                    $wizard itemconfigure $id -appendorder 0
                }
            }
        }
    }

    destructor {
        if {!$temp} {
            array unset ::InstallJammer::Properties $id,*

            foreach lang [::InstallJammer::GetLanguageCodes] {
                ::msgcat::mcunset $lang $id,*
            }

            foreach condition $conditions {
                catch { $condition destroy }
            }
        }
    }

    method class {} {
        return ::InstallComponent
    }

    method set { args } {
        if {[llength $args] == 0} { return }
        if {[llength $args] == 1} { ::set args [lindex $args 0] }
        eval [list ::InstallJammer::SetObjectProperties $id] $args
    }

    method get { property {varName ""} } {
        if {[string length $varName]} {
            upvar 1 $varName var
            return [::InstallJammer::GetObjectProperty $id $property var]
        } else {
            return [::InstallJammer::GetObjectProperty $id $property]
        }
    }

    method getText { field args } {
        eval [list ::InstallJammer::GetText $id $field] $args
    }

    method setText { languages args } {
        if {[llength $args] == 0} { return }
        if {[llength $args] == 1} { ::set args [lindex $args 0] }
        eval [list ::InstallJammer::SetVirtualText $languages $id] $args
    }

    method properties { arrayName args } {
        upvar 1 $arrayName array
        return [eval ::InstallJammer::ObjectProperties $id array $args]
    }

    method ispane {} {
        return [expr {[is "pane"] || [is "window"]}]
    }

    method object {} {
        if {[ispane]} {
            variable ::InstallJammer::panes
            return $panes($component)
        } elseif {[is action]} {
            variable ::InstallJammer::actions
            return $actions($component)
        } elseif {[is actiongroup]} {
            return ActionGroupObject
        }
    }

    method initialize {} {
        [object] initialize $id
    }

    method widget { command widget args } {
        switch -- $command {
            "get" {
                if {[info exists widgetData($widget,widget)]} {
                    return $widgetData($widget,widget)
                }
            }

            "set" {
                if {[lsearch -exact $widgets $widget] < 0} {
                    lappend widgets $widget
                }

                foreach [list opt val] $args {
                    ::set widgetData($widget,[string range $opt 1 end]) $val
                }
            }
            
            "type" {
                if {[info exists widgetData($widget,type)]} {
                    return $widgetData($widget,type)
                }
                return text
            }
        }
    }

    method widgets {} {
        return $widgets
    }

    method conditions { args } {
        if {[lempty $args]} { return $conditions }

        lassign $args command obj
        switch -- $command {
            "add" {
                conditions insert end $obj
            }

            "index" {
                return [lsearch -exact $conditions $obj]
            }

            "insert" {
                lassign $args command index obj
                if {[lsearch -exact $conditions $obj] > -1} { return }

                if {$index eq "end"} {
                    lappend conditions $obj
                } else {
                    ::set conditions [linsert $conditions $index $obj]
                }
            }

            "remove" - "delete" {
                ::set conditions [lremove $conditions $obj]
            }

            "reorder" {
                ::set conditions $obj
            }
        }

        return
    }

    method checkConditions { {when ""} } {
        if {[ispane]} {
            global info
            ::set info(CurrentPane) $id
        }

        ::set return 1
        if {[llength $conditions]} {
            ::set conditionlist [list]

            foreach cid $conditions {
                if {![::InstallJammer::ObjExists $cid]} { continue }

                if {$when eq "" || [$cid get CheckCondition] eq $when} {
                    lappend conditionlist $cid
                }
            }

            if {[llength $conditionlist]} {
                ::set msg "Checking conditions for $id - $title"
                if {$when ne ""} { append msg " - $when" }
                debug $msg $id

                foreach cid $conditionlist {
                    if {![$cid active]} {
                        debug "Skipping condition $cid - [$cid title] -\
                                condition is inactive" $cid
                        continue
                    }

                    debug "Checking condition $cid - [$cid title]" $cid
                    ::set result [$cid check 0]

                    if {!$result} {
                        debug "Condition failed"
                        ::set return 0
                        lappend failures $cid
                        if {$operator eq "AND"} {
                            break
                        }
                    } else {
                        debug "Condition passed"
                        if {$operator eq "OR"} {
                            ::set return 1
                            break
                        }
                    }
                }
            }
        }

        if {!$return} {
            ::InstallJammer::DisplayConditionFailure [lindex $failures 0]
        }

        return $return
    }

    method execute {} {
        if {$type ne "action"} { return }

        ::set executed 1

        debug "Executing action $id - [$id title]" $id

        ::set ::info(CurrentAction) $id
        ::InstallJammer::CurrentObject push $id

        if {[info exists ::InstallJammer::tests(before,$id)]} {
            inject run before,$id
        } elseif {[info exists ::InstallJammer::tests(before,$type)]} {
            inject run before,$type
        }

        ## Remember our current directory.
        if {[file exists .]} { ::set pwd [pwd] }

        ::set err [catch {::InstallJammer::actions::$component $this} res]

        ## Actions can sometimes change to a directory.  We want
        ## to make sure to change back if the action didn't do
        ## that itself.
        if {[info exists pwd] && [file exists .]
            && [file exists $pwd] && $pwd ne [pwd]} {
            cd $pwd
        }

        if {[info exists ::InstallJammer::tests(after,$id)]} {
            inject run after,$id
        } elseif {[info exists ::InstallJammer::tests(after,$type)]} {
            inject run after,$type
        }

        ::InstallJammer::CurrentObject pop

        if {$err && ![get IgnoreErrors]} {
            ::set msg "Error in action $component\n\n$::errorInfo"
            return -code error $msg
        }

        return $res
    }

    method setup       { args } { eval cfgvar setup       $args }
    method title       { args } { eval cfgvar title       $args }
    method window      { args } { eval cfgvar window      $args }
    method created     { args } { eval cfgvar created     $args }
    method command     { args } { eval cfgvar command     $args }
    method executed    { args } { eval cfgvar executed    $args }
    method operator    { args } { eval cfgvar operator    $args }
    method component   { args } { eval cfgvar component   $args }
    method arguments   { args } { eval cfgvar arguments   $args }
    method description { args } { eval cfgvar description $args }

    public variable type        "installcomponent"
    public variable setup       ""
    public variable title       ""
    public variable window      ""
    public variable created     0
    public variable executed    0
    
    public variable operator    "AND"
    public variable component   ""
    public variable arguments   ""
    public variable conditions  [list]
    public variable description ""

    private variable widgets    [list]
    private variable widgetData
} ; ## ::itcl::class InstallComponent

::itcl::class FileGroup {
    inherit InstallComponent

    constructor { args } {
        eval configure $args
    } {
        eval configure $args
        ::set setup Install
    }

    method class {} {
        return ::FileGroup
    }

    method install {} {
        global conf

        ::set dir [directory]

        ::InstallJammer::CreateDir $dir

        if {$conf(windows)} {
            ::InstallJammer::SetPermissions $dir [get Attributes]
        } else {
            ::InstallJammer::SetPermissions $dir [get Permissions]
        }
    }

    method destdirname {} {
        return [get Destination]
    }

    method directory {} {
        return [::InstallJammer::SubstText [destdirname]]
    }

    method version {} {
        return [get Version]
    }

    method filemethod {} {
        return [get FileUpdateMethod]
    }

    method object {} {
        return ::FileGroupObject
    }

    method compressionmethod {} {
        return [get CompressionMethod]
    }

    public variable type "filegroup"
} ; ## ::itcl::class FileGroup

::itcl::class Component {
    inherit InstallComponent

    constructor { args } {
        eval configure $args
    } {
        eval configure $args
        ::set setup Install
    }

    method class {} {
        return ::Component
    }

    method object {} {
        return ::ComponentObject
    }

    public variable type "component"
} ; ## ::itcl::class Component

::itcl::class SetupType {
    inherit InstallComponent

    constructor { args } {
        eval configure $args
    } {
        eval configure $args
        ::set setup Install
    }

    method class {} {
        return ::SetupType
    }

    method object {} {
        return ::SetupTypeObject
    }

    public variable type "setuptype"
} ; ## ::itcl::class SetupType

::itcl::class Condition {
    inherit TreeObject

    constructor { args } {
        ::set id [namespace tail $this]
        eval configure $args

        if {[::InstallJammer::ObjExists $parent]} {
            $parent conditions add $id
        }
    }

    destructor {
        if {[::InstallJammer::ObjExists $parent]} {
            $parent conditions remove $id
        }
    }

    method class {} {
        return ::Condition
    }

    method serialize {} {
        ::set return [list]
        foreach list [configure] {
            ::set opt [lindex $list 0]
            if {$opt eq "-id"} { continue }

            ::set def [lindex $list end-1]
            ::set val [lindex $list end]
            if {$def == $val} { continue }
            lappend return $opt $val
        }
        return $return
    }

    method set { args } {
        return [eval ::InstallJammer::SetObjectProperties $id $args]
    }

    method get { property {varName ""} } {
        if {[string length $varName]} {
            upvar 1 $varName var
            return [::InstallJammer::GetObjectProperty $id $property var]
        } else {
            return [::InstallJammer::GetObjectProperty $id $property]
        }
    }

    method properties { arrayName args } {
        upvar 1 $arrayName array
        return [eval ::InstallJammer::ObjectProperties $id array $args]
    }

    method object {} {
        return $::InstallJammer::conditions($component)
    }

    method check { {showError 1} } {
        ::set ::info(CurrentCondition) $id
        ::InstallJammer::CurrentObject push $id

        if {[info exists ::InstallJammer::tests(before,$id)]} {
            inject run before,$id
        } elseif {[info exists ::InstallJammer::tests(before,$component)]} {
            inject run before,$component
        }

        ::set res [string is true [::InstallJammer::conditions::$component $id]]
        if {!$res && $showError} {
            ::InstallJammer::DisplayConditionFailure $id
        }

        if {[info exists ::InstallJammer::tests(after,$id)]} {
            inject run after,$id
        } elseif {[info exists ::InstallJammer::tests(after,$component)]} {
            inject run after,$component
        }

        ::InstallJammer::CurrentObject pop

        ::set passed $res
    }

    method name {} {
    }

    method type {} {
        return $type
    }

    method id        { args } { eval cfgvar id        $args }
    method title     { args } { eval cfgvar title     $args }
    method active    { args } { eval cfgvar active    $args }
    method passed    { args } { eval cfgvar passed    $args }
    method parent    { args } { eval cfgvar parent    $args }
    method component { args } { eval cfgvar component $args }

    public variable id        ""
    public variable type      "condition"
    public variable title     ""
    public variable active    1
    public variable passed    -1
    public variable parent    ""
    public variable component ""
} ; ## ::itcl::class Condition
