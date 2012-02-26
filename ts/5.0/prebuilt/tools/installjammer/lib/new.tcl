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

namespace eval ::InstallJammer::new {}

proc ::InstallJammer::SetProjectDefaults { {force 0} } {
    global info

    set vars {
        AllowLanguageSelection          "Yes"
	AppName			        "Your Application Name"
        ApplicationID                   ""
        ApplicationURL                  ""
        AutoRefreshFiles                "Yes"
	BuildFailureAction              "Fail (recommended)"
	CancelledInstallAction	        "Rollback and Stop"
	CleanupCancelledInstall         "Yes"
	CommandLineFailureAction        "Fail (recommended)"
	Company			        "Your Company Name"
        CompressionLevel                6
        CompressionMethod               "zlib"
        Copyright                       ""
        DefaultDirectoryLocation        ""
        DefaultLanguage                 "English"
        DefaultToSystemLanguage         "Yes"
        EnableResponseFiles             "Yes"
        ExtractSolidArchivesOnStartup   "No"
        IgnoreDirectories               ""
        IgnoreFiles                     ""
	IncludeDebugging	        "Yes"
        InstallPassword                 ""
	InstallVersion		        "1.0.0.0"
        LastIgnoreDirectories           ""
        LastIgnoreFiles                 ""
        PackageDescription              ""
        PackageLicense                  ""
        PackageMaintainer               ""
        PackageName                     "<%ShortAppName%>"
        PackagePackager                 ""
        PackageRelease                  "<%PatchVersion%>"
        PackageSummary                  ""
        PackageVersion                  "<%MajorVersion%>.<%MinorVersion%>"
        PreserveFileAttributes          "Yes"
        PreserveFilePermissions         "Yes"
        SaveOnlyToplevelDirs            "No"
        ShortAppName                    ""
	SkipUnusedFileGroups	        "Yes"
        UpgradeApplicationID            ""
	Version			        "1.0"
    }

    foreach code [::InstallJammer::GetLanguageCodes] {
        lappend vars Language,$code Yes
    }

    if {$force} {
	array set info $vars
    } else {
	SafeArraySet info $vars
    }
}

proc ::InstallJammer::new::SetDefaults {} {
    global conf
    global info
    global widg
    global newinfo

    variable ::NewInstall::vars
    variable ::NewInstall::platforms

    ::InstallJammer::SetProjectDefaults 1
    lassign_array [split $info(InstallVersion) .] info \
        MajorVersion MinorVersion PatchVersion BuildVersion
    array set newinfo [array get info]
    set newinfo(ShortAppName) "yourapp"

    set themes [::InstallJammer::ThemeList]
    if {[lsearch -exact $themes $conf(DefaultTheme)] > -1} {
        set theme $conf(DefaultTheme)
    } else {
        set theme [file tail [lindex $themes 0]]
    }

    set vars(theme) $theme

    set name [NextProjectName "Install Project" 1]

    set vars(applocation)        ""
    set vars(projectname)        $name
    set vars(projectdirprefix)   [GetPref ProjectDir]
    set vars(projectdir)         [file join [GetPref ProjectDir] $name]
    set vars(programShortcut)    1
    set vars(includeCustomSetup) 1
    set vars(includeUninstall)   1
    set vars(uninstallRegistry)  1
    set vars(uninstallShortcut)  1

    set vars(UNIXAppExecutable)    ""
    set vars(WindowsAppExecutable) ""

    set vars(ViewReadmeCheckbutton)          1
    set vars(LaunchAppCheckbutton)           1
    set vars(DesktopShortcutCheckbutton)     1
    set vars(QuickLaunchShortcutCheckbutton) 1

    foreach platform [concat [AllPlatforms] $conf(Archives)] {
        set platforms($platform) 0
    }

    set platforms([::InstallJammer::Platform]) 1
}

proc New {} {
    if {![Close]} { return 0 }
    ::InstallJammer::new::SetDefaults
    ::NewInstall::Done
}

proc NewFromWizard {} {
    global conf
    global info
    global widg
    global newinfo

    variable ::NewInstall::vars
    variable ::NewInstall::platforms

    ## Close any previously opened project.
    if {![Close]} { return 0 }

    set w $widg(InstallJammer).newWizard
    set ::NewInstall::base $w

    ::InstallJammer::SetProjectDefaults 1
    array set newinfo [array get info]
    set newinfo(ShortAppName) "yourapp"

    set width  475
    set bwidth 12
    set height 350
    if {!$conf(windows)} {
	set bwidth 6
	set height 400
    }

    SimpleWizard $w -createstep 0 \
    	-parent $widg(InstallJammer) \
    	-title "Install Project Wizard" \
        -separatortext "Install Project Wizard" \
    	-finishbutton 1 -helpbutton 1 \
	-minwidth $width -minheight $height -buttonwidth $bwidth

    bind $w <Escape> [list $w cancel 1]

    ::InstallJammer::Grab $w

    set step 0

    $w insert step end root project \
    	-text1 "Step [incr step]" \
    	-text2 "Project Information" \
    	-text3 "Fill in the information required for this project below" \
    	-createcommand ::NewInstall::project \
    	-nextcommand   ::NewInstall::CheckProjectName

    $w insert step end root application \
    	-text1 "Step [incr step]" \
    	-text2 "Application Strings" \
    	-text3 "Fill in the information about your application below" \
    	-createcommand ::NewInstall::application

    $w insert step end root appinfo -createstep 0 \
    	-text1 "Step [incr step]" \
    	-text2 "Application Information" \
    	-text3 "Fill in the information about your application below" \
    	-createcommand ::NewInstall::appinfo

    set    text "This is the location of your application on the local "
    append text "system.  This directory will be applied to your install "
    append text "project as the initial source of files for the install, "
    append text "and you will be able to add other files and directories "
    append text "to your project later."
    append text "\n\nThis directory should be the main directory of the "
    append text "application you will be installing."

    $w insert step end root applocation \
    	-text1 "Step [incr step]" \
    	-text2 "Application Location" \
    	-text3 "$text" \
    	-createcommand ::NewInstall::applocation

    if {[llength [::InstallJammer::ThemeList]] > 1} {
	$w insert step end root themes \
	    -text1 "Step [incr step]" \
	    -text2 "Theme Selection" \
	    -text3 "Select the theme for this install" \
	    -createcommand ::NewInstall::themes
    }

    set platformlist [concat [AllPlatforms] $conf(Archives)]

    if {[llength $platformlist] > 1} {
	$w insert step end root platforms \
	    -text1 "Step [incr step]" \
	    -text2 "Platform Selection" \
	    -text3 "Select the platforms for this install" \
	    -createcommand ::NewInstall::platforms \
	    -nextcommand   ::NewInstall::CheckPlatforms
    }

    $w insert step end root additions \
    	-text1 "Step [incr step]" \
    	-text2 "Additional Features" \
    	-text3 "Select the additional features you would like in your install" \
    	-createcommand ::NewInstall::additions

    set    text "InstallJammer is now ready to build your install\n\n"
    append text "Click the Finish button to build your new install "
    append text "project, or click the Cancel button to cancel this "
    append text "project.\n\n"
    append text "Click Back to go back and change your settings "
    append text "before creating this project."

    $w insert step end root done \
    	-text1 "Final Step" \
    	-text2 "Create Install" \
    	-text3 $text

    ## The user should still be able to cancel and go back on the last step.
    bind $w <<WizardLastStep>> {
	%W itemconfigure back   -state normal
	%W itemconfigure cancel -state normal
    }

    ## Leave the finish button on all the time.
    bind $w <<WizardStep>> {
	%W itemconfigure finish -state normal
    }

    bind $w <<WizardCancel>> {
        destroy %W
        unset ::info
        unset ::newinfo
    }

    bind $w <<WizardHelp>> [list Help CreateANewInstallStep-by-Step]

    ## Finish the wizard and create the install.
    bind $w <<WizardFinish>> { ::NewInstall::Done }

    ::InstallJammer::new::SetDefaults

    $w next 1

    BWidget::place $w 0 0 center $widg(InstallJammer)

    $w show
}

namespace eval ::NewInstall {
    variable base ""

proc ::NewInstall::CreateWindow { wizard step } {
    set base  [$wizard widget get $step]
    set frame $base.titleframe

    grid rowconfigure    $base 3 -weight 1
    grid columnconfigure $base 0 -weight 1

    frame $frame -bd 0 -relief flat -background #FFFFFF
    grid  $frame -row 0 -column 0 -sticky nsew

    grid rowconfigure    $frame 1 -weight 1
    grid columnconfigure $frame 0 -weight 1

    Label $frame.title -background #FFFFFF -anchor nw -justify left \
        -autowrap 1 -font TkCaptionFont \
        -textvariable [$wizard variable $step -text1]
    grid $frame.title -row 0 -column 0 -sticky new -padx 5 -pady 5
    $wizard widget set Title -step $step -widget $frame.title

    Label $frame.subtitle -background #FFFFFF -anchor nw -autowrap 1 \
        -justify left -textvariable [$wizard variable $step -text2]
    grid $frame.subtitle -row 1 -column 0 -sticky new -padx [list 20 5]
    $wizard widget set Subtitle -step $step -widget $frame.subtitle

    label $frame.icon -borderwidth 0 -background #FFFFFF -anchor c
    grid  $frame.icon -row 0 -column 1 -rowspan 2
    $wizard widget set Icon -step $step -widget $frame.icon

    Separator $base.separator -relief groove -orient horizontal
    grid $base.separator -row 1 -column 0 -sticky ew 

    Label $base.caption -anchor nw -justify left -autowrap 1 \
        -textvariable [$wizard variable $step -text3]
    grid $base.caption -row 2 -sticky nsew -padx 8 -pady [list 8 4]
    $wizard widget set Caption -step $step -widget $base.caption

    frame $base.clientarea
    grid  $base.clientarea -row 3 -sticky nsew -padx 8 -pady 4
    $wizard widget set clientArea -step $step -widget $base.clientarea

    Label $base.message -anchor nw -justify left -autowrap 1 \
        -textvariable [$wizard variable $step -text4]
    grid $base.message -row 4 -sticky nsew -padx 8 -pady [list 4 8]
    $wizard widget set Message -step $step -widget $base.message
}

proc project {} {
    variable base
    variable vars

    set f [$base widget get clientArea -step project]

    label $f.l1 -text "Project Name" -underline 0
    ENTRY $f.e1 -width 40 -textvariable ::NewInstall::vars(projectname) \
        -validate key -validatecommand "::NewInstall::AdjustProjectName %P"
    pack  $f.l1 -anchor w -pady [list 2 0]
    pack  $f.e1 -anchor w -padx 3

    label $f.l2 -text "Project Root Directory" -underline 8
    pack  $f.l2 -anchor w -pady [list 2 0]

    set f1 [frame $f.projectdir]
    pack $f1 -anchor w -padx 3 -fill x

    ENTRY $f1.e -textvariable ::NewInstall::vars(projectdirprefix) \
        -validate key -validatecommand "::NewInstall::AdjustProjectPrefix %P"
    pack  $f1.e -side left -expand 1 -fill x

    BrowseButton $f1.b -command ::NewInstall::SetProjectDir
    pack $f1.b -side left

    label $f.l3 -text "Project Directory"
    pack  $f.l3 -anchor w -pady [list 2 0]

    Label $f.l4 -relief sunken -bd 2 -padx 2 \
        -elide 1 -elidepadx 10 -elideside center \
        -textvariable ::NewInstall::vars(projectdir)
    pack  $f.l4 -anchor w -fill x

    bind $base <Alt-p> "focus $f.e1"

    focus $f.e1
    $f.e1 selection range 0 end
}

proc application {} {
    variable base

    set f1 [$base widget get clientArea -step application]

    $f1 configure -bd 2 -padx 6

    label $f1.l1 -text "Application Name" -underline 0
    pack  $f1.l1 -anchor w -pady [list 2 0]
    ENTRY $f1.e1 -width 40 -textvariable newinfo(AppName)
    pack  $f1.e1 -anchor w -padx 3
    DynamicHelp::add $f1.l1 -text "The full name of your application not\
        including a version"

    label $f1.l5 -text "Short Application Name" -underline 0
    pack  $f1.l5 -anchor w -pady [list 2 0]
    ENTRY $f1.e5 -width 40 -textvariable newinfo(ShortAppName)
    pack  $f1.e5 -anchor w -padx 3
    DynamicHelp::add $f1.l5 -text "A short name for your application like\
        you would use for a UNIX directory name"

    label $f1.l2 -text "Version" -underline 0
    pack  $f1.l2 -anchor w -pady [list 2 0]
    ENTRY $f1.e2 -width 40 -textvariable newinfo(Version)
    pack  $f1.e2 -anchor w -padx 3
    DynamicHelp::add $f1.l2 -text "The current version of your application\
        (like: 1.0, 2.0a1, 2.0 Build 200, etc...)"

    label $f1.l3 -text "Company" -underline 0
    pack  $f1.l3 -anchor w -pady [list 2 0]
    ENTRY $f1.e3 -width 40 -textvariable newinfo(Company)
    pack  $f1.e3 -anchor w -padx 3
    DynamicHelp::add $f1.l3 -text "Your name or the name of the organization\
        or company who develops this application"

    bind $base <Alt-a> "focus $f1.e1"
    bind $base <Alt-v> "focus $f1.e2"
    bind $base <Alt-c> "focus $f1.e3"

    focus $f1.e1
    $f1.e1 selection range 0 end
}

proc appinfo {} {
    variable base

    variable ::NewInstall::vars

    set f1 [$base widget get clientArea -step appinfo]

    set vars(UNIXAppExecutable)    $::newinfo(ShortAppName)
    set vars(WindowsAppExecutable) $::newinfo(ShortAppName).exe

    label $f1.l4 -text "Install Version"
    pack  $f1.l4 -anchor w -pady [list 2 0]
    VersionFrame $f1.version ::newinfo
    pack $f1.version -anchor w -padx 4
    DynamicHelp::add $f1.l4 -text "The Install Version is used by InstallJammer\
        to track the version of files in your application for upgrade\
        installations."

    label $f1.l6 -text "Windows Application Executable \
        (like: myapp.exe, yourapp.exe, etc...)"
    pack  $f1.l6 -anchor w -pady [list 2 0]
    ENTRY $f1.e6 -width 40 \
        -textvariable ::NewInstall::vars(WindowsAppExecutable)
    pack  $f1.e6 -anchor w -padx 3
    DynamicHelp::add $f1.l6 -text "This is the name of the main executable\
        of your application on a Windows platform.  This should be relative\
        to the target install directory."

    label $f1.l5 -text "UNIX Application Executable \
        (like: myapp, bin/yourapp.sh, etc...)"
    pack  $f1.l5 -anchor w -pady [list 2 0]
    ENTRY $f1.e5 -width 40 -textvariable ::NewInstall::vars(UNIXAppExecutable)
    pack  $f1.e5 -anchor w -padx 3
    DynamicHelp::add $f1.l5 -text "This is the name of the main executable\
        of your application on a non-Windows platform.  This should be\
        relative to the target install directory."
}

proc applocation {} {
    variable base

    set f [$base widget get clientArea -step applocation]

    label $f.l -text "Your Application Directory:"
    pack  $f.l -anchor w

    set f1 [frame $f.apploc]
    pack $f1 -anchor w -fill x

    ENTRY $f1.e -textvariable ::NewInstall::vars(applocation)
    pack  $f1.e -side left -expand 1 -fill x

    BrowseButton $f1.b -command \
    	[list GetDir ::NewInstall::vars(applocation) -parent $base]
    pack $f1.b -side left
}

proc themes {} {
    global info
    variable base
    variable vars

    set themes [::InstallJammer::ThemeList]

    if {[llength $themes] == 1} {
	set theme [lindex $themes 0]
        set vars(theme) [file tail $theme]
    	return
    }

    set f [$base widget get clientArea -step themes]

    set sw [ScrolledWindow $f.sw]
    set t  [OPTIONTREE $sw.t -height 5]
    $sw setwidget $t
    foreach theme [lsort $themes] {
	set name [split $theme _]
        $t insert end root #auto -type radiobutton \
            -variable ::NewInstall::vars(theme) -text $name -value $theme
    }
    pack $sw -expand 1 -fill both
}

proc additions {} {
    global conf

    variable base
    variable vars

    set f [$base widget get clientArea -step additions]

    set sw [ScrolledWindow $f.sw]
    set t  [OPTIONTREE $sw.t -height 5 -deltay 25]
    $sw setwidget $t

    $t insert end root #auto -type checkbutton \
        -variable ::NewInstall::vars(includeCustomSetup) \
        -text "Allow users to select custom components in your install"

    set i [$t insert end root #auto -type checkbutton -open 1 \
        -drawcross never \
    	-variable ::NewInstall::vars(includeUninstall) \
    	-text "Include an uninstaller"]

    $t insert end $i #auto -type checkbutton \
    	-variable ::NewInstall::vars(uninstallRegistry) \
    	-text "Add the uninstaller to the Windows Add/Remove Programs registry"

    $t insert end $i #auto -type checkbutton \
    	-variable ::NewInstall::vars(uninstallShortcut) \
    	-text "Add a Windows Program shortcut component for the uninstaller"

    $t insert end root #auto -type checkbutton \
    	-variable ::NewInstall::vars(programShortcut) \
    	-text "Add a Windows Program shortcut component for this application"

    set i [$t insert end root #auto -drawcross never -open 1 \
        -font TkCaptionFont -text "Setup Complete Pane Options"]

        $t insert end $i #auto -type checkbutton \
            -variable ::NewInstall::vars(ViewReadmeCheckbutton) \
            -text "Add a View Readme checkbutton"

        $t insert end $i #auto -type checkbutton \
            -variable ::NewInstall::vars(LaunchAppCheckbutton) \
            -text "Add a Launch Application checkbutton"

        $t insert end $i #auto -type checkbutton \
            -variable ::NewInstall::vars(DesktopShortcutCheckbutton) \
            -text "Add a Create Desktop Shortcut checkbutton"

        $t insert end $i #auto -type checkbutton \
            -variable ::NewInstall::vars(QuickLaunchShortcutCheckbutton) \
            -text "Add a Create Quick Launch checkbutton"

    $t insert end root #auto

    pack $sw -expand 1 -fill both

    focus $t
}

proc platforms {} {
    global conf
    global info
    variable base
    variable platforms

    set platformlist [concat [AllPlatforms] $conf(Archives)]

    set f [$base widget get clientArea -step platforms]

    set sw [ScrolledWindow $f.sw]
    set t  [OPTIONTREE $sw.t -height 5]
    $sw setwidget $t
    foreach platform $platformlist {
        $t insert end root #auto -type checkbutton \
	    -variable ::NewInstall::platforms($platform) \
	    -text [PlatformText $platform]
    }
    pack $sw -expand 1 -fill both
}

proc CheckProjectName {} {
    global conf

    variable base
    variable vars

    if {[lempty $vars(projectname)]} {
    	::InstallJammer::MessageBox -parent $base -title "No Project Name" \
            -message "You must specify a Project Name for this project."
	focus [$base widget get clientArea].e1
	return 0
    }

    if {[file exists $vars(projectdir)]} {
    	::InstallJammer::MessageBox -parent $base -title "Directory Exists" \
            -message "This directory already exists.  There may be another\
                        project using this name."
	focus [$base widget get clientArea].e1
	return 0
    }

    return 1
}

proc SetProjectDir {} {
    variable base
    GetDir ::NewInstall::vars(projectdirprefix) -parent $base
    ::NewInstall::AdjustProjectPrefix
}

proc AdjustProjectPrefix { {new ""} } {
    variable vars
    if {![string length $new]} { set new $vars(projectdirprefix) }
    set vars(projectdir) [file join $new $vars(projectname)]
    return 1
}

proc AdjustProjectName { {new ""} } {
    variable vars
    if {![string length $new]} { set new $vars(projectname) }
    set vars(projectdir) [file join $vars(projectdirprefix) $new]
    return 1
}

proc CheckPlatforms {} {
    variable base
    variable platforms

    set found 0
    foreach platform [array names platforms] {
    	if {!$platforms($platform)} { continue }
	set found 1
	break
    }

    if {!$found} {
    	::InstallJammer::MessageBox -parent $base -title "No Platform" \
            -message "You must specify at least one platform."
	return 0
    }

    return 1
}

proc ::NewInstall::AddConsoleInstall {} {
    ## Create the default Console install.
    set act [::InstallJammer::AddAction Install ConsoleAskYesOrNo \
        -parent ConsoleInstall -title "Prompt to continue installation"]
    $act set Prompt "<%InstallStartupText%>"
    $act set Default "Yes"

    set act [::InstallJammer::AddAction Install Exit -parent ConsoleInstall \
        -title "Exit if they said no"]
        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String   "<%Answer%>"
        $con set Operator "false"

    set act [::InstallJammer::AddAction Install ConsoleGetUserInput \
        -parent ConsoleInstall -title "Prompt for install destination"]
    $act set Prompt "<%ConsoleSelectDestinationText%>"
    $act set VirtualText InstallDir

        set con [::InstallJammer::AddCondition FilePermissionCondition \
            -parent $act]
        $con set Filename       "<%InstallDir%>"
        $con set Permission     "can create"
        $con set FailureMessage "<%DirectoryPermissionText%>"
        $con set CheckCondition "Before Next Action is Executed"

    set act [::InstallJammer::AddAction Install ConsoleMessage \
        -parent ConsoleInstall -title "Output Installing Message"]
    $act setText all Message "<%InstallingApplicationText%>"

    set act [::InstallJammer::AddAction Install ExecuteAction \
        -parent ConsoleInstall -title "Install Everything"]
    $act set Action "Install Actions"

    set act [::InstallJammer::AddAction Install ConsoleMessage \
        -parent ConsoleInstall -title "Output Install Complete Message"]
    $act setText all Message "<%InstallationCompleteText%>"

    set act [::InstallJammer::AddAction Install Exit -parent ConsoleInstall]
    $act set ExitType Finish


    ## Create the default Console uninstall.
    set act [::InstallJammer::AddAction Uninstall ConsoleAskYesOrNo \
        -parent ConsoleUninstall]
    $act set Prompt "<%UninstallStartupText%>"
    $act set Default "Yes"

    set act [::InstallJammer::AddAction Uninstall Exit -parent ConsoleUninstall]
        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String   "<%Answer%>"
        $con set Operator "false"

    set act [::InstallJammer::AddAction Uninstall ConsoleMessage \
        -parent ConsoleUninstall]
    $act setText all Message "<%UninstallingApplicationText%>"

    set act [::InstallJammer::AddAction Uninstall ExecuteAction \
        -parent ConsoleUninstall]
    $act set Action "Uninstall Actions"

    set act [::InstallJammer::AddAction Uninstall ConsoleMessage \
        -parent ConsoleUninstall]
    $act setText all Message "<%UninstallCompleteText%>"

    set act [::InstallJammer::AddAction Uninstall Exit -parent ConsoleUninstall]
    $act set ExitType Finish
}

proc Done {} {
    global conf
    global info
    global widg
    global newinfo

    variable ::InstallJammer::panes

    variable base
    variable vars
    variable platforms

    ::InstallJammer::StatusPrefix "Creating new project...  "

    ::InstallJammer::SetProjectDefaults 1

    set info(Theme)       $vars(theme)
    set info(ThemeDir)    $vars(theme)

    set info(Project)       $vars(projectname)
    set info(ProjectID)     [::InstallJammer::uuid]
    set info(ProjectDir)    $vars(projectdir)
    set info(ProjectFile)   [file join $info(ProjectDir) $info(Project).mpi]

    set conf(ActiveProject) $vars(projectname)

    ::InstallJammer::AddDefaultCommandLineOptions

    ::InstallJammer::InitializeObjects

    foreach pf [array names platforms] {
        $pf set Active [expr {$platforms($pf) ? "Yes" : "No"}]

        if {$pf eq "Windows"} {
            if {[string length $vars(WindowsAppExecutable)]} {
                $pf set ProgramExecutable \
                    "<%InstallDir%>/$vars(WindowsAppExecutable)"
            }
        } elseif {[::InstallJammer::IsRealPlatform $pf]} {
            if {[string length $vars(UNIXAppExecutable)]} {
                $pf set ProgramExecutable \
                    "<%InstallDir%>/$vars(UNIXAppExecutable)"
            }
        }
    }

    array set info [array get newinfo]

    set info(ApplicationID) [::InstallJammer::uuid]

    set    info(InstallVersion) $info(MajorVersion).$info(MinorVersion)
    append info(InstallVersion) .$info(PatchVersion).$info(BuildVersion)

    if {$vars(ViewReadmeCheckbutton)} {
        set info(ViewReadme) Yes
    }

    if {$vars(LaunchAppCheckbutton)} {
        set info(LaunchApplication) Yes
    }

    if {$vars(DesktopShortcutCheckbutton)} {
        set info(CreateDesktopShortcut) Yes
    }

    if {$vars(QuickLaunchShortcutCheckbutton)} {
        set info(CreateQuickLaunchShortcut) Yes
    }

    Status "Initializing Trees..."

    InitComponentTrees

    ::InstallJammer::LoadMessages

    ::InstallJammer::LoadVirtualText

    ::InstallJammer::LoadCommandLineOptions

    set groupid [::FileGroupTree::New -text "Program Files"]
    $groupid platforms [concat [AllPlatforms] $conf(Archives)]

    set compid [::ComponentTree::New -text "Default Component"]
    $compid platforms  [AllPlatforms]
    $compid set FileGroups [list $groupid]
    $compid set RequiredComponent Yes
    ::InstallJammer::SetVirtualText en $compid \
        Description "<%ProgramFilesDescription%>"

    set id [::SetupTypeTree::New -text "Typical"]
    $id platforms  [AllPlatforms]
    $id set Components [list $compid]
    ::InstallJammer::SetVirtualText en $id \
        Description "<%TypicalInstallDescription%>"

    set id [::SetupTypeTree::New -text "Custom"]
    $id platforms [AllPlatforms]
    $id set Components [list $compid]
    ::InstallJammer::SetVirtualText en $id \
        Description "<%CustomInstallDescription%>"

    Status "Loading [::InstallJammer::StringToTitle $info(Theme)] Theme..."

    LoadTheme

    set info(ThemeVersion) $::InstallJammer::theme(Version)

    Status "Adding Panes and Actions..."

    ## Add the panes to all the requested install types.
    foreach setup $conf(ThemeDirs) {
        foreach pane $conf(PaneList,$setup) {
            set obj $panes($pane)
            if {[lsearch -exact [$obj installtypes] "Common"] < 0
                && ([$obj get Active value value] && !$value)} { continue }

            foreach parent [$obj installtypes] {
                set parent $parent$setup
                set id [::InstallJammer::AddPane $setup $pane -parent $parent]
                foreach action [$id children] {
                    set types([$action component]) 1
                }
            }
        }
    }

    ## Create default Install Action Groups.
    set id [::InstallJammer::AddActionGroup Install \
        -parent ActionGroupsInstall -title "Setup Actions" -edit 0 -open 1]
    $id set Alias "Setup Actions"

    set id [::InstallJammer::AddActionGroup Install \
        -parent ActionGroupsInstall -title "Startup Actions" -edit 0 -open 0]
    $id set Alias "Startup Actions"

    set id [::InstallJammer::AddActionGroup Install \
        -parent ActionGroupsInstall -title "Install Actions" -edit 0 -open 0]
    $id set Alias "Install Actions"

    set id [::InstallJammer::AddActionGroup Install \
        -parent ActionGroupsInstall -title "Finish Actions" -edit 0 -open 0]
    $id set Alias "Finish Actions"
    set installFinishActions $id

    set id [::InstallJammer::AddActionGroup Install \
        -parent ActionGroupsInstall -title "Cancel Actions" -edit 0 -open 1]
    $id set Alias "Cancel Actions"


    ## Add a popup to the Startup Actions that asks the user if
    ## they want to continue the install.
    set act [::InstallJammer::AddAction Install Exit -parent "Startup Actions"]
    $act set Comment "Ask the user if they want to proceed with the install."

    set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
    $con set String   "<%GuiMode%>"
    $con set Operator "true"

    set id [::InstallJammer::AddCondition AskYesOrNo -parent $act]
    $id set TrueValue "No"
    ::InstallJammer::SetVirtualText en $id {
        Title "<%InstallApplicationText%>" Message "<%InstallStartupText%>"
    }

    ## If the theme didn't already add a CreateInstallPanes action,
    ## add it to the Startup Actions.
    if {![info exists types(CreateInstallPanes)]} {
        ::InstallJammer::AddAction Install CreateInstallPanes \
            -parent "Startup Actions"
    }

    ## Add items to the Install Actions.
    ::InstallJammer::AddAction Install InstallSelectedFiles \
        -parent "Install Actions"

    set id [::InstallJammer::AddAction Install ExecuteAction \
        -parent SilentInstall -title "Install Everything"]
    $id set Action "Install Actions"

    set act [::InstallJammer::AddAction Install Exit -parent SilentInstall]
    $act set ExitType Finish

    ## Add default Uninstall Action Groups.
    set id [::InstallJammer::AddActionGroup Uninstall \
        -parent ActionGroupsUninstall -title "Setup Actions" -edit 0 -open 1]
    $id set Alias "Setup Actions"

    set id [::InstallJammer::AddActionGroup Uninstall \
        -parent ActionGroupsUninstall -title "Startup Actions" -edit 0 -open 0]
    $id set Alias "Startup Actions"

    set id [::InstallJammer::AddActionGroup Uninstall \
        -parent ActionGroupsUninstall -title "Uninstall Actions" \
	-edit 0 -open 0]
    $id set Alias "Uninstall Actions"

    set id [::InstallJammer::AddActionGroup Uninstall \
        -parent ActionGroupsUninstall -title "Finish Actions" -edit 0 -open 1]
    $id set Alias "Finish Actions"

    set id [::InstallJammer::AddActionGroup Uninstall \
        -parent ActionGroupsUninstall -title "Cancel Actions" -edit 0 -open 1]
    $id set Alias "Cancel Actions"

    ## Add items to the Uninstall Startup Actions.
    set act [::InstallJammer::AddAction Uninstall Exit \
        -parent "Startup Actions"]
    $act set Comment "Ask the user if they want to proceed with the uninstall."

    set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
    $con set String   "<%GuiMode%>"
    $con set Operator "true"

    set id [::InstallJammer::AddCondition AskYesOrNo -parent $act]
    $id set TrueValue "No"
    ::InstallJammer::SetVirtualText en $id {
        Title "<%UninstallApplicationText%>" Message "<%UninstallStartupText%>"
    }

    ## Add items to the Uninstall Actions.
    ::InstallJammer::AddAction Uninstall UninstallSelectedFiles \
        -parent "Uninstall Actions"

    set id [::InstallJammer::AddAction Uninstall ExecuteAction \
        -parent SilentUninstall -title "Uninstall Everything"]
    $id set Action "Uninstall Actions"

    set act [::InstallJammer::AddAction Uninstall Exit -parent SilentUninstall]
    $act set ExitType Finish

    if {[::InstallJammer::CommandExists ::InstallJammer::theme::NewProject]} {
        ::InstallJammer::theme::NewProject vars
    }

    ::NewInstall::AddConsoleInstall

    set conf(projectLoaded) 1

    if {[string length $vars(applocation)]} {
        Status "Adding Files..."

        set id [AddToFileGroup -name $vars(applocation) -group $groupid \
            -parent $groupid -type dir]
        $id directory "<%InstallDir%>"
        $id set Comment \
            "Base application directory.  Install to <%InstallDir%>."

        ::InstallJammer::RecursiveGetFiles $id
    }

    tag configure project -state normal

    destroy $base

    ::InstallJammer::Grab release $base

    BuildInstall

    if {$vars(includeUninstall)} {
        set act [::InstallJammer::AddAction Install InstallUninstaller \
            -parent "Install Actions"]

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set Operator false
        $con set String   "<%UpgradeInstall%>"
    }

    if {$vars(uninstallRegistry)} {
        set act [::InstallJammer::AddAction Install AddWindowsUninstallEntry \
            -parent "Install Actions" -title "Windows Uninstall Registry"]

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set Operator false
        $con set String   "<%UpgradeInstall%>"
    }

    if {$vars(programShortcut)} {
        set act [::InstallJammer::AddAction Install \
            InstallProgramFolderShortcut \
            -parent "Install Actions" -title "Program Shortcut"]
        $act set FileName         "<%ShortAppName%>-program"
        $act set ShortcutName     "<%AppName%>"
        $act set TargetFileName   "<%ProgramExecutable%>"
        $act set WorkingDirectory "<%InstallDir%>"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set Operator false
        $con set String   "<%UpgradeInstall%>"
    }

    if {$vars(uninstallShortcut)} {
        set act [::InstallJammer::AddAction Install \
            InstallProgramFolderShortcut \
            -parent "Install Actions" -title "Uninstall Shortcut"]
        $act set FileName         "<%ShortAppName%>-uninstall"
        $act set ShortcutName     "Uninstall <%AppName%>"
        $act set TargetFileName   "<%Uninstaller%>"
        $act set WorkingDirectory "<%InstallDir%>"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set Operator false
        $con set String   "<%UpgradeInstall%>"
    }

    if {$vars(DesktopShortcutCheckbutton)} {
        set act [::InstallJammer::AddAction Install InstallDesktopShortcut \
                -parent $installFinishActions]
        $act set FileName         "<%ShortAppName%>-desktop"
        $act set ShortcutName     "<%AppName%>"
        $act set TargetFileName   "<%ProgramExecutable%>"
        $act set WorkingDirectory "<%InstallDir%>"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String "<%CreateDesktopShortcut%>"

        set con [::InstallJammer::AddCondition FileExistsCondition -parent $act]
        $con set Filename "<%ProgramExecutable%>"
    }

    if {$vars(QuickLaunchShortcutCheckbutton)} {
        set act [::InstallJammer::AddAction Install InstallWindowsShortcut \
                -parent $installFinishActions \
                -title "Install Quick Launch Shortcut"]
        $act set ShortcutName      "<%AppName%>"
        $act set TargetFileName    "<%ProgramExecutable%>"
        $act set WorkingDirectory  "<%InstallDir%>"
        $act set ShortcutDirectory "<%QUICK_LAUNCH%>"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String "<%CreateQuickLaunchShortcut%>"

        set con [::InstallJammer::AddCondition FileExistsCondition -parent $act]
        $con set Filename "<%ProgramExecutable%>"
    }

    if {$vars(ViewReadmeCheckbutton)} {
        set act [::InstallJammer::AddAction Install TextWindow \
                -parent $installFinishActions -title "View Readme Window"]
        $act set TextFile "<%ProgramReadme%>"
        ::InstallJammer::SetVirtualText en $act \
            Message "" \
            Title   "<%ApplicationReadmeText%>" \
            Caption "<%ApplicationReadmeText%>"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String   "<%GuiMode%>"
        $con set Operator "true"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String "<%ViewReadme%>"

        set con [::InstallJammer::AddCondition FileExistsCondition -parent $act]
        $con set Filename "<%ProgramReadme%>"
    }

    if {$vars(LaunchAppCheckbutton)} {
        set act [::InstallJammer::AddAction Install ExecuteExternalProgram \
                -parent $installFinishActions -title "Launch Application"]
        $act set WaitForProgram No
        $act set WorkingDirectory   "<%InstallDir%>"
        $act set ProgramCommandLine "<%ProgramExecutable%>"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String   "<%GuiMode%>"
        $con set Operator "true"

        set con [::InstallJammer::AddCondition StringIsCondition -parent $act]
        $con set String "<%LaunchApplication%>"

        set con [::InstallJammer::AddCondition FileExistsCondition -parent $act]
        $con set Filename "<%ProgramExecutable%>"
    }

    ::InstallJammer::RefreshComponentTitles

    unset vars
    unset platforms

    ClearTmpVars

    Save

    $widg(Product) raise applicationInformation

    $widg(ApplicationInformationPref) open standard

    Status "Done." 3000
    ::InstallJammer::StatusPrefix
}

} ;# namespace eval ::NewInstall
