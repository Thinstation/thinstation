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

namespace eval ::InstallJammer {}

proc ::InstallJammer::DisplayUsageInformation { {message ""} } {
    global conf

    uplevel #0 source [list [file join $conf(lib) common.tcl]]

    append message {
Usage: installjammer ?options? ?--? ?projectFile?

Options:
    --                        denotes the end of options
    --build                   build the installers for the given project file
    --build-dir <directory>   directory to use for temporary build files
    --build-for-release       build the installers for final release
    --build-log-file          path to the file to log build messages in
    --control-script <file>   load script file before building
    --debug-log               run installjammer with a debug log
    --help                    display this information
    --output-dir <directory>  directory to store finished installers in
    --platform <platform>     specify a platform to add to the build list
    --quick-build             do a quick rebuild and not a full build
    --quiet                   only build errors will be reported
    --test                    test the installer when it is done building
    --test-without-installing test the installer without installing files
    --verbose                 output verbose logging when building
    --version                 display InstallJammer version information

    -D<virtualText> <value>   set <virtualText> to <value> before building
}

    ::InstallJammer::Message -message $message
    ::exit 0
}

proc ParseCommandLineArgs {} {
    global argv
    global conf
    global info

    set switches {
        --build
        --build-for-release
        --debug-log
        --quick-build
        --test
        --test-without-installing
        --quiet
        --verbose
        -v -version --version
        -help --help
	-b -t -S
    }

    set options {
        -d -p
	--build-dir
        --build-log-file
        --command-port
        --control-script
	--output-dir
        --platform
    }

    set len  [llength $argv]
    set args {}
    set file ""
    for {set i 0} {$i < $len} {incr i} {
	set arg [lindex $argv $i]

	if {[lsearch -exact $switches $arg] > -1} {
	    if {[info exists val]} {
	        lappend args [join $val]
		unset val
	    }

	    lappend args $arg ""
	} elseif {[lsearch -exact $options $arg] > -1
	    	    || [string match "-D*" $arg]} {
	    if {[info exists val]} {
	        lappend args [join $val]
		unset val
	    }

	    lappend args $arg
	} elseif {$arg eq "--"} {
	    if {[info exists val]} {
	        lappend args [join $val]
		unset val
	    }

	    set file [join [lrange $argv [incr i] end]]
	    break
	} else {
	    lappend val $arg
	}
    }

    if {[info exists val]} {
    	set file [join $val]
	unset val
    }

    foreach {opt val} $args {
	switch -glob -- $opt {
	    "--build" - "-b" {
                # Build the install of the given project.
		set conf(cmdline) 1
	    }

	    "--build-dir" {
		set conf(cmdline) 1
	    	set conf(BuildDir) $val
	    }

            "--build-for-release" {
		set conf(cmdline) 1
                set conf(buildForRelease) 1
            }

            "--build-log-file" {
                set conf(buildLogFile) $val
            }

            "--command-port" {
                set conf(commandPort) $val
            }

	    "--control-script" - "-d" {
		set conf(cmdline) 1
		lappend conf(CommandLineOptionFiles) $val
	    }

            "--debug-log" {
                set conf(debugLogFile) $val
            }

            "--help" - "-help" {
                ::InstallJammer::DisplayUsageInformation
            }

	    "--output-dir" {
		set conf(cmdline) 1
	    	set conf(OutputDir) $val
	    }

	    "--platform" - "-p" {
		set conf(cmdline) 1
		lappend conf(platformBuildList) $val
	    }

	    "--quiet" {
                # Supress messages to stdout.  Errors will go to stderr.
		set conf(silent) 1
	    }

            "--quick-build" {
		set conf(cmdline) 1
                set conf(rebuildOnly) 1
            }

	    "--test" - "-t" {
                # Build and then test the given project.
		set conf(cmdline) 1
		set conf(buildAndTest) 1
	    }

            "--test-without-installing" {
		set conf(buildAndTest) 1
                set conf(testInTestMode) 1
            }

	    "--verbose" {
		set conf(verbose) 1
	    }

            "--version" - "-version" - "-v" {
                puts "$conf(Version) ($conf(BuildVersion))"
                puts ""
                puts "InstallJammer version $conf(Version)"
                ::exit 0
            }

	    "-D*" { ; # Set an option in the info array.
		set opt [string range $opt 2 end]
		lappend conf(CommandLineOptions) $opt $val
	    }

	    default {
                ::InstallJammer::DisplayUsageInformation \
                        "\ninvalid option \"$opt\"\n"
	    }
	}
    }

    if {$conf(cmdline) && $file eq ""} {
        ::InstallJammer::DisplayUsageInformation
    }

    set argv {}
    if {$file ne ""} {
        if {[lsearch -exact $options $file] > -1
	    || [lsearch -exact $switches $file] > -1
	    || [string match "-D*" $file]} {
            ::InstallJammer::DisplayUsageInformation \
                "\nNo project file specified.\n"
        }

        if {![file exists $file]} {
            ::InstallJammer::DisplayUsageInformation \
                "\nProject file \"$file\" does not exist.\n"
        }

        set file [file normalize $file]
        if {[file isdirectory $file]} {
            set tail [file tail $file]
            if {[file exists [file join $file $tail.mpi]]} {
                set file [file join $file $tail.mpi]
            } else {
                set files [glob -nocomplain -type f -dir $file *.mpi]
                if {[llength $files] > 1} {
                    ::InstallJammer::DisplayUsageInformation \
                        "\nPlease specify which project file in $file.\n"
                }
                set file [lindex $files 0]
            }
        }

        set argv [list $file]
    }
}

proc ::InstallJammer::InstallJammerHome { {file ""} } {
    global conf

    if {[file exists [file join $conf(pwd) preferences]]} {
        set conf(home) $conf(pwd)
        set conf(InstallJammerHome) $conf(pwd)
    }

    if {![info exists conf(home)] || ![info exists conf(InstallJammerHome)]} {
        if {[info exists env(USERPROFILE)]} {
            set home $env(USERPROFILE)
        }

        if {[info exists env(HOME)]} {
            set home $env(HOME)
        }

        if {[info exists env(INSTALLJAMMER_HOME)]} {
            set home $env(INSTALLJAMMER_HOME)
        }

        if {![info exists home]} {
            switch $::tcl_platform(platform) {
                "windows" {
                    if {$conf(windows98)} {
                        set home [installkit::Windows::getFolder MYDOCUMENTS]
                    } else {
                        set home [installkit::Windows::getFolder PROFILE]
                    }
                }

		default {
		    set home [file normalize ~]
		}
            }
        }

        set conf(home) $home

        set ijhome [file join $conf(home) .installjammer]
        if {$conf(osx)} {
            set ijhome [file join ~ Library InstallJammer]
        }

        set conf(InstallJammerHome) [file normalize $ijhome]

        if {![file exists $conf(InstallJammerHome)]} {
            file mkdir $conf(InstallJammerHome)
        }
    }

    set return $conf(InstallJammerHome)
    if {$file ne ""} { set return [file join $return $file] }

    return $return
}

proc ::InstallJammer::GuiInit {} {
    global conf

    DynamicHelp::configure -topbg #000000 -bd 1 -bg #FFFFDC -padx 2 -pady 3

    IconLibrary InstallJammerIcons

    option add *font                                        TkTextFont
    option add *Menu.tearOff                                0

    option add *Installjammer*highlightThickness            0
    option add *Installjammer*Listbox.background            #FFFFFF
    option add *Installjammer*ListBox.background            #FFFFFF
    option add *Installjammer*Listbox.selectBorderWidth     0
    option add *Installjammer*Entry.selectBorderWidth       0
    option add *Installjammer*Text.selectBorderWidth        0
    option add *Installjammer*Menu.activeBorderWidth        0
    option add *Installjammer*Menu.highlightThickness       0
    option add *Installjammer*Menu.borderWidth              2
    option add *Installjammer*Menubutton.activeBorderWidth  2
    option add *Installjammer*Menubutton.highlightThickness 0
    option add *Installjammer*Menubutton.borderWidth        2
    option add *Installjammer*Tree.background               #FFFFFF
    option add *Installjammer*Properties*editfinishcommand  \
        [list ::InstallJammer::EditFinishProperty %W %n]

    option add *Tree*highlightThickness                     0
    option add *ComboBox*Entry*background                   #FFFFFF

    #option add *Installjammer*Panedwindow.borderWidth       0
    #option add *Installjammer*Panedwindow.sashWidth         3
    #option add *Installjammer*Panedwindow.showHandle        0
    #option add *Installjammer*Panedwindow.sashPad           0
    #option add *Installjammer*Panedwindow.sashRelief        flat
    #option add *Installjammer*Panedwindow.relief            flat

    image create photo logo  -file [file join $conf(icons) logo.png]

    ## See if we have the tkdnd package for drag-and-drop support.  If not,
    ## create a dummy command so the dnd commands will do nothing.
    if {[catch { package require tkdnd }]} { proc ::dnd {args} {} }

    InitializeBindings

    Status "Creating images..."
    SetIconTheme
}

proc ::InstallJammer::Debug { string } {
    global conf
    if {$conf(debugLogFile) eq ""} { return }
    if {![info exists conf(debugfp)]} {
        set home [::InstallJammer::InstallJammerHome]
        set conf(debugfp) [open $conf(debugLogFile) w]
    }
    puts $conf(debugfp) $string
}

proc ClearStatus {} {
    set ::conf(status) ""
}

proc ::InstallJammer::StatusPrefix { {prefix ""} } {
    set ::conf(statusPrefix) $prefix
    Status ""
}

proc Status { string {time ""} } {
    global conf
    if {![info exists ::tk_patchLevel]} { return }
    if {[winfo exists .splash]} {
	.splash.c itemconfigure $::widg(SplashText) -text $string
        ::InstallJammer::Debug $string
    } else {
	set conf(status) $conf(statusPrefix)$string
    }
    if {[info exists conf(statusTimer)]} { after cancel $conf(statusTimer) }
    if {$time ne ""} { set conf(statusTimer) [after $time ClearStatus] }

    update idletasks
}

proc init {} {
    global info
    global conf
    global Components
    global SetupTypes
    global preferences

    catch { wm withdraw . }
    catch { console hide }

    set conf(osx)     [string equal $::tcl_platform(os) "Darwin"]
    set conf(unix)    [expr {[string equal $::tcl_platform(platform) "unix"]
			&& !$conf(osx)}]
    set conf(windows) [string equal $::tcl_platform(platform) "windows"]

    set conf(windows98) 0
    if {$conf(windows) && $::tcl_platform(osVersion) < 5.0} {
        set conf(windows98) 1
    }

    set conf(vista) 0
    if {$conf(windows) && $::tcl_platform(osVersion) >= 6.0} {
        set conf(vista) 1
    }

    array set conf {
        Version                 1.2.15
	InstallJammerVersion	1.2.15.2
	projectLoaded		0
	silent			0
        verbose                 0
	cmdline			0
	modified		0
        filesModified           0
        exiting                 0
        closing                 0
	loading			0
	building		0
        statusPrefix            ""
        renameAfterId           ""
        demo                    0
	stop			.stop
	pause			.pause
	RecentProjects		{}
        buildStopped            0
        buildForRelease         0
	buildMainTclOnly	0
        fullBuildRequired       0
	saveMainTcl		1
	logBuild		1
	buildAndTest		0
        testInTestMode          0
	backgroundBuild 	1
	rebuildOnly		0
	SaveTempDir		0
	TestWithoutFiles	0
	TestAllDefaults		0
	TestSilent		0
        TestConsole             0
	TestWithConsole		0
        SelectedProject         ""
	ThemeDirs		{Install Uninstall}
        DefaultTheme            "Modern_Wizard"
        ThemeSourceDirs         {Install Uninstall Common}
        Tabs                    {Product}
        TestCommandLineOptions  {}
        VirtualTextLanguage     "None"
        Archives                {}
        TreeFocus               ""
        clipboard               {}
        debugLogFile            ""

        TestUninstallSilentMode         0
        TestUninstallConsoleMode        0
        TestUninstallWithConsole        0
        TestUninstallWithoutFiles       0
        TestUninstallCommandLineOptions {}

        InstallTypes {Common Standard Default Console Silent ActionGroups}

        InstallModes            {Console Default Silent Standard}
        UninstallModes          {Console Silent Standard}

        InstallsDir             "InstallJammerProjects"

        HomePage                "http://www.installjammer.com/"
        HelpURL                 "http://www.installjammer.com/docs/"
        ForumsURL               "http://www.installjammer.com/forums/"
        HelpTopic               "Welcome"
        DefaultHelpTopic        "Welcome"

        PaneCheckConditions {
            "After Pane is Cancelled"
            "Before Next Pane is Displayed"
            "Before Pane is Cancelled"
            "Before Pane is Displayed"
            "Before Pane is Finished"
            "Before Previous Pane is Displayed"
        }

        ActionCheckConditions {
            "Before Action is Executed"
            "Before Next Action is Executed"
        }
    }

    set conf(CompressionMethods) {lzma "lzma (solid)" none zlib "zlib (solid)"}

    if {![catch { package require miniarc::crap::lzma }]} {
        set conf(CompressionMethods) {none zlib "zlib (solid)"}
    }

    if {![catch { package require miniarc::tar }]} {
        lappend conf(Archives) TarArchive
    }

    if {![catch { package require miniarc::zip }]} {
        lappend conf(Archives) ZipArchive
    }

    if {$conf(windows)} {
        set conf(InstallsDir) "My InstallJammer Projects"
        if {$::tcl_platform(osVersion) > 5.1} {
            set conf(InstallsDir) "InstallJammer Projects"
        }
    } elseif {$conf(osx)} {
        set conf(InstallsDir) "projects"
    }

    array set preferences {
        CustomThemeDir          ""
        CustomActionDir         ""
        CustomConditionDir      ""
	Theme			crystal
        Editor                  ""
	HelpBrowser		""
        RecentProjects          {}

        CheckForUpdates         0
        UseProxyServer          0
        ProxyHost               ""
        ProxyPort               8080
    }

    if {$conf(windows)} {
	set preferences(HelpBrowser) "Windows Help"
    }

    ## A list of variables to store in the install when building.
    ## Only variables in this list and the platform specific
    ## variables will be stored from the info array.
    set conf(InstallVars) {
        AllowLanguageSelection
	AppName
        ApplicationID
        ApplicationURL
        BuildVersion
	CancelledInstallAction
	CleanupCancelledInstall
	Company
        CompressionMethod
        Copyright
        DefaultLanguage
        DefaultToSystemLanguage
        EnableResponseFiles
        ExtractSolidArchivesOnStartup
        Icon
        Image
	IncludeDebugging
	InstallVersion
        MajorVersion
        MinorVersion
        PackageDescription
        PackageLicense
        PackageMaintainer
        PackageName
        PackagePackager
        PackageRelease
        PackageSummary
        PackageVersion
        PatchVersion
        ShortAppName
        UpgradeApplicationID
	Version
        WizardHeight
        WizardWidth
    }

    ## A list of platform-specific variables that get stored in the
    ## install when building.
    set conf(PlatformVars) {
        DefaultDirectoryPermission
        DefaultFilePermission
        FallBackToConsole
        InstallDir
        InstallMode
        InstallType
        ProgramExecutable
        ProgramFolderAllUsers
        ProgramFolderName
        ProgramLicense
        ProgramName
        ProgramReadme
        PromptForRoot
        RequireAdministrator
        RequireRoot
        RootInstallDir
    }

    set conf(WindowsSpecialDirs) {
	DESKTOP
	INTERNET 
	PROGRAMS
	CONTROLS 
	PRINTERS
	PERSONAL 
	FAVORITES
	STARTUP 
	RECENT
	SENDTO 
	BITBUCKET
	STARTMENU 
	DESKTOPDIRECTORY
	DRIVES 
	NETWORK
	NETHOOD 
	FONTS
	TEMPLATES 
	APPDATA
	PRINTHOOD 
	ALTSTARTUP
	INTERNET_CACHE 
	COOKIES
	HISTORY 
	COMMON_ALTSTARTUP 
	COMMON_FAVORITES
	COMMON_STARTMENU
	COMMON_PROGRAMS 
	COMMON_STARTUP
	COMMON_DESKTOPDIRECTORY 
	WINDOWS
	SYSTEM
	SYSTEM32
	PROGRAM_FILES
	QUICK_LAUNCH
    }
    set conf(WindowsSpecialDirs) [lsort $conf(WindowsSpecialDirs)]

    set ::InstallJammer $conf(InstallJammerVersion)

    namespace eval ::InstallJammer {}
    namespace eval ::InstallJammer::theme {}
    namespace eval ::InstallJammer::preview {}
    namespace eval ::InstallJammer::actions {}
    namespace eval ::InstallJammer::loadtheme {}
    namespace eval ::InstallJammer::conditions {}
    namespace eval ::InstallJammer::loadactions {}
    namespace eval ::InstallJammer::loadconditions {}

    set conf(gui)     $::tcl_platform(platform)
    set conf(lib)     [file join $conf(pwd) lib]
    set conf(help)    [file join $conf(pwd) docs]
    set conf(icons)   [file join $conf(lib) Icons]
    set conf(images)  [file join $conf(pwd) Images]
    set conf(winico)  [file join $conf(pwd) Images "Windows Icons"]
    set conf(bwidget) [file join $conf(lib) BWidget]

    if {$conf(osx)} { set conf(gui) "osx" }

    ::ParseCommandLineArgs

    ::InstallJammer::Debug "Initializing InstallJammer..."

    uplevel #0 source [list [file join $conf(lib) common.tcl]]
    uplevel #0 source [list [file join $conf(lib) utils.tcl]]

    if {[info exists conf(commandPort)]} {
        set conf(commandSock) [socket -server \
            ::InstallJammer::AcceptCommandConnection $conf(commandPort)]
    }

    set conf(bin) [file join $conf(pwd) Binaries [::InstallJammer::Platform]]

    ## We want our directories in front incase the user has an older
    ## version of the libraries we're using.
    set ::auto_path [linsert $::auto_path 0 $conf(lib) $conf(bin)]

    set bindir [file dirname [info nameofexecutable]]
    if {!$conf(windows) && [lsearch -exact $::auto_path $bindir] < 0} {
        lappend ::auto_path $bindir
    }

    set verfile [file join $conf(pwd) .buildversion]
    set gitfile [file join $conf(pwd) .git refs heads v1.2]
    if {[file exists $verfile]} {
        set conf(BuildVersion) [string trim [read_file $verfile]]
    } elseif {[file exists $gitfile]} {
        set conf(BuildVersion) [string range [read_file $gitfile] 0 6]
    } else {
        set conf(BuildVersion) "unknown"
    }

    if {!$conf(cmdline)} {
	if {[catch { package require Tk } version]} {
	    puts "InstallJammer must be run in a graphical environment."
	    exit
	}

	wm withdraw .

        ::InstallJammer::Debug "Loading generic GUI code..."
        package require tile 0.5

	if {[package vcompare $version 8.5.0]} {
	    namespace import ::ttk::style
	}

	## Source in the common GUI code.
	uplevel #0 [list source [file join $conf(lib) gui-common.tcl]]

        ## Source in the platform-specific GUI code.
        uplevel #0 [list source [file join $conf(lib) gui-$conf(gui).tcl]]

        ## Display the splash screen.
        source [file join $conf(lib) splash.tcl]

        wm title    . "InstallJammer"
        wm client   . [info hostname]
        wm command  . [linsert $::argv 0 $::argv0]

        if {$conf(windows)} {
            wm iconbitmap . -default [file join $conf(icons) InstallJammer.ico]
        }

	Window.splash
	grab set .splash
	update idletasks

        Status "Loading libraries..."
    }

    ## Source in all the library files.
    foreach file [glob [file join $conf(lib) *.tcl]] {
        if {[string match "*gui-*" $file]} { continue }
        if {[string match "*common.tcl" $file]} { continue }
	uplevel #0 source [list $file]
    }

    ::InstallJammer::CommonInit

    Status "Loading user preferences..."

    ::InstallJammer::LoadPreferences

    Status "Loading actions..."

    ::InstallJammer::LoadActions

    Status "Loading conditions..."

    ::InstallJammer::LoadConditions

    Status "Loading messages..."
    ::InstallJammer::LoadMessages
    ::InstallJammer::LoadReservedVirtualText

    ## Establish a list of available install themes.
    ::InstallJammer::ThemeList

    ## Initialize some objects.
    Platform  ::PlatformObject
    ::PlatformObject set Active Yes

    ::InstallJammer::File      ::FileObject
    ::InstallJammer::FileGroup ::FileGroupObject
    ::InstallJammer::Component ::ComponentObject
    ::InstallJammer::SetupType ::SetupTypeObject
    ::InstallJammer::ActionGroup ::ActionGroupObject

    ## If we're running in command-line mode, we don't need to go any
    ## further.  If we're not in command-line mode, and we don't have
    ## a display, we exit out.  CheckRunStatus figures all this out.
    CheckRunStatus

    Status "Loading packages..."

    package require Tktags
    package require BWidget 2.0
    BWidget::use png
    BWidget::use ttk
    set ::BWidget::iconLibrary InstallJammerIcons

    if {$conf(osx)} {
        BWidget::use aqua
    }

    if {$conf(windows) && $::tcl_platform(osVersion) >= 5.0} {
        package require twapi
    }

    if {$conf(osx)} {
	set conf(installs) [::InstallJammer::InstallJammerHome projects]
    } elseif {$conf(unix)} {
	set conf(installs) [::InstallJammer::HomeDir $conf(InstallsDir)]
    } else {
	set docs [::InstallJammer::WindowsDir MYDOCUMENTS]
	set conf(installs) [file join $docs $conf(InstallsDir)]
    }

    if {![info exists preferences(ProjectDir)]
    	|| ![file exists $preferences(ProjectDir)]} {
        set preferences(ProjectDir) $conf(installs)
    } else {
	set conf(installs) $preferences(ProjectDir)
    }
    set conf(lastdir) $preferences(ProjectDir)

    file mkdir $conf(installs)

    if {$conf(unix)} {
        append ::env(PATH) ":[file join $conf(pwd) lib packages xdg-utils]"
    }

    ::InstallJammer::GuiInit

    return
}

proc main {} {
    global conf

    set base .installjammer

    Status "Building windows..."

    ## Build the main window first.
    Window show $base

    tag configure project -state disabled

    Window show $base

    raise .splash

    Status "InstallJammer loaded" 3000

    ## Hold the splash image for half a second and then fade it out.
    after 500 {
        ::InstallJammer::FadeWindowOut .splash 1
        image delete ::icon::splash
    }

    tkwait window .splash
    grab release  .splash

    UpdateRecentProjects

    #if {[GetPref CheckForUpdates]} {
        #::InstallJammer::DownloadVersionInfo
    #}

    if {[llength $::argv]} {
        set file [lindex $::argv 0]
        set file [file normalize $file]
        Open $file
    }

    if {[info exists conf(commandPort)]} {
        ::InstallJammer::SendReadySignal
    }

    return
}

if {!$tcl_interactive} { init; main }
