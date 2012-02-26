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

proc BUTTON { path args } {
    eval [list ::ttk::button $path] $args
}

proc CHECKBUTTON { path args } {
    eval [list ::ttk::checkbutton $path] $args
}

proc COMBOBOX { path args } {
    array set _args $args
    if {[info exists _args(-editable)] && !$_args(-editable)} {
        unset _args(-editable)
        set _args(-state) readonly
    }

    unset -nocomplain _args(-autocomplete)

    eval [list ::ttk::combobox $path] [array get _args]
}

proc ENTRY { path args } {
    eval [list ::ttk::entry $path] $args
}

proc LISTBOX { path args } {
    eval ListBox $path -background #FFFFFF $args
}

proc MENU { path args } {
    eval [list menu $path -bd 1 -relief groove] $args
}

proc OPTIONTREE { path args } {
    eval [list OptionTree $path] $args \
        -radioimage [GetImage radio-off] -radioselectimage [GetImage radio-on] \
        -checkimage [GetImage check-off] -checkselectimage [GetImage check-on]
}

proc PANEDWINDOW { path args } {
    eval [list ::PanedWindow $path] \
        -sashpad 2 -sashwidth 4 -sashrelief ridge $args
}

proc POPUP { path args } {
    eval [list MENU $path] $args
}

proc PREFERENCES { path args } {
    eval [list ::Preferences $path] -padx 5 -treebackground #FFFFFF $args
}

proc PROGRESSBAR { path args } {
    eval [list ::ttk::progressbar $path] $args
}

proc PROPERTIES { path args } {
    eval ::Properties $path -expand 1 $args

    $path bindValue <<RightClick>> {
    	::InstallJammer::PostPropertiesRightClick %W %n %X %Y
    }

    bind $path <<PropertiesEditStart>> \
        "::InstallJammer::SetActivePropertyNode %W"

    return $path
}

proc RADIOBUTTON { path args } {
    eval [list ::ttk::radiobutton $path] $args
}

proc SPINBOX { path args } {
    eval ::spinbox $path -bg #FFFFFF $args
}

proc TREE { path args } {
    eval Tree $path -linesfill #CACACA -bg #FFFFFF -highlightthickness 0 $args
}

proc BIND { window args } {
    eval [list bind $window] $args
    if {$::conf(osx) && [string match "*Control-*" [lindex $args 0]]} {
        set event [string map {Control- Command-} [lindex $args 0]]
        eval [list bind $window] [lreplace $args 0 0 $event]
    }
}

proc ::InstallJammer::PostPropertiesRightClick { prop node x y } {
    global conf
    global widg

    set conf(x)    $x
    set conf(y)    $y
    set conf(prop) $prop
    set conf(node) $node
    $widg(PropertiesRightClick) post $x $y
}

proc mpi_chooseDirectory {args} {
    global conf
    global widg

    set data(-parent)     $widg(InstallJammer)
    set data(-initialdir) $conf(lastdir)

    array set data $args

    switch -- $::tcl_platform(platform) {
	"windows" {
	    if {[info exists data(-initialdir)]
                && [file exists $data(-initialdir)]} {
		set data(-initialdir) [file attributes $data(-initialdir) -long]
	    }
	}
    }

    if {![file exists $data(-initialdir)]} {
    	unset data(-initialdir)
    }

    set args [array get data]

    if {$conf(windows) || $conf(osx)} {
	set dir [eval tk_chooseDirectory $args]
    } else {
	set win [::InstallJammer::TopName .__chooseDirectory]
	set dir [eval [list ChooseDirectory $win -name ChooseDirectory] $args]
    }

    if {[string length $dir]} { set conf(lastdir) $dir }

    return $dir
}

proc mpi_getSaveFile {args} {
    global conf
    global widg

    set data(-parent)     $widg(InstallJammer)
    set data(-initialdir) $conf(lastdir)

    array set data $args

    if {![file exists $data(-initialdir)]} {
    	unset data(-initialdir)
    }

    if {$conf(windows) || $conf(osx)} {
        set file [eval tk_getSaveFile [array get data]]
    } else {
        set file [eval ChooseFile .__chooseFile -type save [array get data]]
    }

    if {[string length $file]} { set conf(lastdir) [file dirname $file] }

    return $file
}

proc mpi_getOpenFile {args} {
    global conf
    global widg

    set data(-parent)     $widg(InstallJammer)
    set data(-initialdir) $conf(lastdir)

    array set data $args

    if {![file exists $data(-initialdir)]} {
    	unset data(-initialdir)
    }

    if {$conf(windows) || $conf(osx)} {
        set file [eval tk_getOpenFile [array get data]]
    } else {
        set file [eval ChooseFile .__chooseFile [array get data]]
    }

    if {[string length $file]} { set conf(lastdir) [file dirname $file] }

    return $file
}

proc BrowseButton {w args} {
    eval WinButton $w -image [GetImage folderopen16] $args
    DynamicHelp::register $w balloon "Browse"
}

proc WinButton { path args } {
    return [eval [list Button $path -style Toolbutton] $args]

    eval [list button $path] -highlightthickness 0 $args -relief flat
    bind $path <Enter> {
	if {[%W cget -state] == "normal"} { %W configure -relief raised }
    }
    bind $path <Leave> [list %W configure -relief flat]
    return $path
}

proc WinMenuButton { path args } {
    return [eval [list ttk::menubutton $path] $args]

    eval [list menubutton $path] -highlightthickness 0 $args -relief flat
    bind $path <Enter> {
	if {[%W cget -state] == "normal"} { %W configure -relief raised }
    }
    bind $path <Leave> [list %W configure -relief flat]
    return $path
}

proc DirListComboBox {w platform args} {
    if {[winfo exists $w]} {
	$w configure -values [InstallDirList $platform]
	return $w
    }
    return [eval COMBOBOX $w -values [list [InstallDirList $platform]] $args]
}

proc WindowsIconComboBox { w args } {
    if {[winfo exists $w]} {
	$w configure -values [GetIconList]
	return $w
    }
    return [eval COMBOBOX $w -width 50 -values [list [GetIconList]] $args]
}

proc Window.installjammer { {base .installjammer} } {
    global conf
    global widg
    global preferences

    set widg(InstallJammer)      $base
    set widg(Main)               $base.main
    set widg(MainMenu)           $base.m
    set widg(MainEditMenu)       $base.m.edit
    set widg(MainFileMenu)       $base.m.file
    set widg(MainBuildMenu)      $base.m.build
    set widg(MainHelpMenu)       $base.m.helpm

    set geometry 800x600+50+0
    if {[info exists preferences(Geometry)]} {
        set geometry $preferences(Geometry)
    }

    if {[winfo exists $base]} {
        wm geometry  $base $geometry
        wm deiconify $base

        if {[info exists preferences(Zoomed)] && $preferences(Zoomed)} {
            wm state $base zoomed
        }

        return
    }

    toplevel    $base -class Installjammer
    wm withdraw $base
    update idletasks
    wm geometry $base $geometry
    wm protocol $base WM_DELETE_WINDOW Exit
    wm minsize  $base 640 480

    ::InstallJammer::SetMainWindowTitle

    if {[string length [package provide twapi]]} {
        set title "InstallJammer - Multiplatform Installer"
        set conf(hwin) [twapi::find_windows -text $title]
    }

    BIND all <F1> {Help $conf(HelpTopic)}

    BIND $base <F7> { Build }
    BIND $base <Control-F5> { TestInstall }

    BIND $base <Control-b> { ::InstallJammer::QuickBuild }
    BIND $base <Control-B> { ::InstallJammer::QuickBuild }
    BIND $base <Control-Shift-b> { Build }
    BIND $base <Control-Shift-B> { Build }
    BIND $base <Control-r> { TestInstall }
    BIND $base <Control-R> { TestInstall }

    BIND $base <Control-n> "NewFromWizard"
    BIND $base <Control-o> "Open"
    BIND $base <Control-s> "Save"

    InstallJammerIcons add blank -imageargs [list -width 16 -height 16]

    $base configure -menu $base.m

    ## Create the main menu
    set m [menu $widg(MainMenu)]
    MENU $widg(MainFileMenu)
    MENU $widg(MainEditMenu)
    MENU $widg(MainBuildMenu)
    MENU $widg(MainHelpMenu)

    $m add cascade -label File -menu $m.file -underline 0

    $m.file add command -label "New" -underline 0 -accel "Ctrl+N" \
    	-command New -image [GetImage filenew16] -compound left
    $m.file add command -label "New Project Wizard..." \
    	-command NewFromWizard -image [GetImage filenew16] -compound left
    $m.file add command -label "Open..." -underline 0 -accel "Ctrl+O" \
        -command Open -image [GetImage fileopen16] -compound left
    $m.file add command -label "Close" -underline 0 -command Close \
    	-image [GetImage fileclose16] -compound left
    $m.file add separator
    $m.file add command -label "Save" -underline 0 -accel "Ctrl+S" \
        -command Save -image [GetImage filesave16] -compound left
    $m.file add command -label "Save as..." -underline 5 -command SaveAs \
    	-image [GetImage filesaveas16] -compound left
    $m.file add separator
    $m.file add command -label Exit -underline 1 -command Exit \
    	-image [GetImage actexit16] -compound left
    
    tag add project [list $m.file "Save"]
    tag add project [list $m.file "Save as..."]
    tag add project [list $m.file "Close"]

    $m add cascade -label Edit -menu $m.edit -underline 0

    $m.edit add command -label Cut -underline 2 -accel "Ctrl+X" \
    	-command ::InstallJammer::EditCut \
    	-image [GetImage editcut16] -compound left
    $m.edit add command -label Copy -underline 0 -accel "Ctrl+C" \
    	-command ::InstallJammer::EditCopy \
    	-image [GetImage editcopy16] -compound left
    $m.edit add command -label Paste -underline 0 -accel "Ctrl+V" \
    	-command ::InstallJammer::EditPaste \
    	-image [GetImage editpaste16] -compound left
    $m.edit add command -label Delete -underline 0 -accel "Delete" \
    	-command ::InstallJammer::EditDelete \
    	-image [GetImage editdelete16] -compound left
    $m.edit add separator
    $m.edit add command -label "Select All" -underline 7 -accel "Ctrl+A" \
    	-command ::InstallJammer::EditSelectAll \
    	-image [GetImage blank] -compound left
    $m.edit add separator
    $m.edit add command -label "Preferences..." -underline 0 \
    	-command "Window show .preferences" \
    	-image [GetImage actconfigure16] -compound left

    tag addtag editMenu menuentries $m recursive

    $m add cascade -label Build -menu $m.build -underline 0

    $m.build add command -label "Quick Build Install" -underline 0 \
    	-accel "Ctrl+B" -command ::InstallJammer::QuickBuild \
    	-image [GetImage quickbuild16] -compound left
    $m.build add command -label "Build Install" -underline 0 \
    	-accel "Ctrl+Shift+B" -command "Build" \
    	-image [GetImage build16] -compound left
    $m.build add separator
    $m.build add command -label "Stop Build" -underline 0 \
    	-command ::InstallJammer::StopBuild \
        -image [GetImage actstop16] -compound left
    $m.build add separator
    $m.build add command -label "Run Install" -underline 0 \
    	-accel "Ctrl+R" -command "TestInstall" \
    	-image [GetImage actrun16] -compound left
    $m.build add command -label "Run Uninstall" -underline 4 \
        -command "TestUninstall" -image [GetImage edittrash16] -compound left
    tag add project [list $m.build "Build Install"]
    tag add project [list $m.build "Quick Build Install"]
    tag add project [list $m.build "Stop Build"]
    tag add project [list $m.build "Run Install"]
    tag add project [list $m.build "Run Uninstall"]

    $m add cascade -label Help -menu $m.helpm -underline 0

    if {[::InstallJammer::LocalHelpExists]} {
        $m.helpm add command -label "InstallJammer Help" \
            -underline 0 -accel "F1" -compound left \
            -image [GetImage acthelp16] -command {Help $conf(DefaultHelpTopic)}
        $m.helpm add command -label "Release Notes" -underline 0 \
            -command [list Help ReleaseNotes] -image [GetImage acthelp16] \
            -compound left
        $m.helpm add separator
    }
    $m.helpm add command -label "Online Help" -underline 0 \
        -image [GetImage acthelp16] -compound left \
    	-command [list ::InstallJammer::LaunchBrowser $conf(HelpURL)]
    $m.helpm add command -label "Online Support Forums" -underline 0 \
        -image [GetImage acthelp16] -compound left \
    	-command [list ::InstallJammer::LaunchBrowser $conf(ForumsURL)]
    $m.helpm add separator
    $m.helpm add command -label "Show Debug Console" \
	-underline 0 -command "console show" \
	-image [GetImage displayscreen16] -compound left
    $m.helpm add separator
    $m.helpm add command -label "About InstallJammer" \
        -underline 0 -command "::InstallJammer::AboutInstallJammer" \
        -image [GetImage about16] -compound left

    if {$conf(demo)} {
	$m.helpm add command -label "About Demo Mode" \
	    -underline 0 -command "Help Demo" \
	    -image [GetImage about16] -compound left
    }

    pack [Separator $base.sp1] -fill x
    set toolbar $base.toolbar
    set widg(MainToolbar) $toolbar
    pack [frame $toolbar -bd 1 -relief flat] -anchor w -fill x
    pack [Separator $base.sp2] -fill x
    pack [frame $base.sp3] -pady 5

    set b [WinButton $toolbar.new -image [GetImage filenew22] \
    	-command NewFromWizard]
    pack $b -side left
    DynamicHelp::register $b balloon "New Project Wizard"

    set b [WinButton $toolbar.open -image [GetImage fileopen22] -command Open]
    pack $b -side left
    DynamicHelp::register $b balloon "Open Install"

    set b [WinButton $toolbar.save -image [GetImage filesave22] -command Save]
    pack $b -side left
    DynamicHelp::register $b balloon "Save Install"
    tag add project $b

    set b [WinButton $toolbar.exploreProject \
        -image [GetImage filefind22] -command ::InstallJammer::ExploreProject]
    pack $b -side left
    DynamicHelp::register $b balloon "Explore Project"
    tag add project $b

    pack [Separator $toolbar.sp1 -orient vertical] \
    	-side left -fill y -padx 3 -pady 4

    set widg(BuildButton) [WinButton $toolbar.build \
        -image [GetImage build22] -command Build -state disabled]
    pack $widg(BuildButton) -side left
    DynamicHelp::register $widg(BuildButton) balloon "Build Install"
    tag add project $widg(BuildButton)

    set widg(BuildQuickButton) [WinButton $toolbar.qbuild -state disabled \
        -image [GetImage quickbuild22] -command ::InstallJammer::QuickBuild]
    pack $widg(BuildQuickButton) -side left
    DynamicHelp::register $widg(BuildQuickButton) balloon "Quick Build Install"
    tag add project $widg(BuildQuickButton)

    set widg(StopBuildButton) [WinButton $toolbar.stopbuild -state disabled \
        -image [GetImage actstop22] -command ::InstallJammer::StopBuild]
    pack $widg(StopBuildButton) -side left
    DynamicHelp::register $widg(StopBuildButton) balloon "Stop Build"
    tag add project $widg(StopBuildButton)

    set widg(TestButton) [WinButton $toolbar.test -image [GetImage actrun22] \
    	-command TestInstall -state disabled]
    pack $widg(TestButton) -side left
    DynamicHelp::register $widg(TestButton) balloon "Test Install"
    tag add project $widg(TestButton)

    WinButton $toolbar.exploreInstall -image [GetImage filefind22] \
        -command ::InstallJammer::ExploreTestInstall -state disabled
    pack $toolbar.exploreInstall -side left
    DynamicHelp::add $toolbar.exploreInstall -text "Explore Test Install"
    tag add project  $toolbar.exploreInstall

    WinButton $toolbar.uninstall -image [GetImage edittrash22] \
        -command TestUninstall -state disabled
    pack $toolbar.uninstall -side left
    DynamicHelp::add $toolbar.uninstall -text "Test Uninstall"
    tag add project  $toolbar.uninstall

    WinButton $toolbar.help \
    	-image [GetImage acthelp22] \
    	-command {Help $conf(HelpTopic)}
    pack $toolbar.help -side right
    DynamicHelp::register $toolbar.help balloon "Help"

    set status [StatusBar $base.status]
    set widg(Status) $status
    pack $status -fill x -side bottom
    set f [$status getframe]

    label $f.status -textvariable conf(status) -anchor w -width 1
    $status add $f.status -weight 1 -separator 0

    PROGRESSBAR $f.progress
    set widg(Progress) $f.progress
    $status add $f.progress -separator 0
    grid remove $widg(Progress)

    set n [ttk::notebook $widg(Main)]
    pack $widg(Main) -expand 1 -fill both

    set widg(StartPageTab) [ttk::frame $n.fProjects]
    $n add $widg(StartPageTab) -text "Start Page" \
        -compound left -image [GetImage startpage16]

    set widg(InstallDesignerTab) [ttk::frame $n.fProduct]
    $n add $widg(InstallDesignerTab) -text "Install Designer" -state disabled \
        -compound left -image [GetImage actwizard16]

    $n select $widg(InstallDesignerTab)

    ## Create the Projects tab.
    set widg(Projects) $widg(StartPageTab).c

    ScrolledWindow $widg(StartPageTab).sw
    pack $widg(StartPageTab).sw -expand 1 -fill both

    canvas $widg(Projects) -bg #FFFFFF -bd 2 -relief sunken
    $widg(StartPageTab).sw setwidget $widg(Projects)

    label  $widg(Projects).logo -image logo -background #FFFFFF
    pack   $widg(Projects).logo -side bottom -anchor se -padx 10 -pady 10

    set c $widg(Projects)
    $c bind project <1>     "::InstallJammer::LoadProject 1"
    $c bind project <3>     "::InstallJammer::ProjectPopup %X %Y"
    $c bind project <Enter> "::InstallJammer::EnterProjectItem %W"
    $c bind project <Leave> "::InstallJammer::LeaveProjectItem %W"

    ## Create the Project popup.

    set m [MENU $widg(Projects).rightClick]
    $m add command -label "Open Project" \
        -compound left -image [GetImage fileopen16] \
        -command "::InstallJammer::LoadProject"
    $m add command -label "Explore Project" \
        -compound left -image [GetImage filefind16] \
        -command "::InstallJammer::ExploreProject"
    $m add separator
    $m add command -label "Rename Project" \
        -compound left -image [GetImage editcopy16] \
        -command "::InstallJammer::RenameProject"
    $m add command -label "Duplicate Project" \
        -compound left -image [GetImage editcopy16] \
        -command "::InstallJammer::DuplicateProject"
    $m add separator
    $m add command -label "Delete Project" \
        -compound left -image [GetImage buttoncancel16] \
        -command "::InstallJammer::DeleteProject"

    ## Create the Product tab.
    set widg(Product) $widg(InstallDesignerTab).p

    set opts {}
    if {[info exists preferences(Geometry,Product)]} {
        set opts $preferences(Geometry,Product)
    }

    eval [list PREFERENCES $widg(Product) -showlines 0 -treewidth 215 \
    	-padx [list 10 0] -deltax 5 -deltay 18 -treepadx 5] $opts

    set main $widg(Product)

    $main insert end root general -text "General Information" \
        -font TkCaptionFont -haspage 0
    	$main insert end general applicationInformation \
	    -text "Application Information" \
	    -raisecommand Frame.applicationInformation
    	$main insert end general platformInformation \
	    -text "Platform Information" \
	    -raisecommand Frame.platformInformation
        $main insert end general packageAndArchiveInformation \
            -text "Package and Archive Information" \
            -raisecommand Frame.packageAndArchiveInformation

    $main insert end root groups  -text "Components and Files" \
    	-font TkCaptionFont -haspage 0
    	$main insert end groups groupsAndFiles \
	    -text "Groups and Files" \
	    -raisecommand Frame.groupsAndFiles
	$main insert end groups components \
	    -text "Components" \
	    -raisecommand Frame.components
        $main insert end groups setupTypes \
            -text "Setup Types" \
            -raisecommand Frame.setupTypes

    $main insert end root installInterface -text "Install User Interface" \
        -font TkCaptionFont -haspage 0
        $main insert end installInterface install \
            -text "Install Panes and Actions" \
            -raisecommand Frame.install
        $main insert end installInterface InstallCommandLine \
            -text "Install Command Line Options" \
            -raisecommand [list Frame.commandLine Install]

    $main insert end root uninstallInterface -text "Uninstall User Interface" \
        -font TkCaptionFont -haspage 0
        $main insert end uninstallInterface uninstall \
            -text "Uninstall Panes and Actions" \
            -raisecommand Frame.uninstall
        $main insert end uninstallInterface UninstallCommandLine \
            -text "Uninstall Command Line Options" \
            -raisecommand [list Frame.commandLine Uninstall]

    $main insert end root virtualDefinitions -text "Virtual Definitions" \
    	-font TkCaptionFont -haspage 0
    	$main insert end virtualDefinitions virtualText \
	    -text "Virtual Text Strings" \
	    -raisecommand Frame.virtualText

    $main insert end root builder -text "Run Build" \
        -font TkCaptionFont -haspage 0
    	$main insert end builder diskBuilder -text "Build Installers" \
            -raisecommand Frame.diskBuilder

    $main insert end root test -text "Test the Installation" \
        -font TkCaptionFont -haspage 0
    	$main insert end test testInstaller -text "Test Installer" \
            -raisecommand Frame.testInstaller
    	$main insert end test testUninstaller -text "Test Uninstaller" \
            -raisecommand Frame.testUninstaller

    #Frame.general
    #Frame.applicationInformation
    #Frame.platformInformation
    Frame.groupsAndFiles
    Frame.components
    Frame.setupTypes
    Frame.install
    Frame.commandLine Install
    Frame.uninstall
    Frame.commandLine Uninstall
    Frame.virtualText
    Frame.diskBuilder
    #Frame.testInstaller

    foreach node [$main nodes root] { $main open $node 1 }

    ## Create the standard right-click edit menu.
    set m [POPUP $base.editMenu -tearoff 0]
    set widg(RightClickEditMenu) $m
    $m add command -label Cut -underline 2 \
    	-command {::edit::cut $::edit::widget} \
    	-image [GetImage editcut16] -compound left
    $m add command -label Copy -underline 0 \
    	-command {::edit::copy $::edit::widget} \
    	-image [GetImage editcopy16] -compound left
    $m add command -label Paste -underline 0 \
    	-command {::edit::paste $::edit::widget} \
    	-image [GetImage editpaste16] -compound left
    $m add command -label Delete -underline 0 \
    	-command {::edit::delete $::edit::widget} \
    	-image [GetImage editdelete16] -compound left
    $m add command -label "Select All" -underline 7 \
    	-command {::edit::selectall $::edit::widget} \
    	-image [GetImage blank] -compound left
    tag addtag editMenu menuentries $m recursive

    ## Create the properties right-click menu.
    set m [POPUP $base.propertiesRightClick -tearoff 0]
    set widg(PropertiesRightClick) $m
    $m add command -label "Copy Value" \
        -command ::InstallJammer::CopyPropertiesValue \
    	-image [GetImage editcopy16] -compound left
    $m add command -label "Paste Value" \
        -command ::InstallJammer::PastePropertiesValue \
        -image [GetImage editpaste16] -compound left

    ::InstallJammer::SetHelp <default>
}

proc Frame.applicationInformation {} {
    global conf
    global widg

    set f1 [$widg(Product) getframe applicationInformation]
    set p  $f1.p

    set widg(ApplicationInformationPref) $p

    ::InstallJammer::SetHelp ApplicationInformation

    if {[winfo exists $p]} { return }

    ScrolledWindow $f1.sw -scrollbar vertical -auto vertical
    PROPERTIES $p -browseargs [list -style Toolbutton]
    $f1.sw setwidget $p
    pack $f1.sw -expand 1 -fill both

    $p insert end root standard -text "Application Information" \
        -helptext "This section describes general information about\
                your application and your project."

        $p insert end standard #auto -text "Application ID" \
            -variable info(ApplicationID) -helptext "The unique ID for this\
                application"
	$p insert end standard #auto -text "Application Name" \
	    -variable info(AppName) -helptext "The name of your application"

	$p insert end standard #auto -text "Application URL" \
	    -variable info(ApplicationURL) -helptext \
                "The main URL where people can find your application."

	$p insert end standard #auto -text "Company" \
	    -variable info(Company) -helptext "Your company name"

	$p insert end standard #auto -text "Copyright" \
	    -variable info(Copyright) -helptext "Copyright of your application"

	$p insert end standard #auto -text "Install Icon" \
	    -variable info(Icon) \
	    -browsebutton 1 -browsecommand [list GetImageFile ::info(Icon)] \
            -helptext "A standard icon to use for your install"

	$p insert end standard #auto -text "Install Image" \
	    -variable info(Image) \
	    -browsebutton 1 -browsecommand [list GetImageFile ::info(Image)] \
            -helptext "A standard image to use for your install"

	VersionFrame $f1.installVersion info -command [list $p edit finish]
	$p insert end standard #auto -text "Install Version" \
	    -variable info(InstallVersion) -editwindow $f1.installVersion \
            -editfinishcommand ::InstallJammer::FinishEditVersion -helptext \
                "The build version for your install"

	$p insert end standard #auto -text "Short Application Name" \
	    -variable info(ShortAppName) -helptext \
                "The short name of your application."

        $p insert end standard #auto -text "Upgrade Application ID" \
            -variable info(UpgradeApplicationID) -helptext "If this project\
                is an upgrade to another application, this is the unique ID\
                for that application"

	$p insert end standard #auto -text "Version String" \
	    -variable info(Version) -helptext "The version of your application"


    $p insert end root features -text "Install Features" \
        -helptext "This section defines different features that can be\
                enabled or disabled for your install project."

        $p insert end features #auto -text "Allow Language Selection" \
            -variable info(AllowLanguageSelection) -editable 0 \
            -values [list Yes No] -helptext "Allow the user to select\
                which language to use for installation"

	set actions [list "Cancel and Stop" "Continue to Next Pane"]
	lappend actions "Rollback and Stop" "Rollback and Continue to Next Pane"
	$p insert end features #auto -text "Cancelled Install Action" \
	    -variable info(CancelledInstallAction) -editable 0 \
            -values $actions -helptext "The action your install will take when\
                the user cancels in the middle of installing files"

        $p insert end features #auto -text "Default Language" \
            -variable info(DefaultLanguage) -editable 0 \
            -valuescommand ::InstallJammer::GetLanguages \
            -helptext "The default language to use during installation.  This\
                could change depending on system settings if the user is\
                allowed to select a language"

        $p insert end features #auto -text "Default to System Language" \
            -variable info(DefaultToSystemLanguage) -editable 0 \
            -values "Yes No" -helptext "Use whatever language is the\
                default on the installing system if the language has been\
                included in the installer.  If the system language is not\
                part of the installer, the Default Language will be used"

        $p insert end features #auto -text "Enable Response Files" \
            -variable info(EnableResponseFiles) -editable 0 \
            -values "Yes No" -helptext "Enable the response-file and\
                save-response-file command-line options that allow a user\
                to save responses in an installer and replay them later"

        $p insert end features #auto -text "Extract Solid Archives on Startup" \
            -variable info(ExtractSolidArchivesOnStartup) -editable 0 \
            -values [list Yes No] -helptext "Whether or not InstallJammer\
                should extract solid archives during startup or wait until\
                just before file installation"

        $p insert end features #auto -text "Install Password" \
            -variable info(InstallPassword) \
            -helptext "A password to encrypt the installer with.  The user\
                must then be prompted for a password to install"

        $p insert end features #auto -text "Wizard Height" \
            -variable info(WizardHeight) \
            -helptext "The height of the installation wizard window"

        $p insert end features #auto -text "Wizard Width" \
            -variable info(WizardWidth) \
            -helptext "The width of the installation wizard window"

    $p insert end root languages -text "Install Languages" \
        -helptext "This section defines which languages are supported by\
                        your installer."

    variable ::InstallJammer::languages
    foreach lang [::InstallJammer::GetLanguages] {
        set code $languages($lang)
        $p insert end languages #auto -text "$lang" \
            -variable info(Language,$code) -editable 0 \
            -values {Yes No} -helptext "Allow user to choose $lang as the\
                install language if Allow Language Selection is true"
    }

    $p insert end root preferences -text "Project Preferences" \
        -helptext "This section defines preferences about how InstallJammer\
                will save and build your project."

	set actions [list "Fail (recommended)" \
                "Continue without including missing files"]

	$p insert end preferences #auto -text "Build Failure Action" \
	    -variable info(BuildFailureAction) \
	    -editable 0 -values $actions -helptext "The action InstallJammer\
                will take when a file is missing while building installs from\
                within the builder"

	$p insert end preferences #auto -text "Command Line Failure Action" \
	    -variable info(CommandLineFailureAction) \
	    -editable 0 -values $actions -helptext "The action InstallJammer\
                will take when a file is missing while building installs from\
                the command line"

        for {set i 1} {$i <= 9} {incr i} { lappend levels $i }
	$p insert end preferences #auto -text "Compression Level" \
	    -variable info(CompressionLevel) -editable 0 \
            -values $levels -helptext "The level of compression to use when\
                storing files in your install with zlib compression\
                (1 = faster, 9 = smaller)"

	$p insert end preferences #auto -text "Compression Method" \
	    -variable info(CompressionMethod) -editable 0 \
            -values $conf(CompressionMethods) -helptext "The method of\
                compression to use when storing files in your install"

	$p insert end preferences #auto -text "Default Directory Location" \
	    -variable info(DefaultDirectoryLocation) -editable 1 \
            -helptext "The default location to look for files within the\
                file groups of the project."

	$p insert end preferences #auto -text "Ignore Directories" \
            -variable info(IgnoreDirectories) \
            -helptext "A list of regular expressions to match when searching\
                for new directories.  Each expression should be separated by\
                a space with patterns containing spaces wrapped in quotes"

	$p insert end preferences #auto -text "Ignore Files" \
            -variable info(IgnoreFiles) \
            -helptext "A list of regular expressions to match when searching\
                for new files.  Each expression should be separated by a space\
                with patterns containing spaces wrapped in quotes"

	$p insert end preferences #auto \
            -text "Include Install Debugging Options" \
	    -variable info(IncludeDebugging) -editable 0 \
            -values [list Yes No] -helptext "Turn install debugging options\
                on or off"

	$p insert end preferences #auto \
            -text "Preserve UNIX File Permissions" \
	    -variable info(PreserveFilePermissions) -editable 0 \
            -values [list Yes No] -helptext "Whether or not InstallJammer\
                should preserve the current UNIX file permissions when adding\
                files to an installer"

	$p insert end preferences #auto \
            -text "Preserve Windows File Attributes" \
	    -variable info(PreserveFileAttributes) -editable 0 \
            -values [list Yes No] -helptext "Whether or not InstallJammer\
                should preserve the current Windows file attributes when\
                adding files to an installer"

	$p insert end preferences #auto \
            -text "Refresh File List Before Building" \
	    -variable info(AutoRefreshFiles) -editable 0 \
            -values [list Yes No] -helptext "Whether or not InstallJammer\
                should look for new and deleted files in directories added\
                to file groups automatically before building"

	$p insert end preferences #auto -text "Save Only Toplevel Directories" \
	    -variable info(SaveOnlyToplevelDirs) -editable 0 \
            -values [list Yes No] -helptext "Do not recursively save all of the\
                files and subdirectories beneath a directory in a file\
                group.  Only save the directories and files that are direct\
                children of the file group."

	$p insert end preferences #auto -text "Skip Unused File Groups" \
	    -variable info(SkipUnusedFileGroups) -editable 0 \
            -values [list Yes No] -helptext "Do not pack file groups that are\
                not included in at least one component."

    return

    ## Build the restore buttons.
    set f [frame $f1.themes]
    pack $f -side bottom -anchor se -pady [list 10 0]

    BUTTON $f.restorewin -text "Restore Windows" -width 18 \
        -command RestoreThemeWindows
    pack $f.restorewin -side left

    BUTTON $f.restore -text "Restore Theme" -width 18 \
        -command [list RestoreTheme -prompt]
    pack $f.restore -side left -padx 5

    BUTTON $f.save -text "Save New Theme" -width 18 \
        -command SaveTheme
    pack $f.save -side left
}

proc Frame.platformInformation {} {
    global conf
    global info
    global widg

    set f [$widg(Product) getframe platformInformation]
    set p $f.sw.p

    ::InstallJammer::SetHelp PlatformInformation

    if {[winfo exists $p]} {
        foreach platform [AllPlatforms] {
            foreach node [$p nodes [PlatformName $platform]] {
                set var [$p itemcget $node -data]
                $p itemconfigure $node -value [$platform get $var]
            }
        }

        return
    }

    ScrolledWindow $f.sw -scrollbar vertical -auto vertical
    PROPERTIES $p
    $f.sw setwidget $p
    pack $f.sw -expand 1 -fill both

    set platforms [ActivePlatforms]
    foreach platform [AllPlatforms] {
	set open 0
	if {[lsearch -exact $platforms $platform] > -1} { set open 1 }

        set cmd [list ::InstallJammer::FinishEditPlatformPropertyNode %W %p %n]

	set node [PlatformName $platform]
	$p insert end root $node -text [PlatformText $platform] \
            -open $open -data $platform

        $p insert end $node #auto -text "Active" \
            -values [list Yes No] -editable 0 -data Active \
            -editfinishcommand $cmd -value [$platform get Active] \
            -helptext "Whether this platform is active for your project"

        $p insert end $node #auto -text "Build Separate Archives" \
            -values [list Yes No] -editable 0 -editfinishcommand $cmd \
            -data BuildSeparateArchives \
            -value [$platform get BuildSeparateArchives] \
            -helptext "Whether this platform should be built as a single\
                executable installer or that the files should be packaged\
                separately in archives to be distributed with the installer"

	$p insert end $node #auto \
	    -text "Default Destination Directory" \
            -valuescommand [list InstallDirList $platform] \
            -data InstallDir -editfinishcommand $cmd \
            -value [$platform get InstallDir] -helptext "The default\
                installation location for this application"

        if {$platform ne "Windows"} {
            $p insert end $node #auto \
                -text "Default Directory Permission Mask" \
                -data DefaultDirectoryPermission -editfinishcommand $cmd \
                -value [$platform get DefaultDirectoryPermission] \
                -helptext "The default permission mask for\
                    directories on a UNIX platform (in octal format)"

            $p insert end $node #auto \
                -text "Default File Permission Mask" \
                -data DefaultFilePermission -editfinishcommand $cmd \
                -value [$platform get DefaultFilePermission] \
                -helptext "The default permission mask for\
                    files on a UNIX platform (in octal format)"
        }

	$p insert end $node #auto -text "Default Install Mode" \
            -values [list Default Silent Standard] \
            -editable 0 -data InstallMode -editfinishcommand $cmd \
            -value [$platform get InstallMode] -helptext "The default install\
                mode when installing this application"

	$p insert end $node #auto -text "Default Program Folder" \
            -data ProgramFolderName -editfinishcommand $cmd \
            -value [$platform get ProgramFolderName] -helptext "The default\
                program folder on Windows to store shortcuts for this\
                application"

	$p insert end $node #auto -text "Default Setup Type" \
            -valuescommand [list ::InstallJammer::GetSetupTypeNames $platform] \
            -editable 0 -data InstallType -editfinishcommand $cmd \
            -value [$platform get InstallType] -helptext "The default setup\
                type when installing this application"

        if {$platform ne "Windows"} {
            $p insert end $node #auto -text "Fall Back to Console Mode" \
                -values [list Yes No] -editable 0 \
                -data FallBackToConsole -editfinishcommand $cmd \
                -value [$platform get FallBackToConsole] \
                -helptext "If a GUI mode is unavailable the installer will\
                    automatically fall back to a console mode to install"
        }

        if {$platform eq "Windows"} {
            $p insert end $node #auto -text "Include Windows API Extension" \
                -values [list Yes No] -editable 0 \
                -data IncludeTWAPI -editfinishcommand $cmd \
                -value [$platform get IncludeTWAPI] \
                -helptext "Whether or not to include the Tcl Windows API\
                    extension in your install (Windows NT 4.0 SP4 or later)"

            $p insert end $node #auto -text "Install Executable Description" \
                -data FileDescription -editfinishcommand $cmd \
                -value [$platform get FileDescription] \
                -helptext "The file description when someone examines the\
                    properties of the executable on the Windows platform"
        }

	$p insert end $node #auto -text "Install Executable Name" \
            -data Executable -editfinishcommand $cmd \
            -value [$platform get Executable] -helptext "The name of your\
                installer when it is built"

        if {$platform eq "Windows"} {
            $p insert end $node #auto \
                -text "Install Program Folder for All Users" \
                -values [list Yes No] -editable 0 \
                -data ProgramFolderAllUsers -editfinishcommand $cmd \
                -value [$platform get ProgramFolderAllUsers] -helptext \
                    "Whether or not to create the Program Folder for all or \
                     the current user by default"
        }

	$p insert end $node #auto \
	    -text "Program Executable" \
            -valuescommand [list InstallDirList $platform] \
            -data ProgramExecutable -editfinishcommand $cmd \
            -value [$platform get ProgramExecutable] -helptext "The path to\
                the main executable for your application on the target system"

	$p insert end $node #auto \
	    -text "Program License" \
            -valuescommand [list InstallDirList $platform] \
            -data ProgramLicense -editfinishcommand $cmd \
            -value [$platform get ProgramLicense] -helptext "The path to your\
                LICENSE file on the target system"

	$p insert end $node #auto \
	    -text "Program Readme" \
            -valuescommand [list InstallDirList $platform] \
            -data ProgramReadme -editfinishcommand $cmd \
            -value [$platform get ProgramReadme] -helptext "The path to your\
                README file on the target system"

        if {$platform eq "Windows"} {
            $p insert end $node #auto -text "Require Administrator" \
                -values "Yes No" -editable 0 -data RequireAdministrator \
                -editfinishcommand $cmd \
                -value [$platform get RequireAdministrator] \
                -helptext "Whether this install requires administrator\
                    privileges to install"
        } else {
            $p insert end $node #auto -text "Prompt for Root Password" \
                -values [list Yes No] -editable 0 -data PromptForRoot \
                -editfinishcommand $cmd -value [$platform get PromptForRoot] \
                -helptext "If root access is required, InstallJammer will\
                    prompt the user to login as root on startup if they are\
                    not already root"

            $p insert end $node #auto -text "Require Root User" \
                -values [list Yes No] -editable 0 -data RequireRoot \
                -editfinishcommand $cmd -value [$platform get RequireRoot] \
                -helptext "Whether this install requires the root user to\
                    install"

            $p insert end $node #auto \
                -text "Root Destination Directory" \
                -valuescommand [list InstallDirList $platform] \
                -data RootInstallDir -editfinishcommand $cmd \
                -value [$platform get RootInstallDir] -helptext "The\
                    default installation location for this application\
                    when being installed as root.  If this value is empty,\
                    the Default Destination Directory will be used"
        }

        if {$platform eq "Windows"} {
            $p insert end $node #auto -text "Use Uncompressed Binaries" \
                -values [list Yes No] -editable 0 \
                -data UseUncompressedBinaries -editfinishcommand $cmd \
                -value [$platform get UseUncompressedBinaries] \
                -helptext "If this property is true, the installer will be\
                    built with uncompressed binaries that make the install\
                    larger but sometimes avoid being erroneously detected by\
                    some virus scanning software"

            $p insert end $node #auto -text "Windows File Icon" \
                -browsebutton 1 -browsecommand [list GetIconFile %v] \
                -browseargs {-style Toolbutton} \
                -valuescommand GetIconList \
                -data WindowsIcon -editfinishcommand $cmd \
                -value [$platform get WindowsIcon] -helptext "The Windows\
                    icon to use for building the Windows installer"
        }
    }
}

proc Frame.packageAndArchiveInformation {} {
    global conf
    global info
    global widg

    set f [$widg(Product) getframe packageAndArchiveInformation]
    set p $f.sw.p

    ::InstallJammer::SetHelp PackageAndArchiveInformation

    if {[winfo exists $p]} {
        foreach archive $conf(Archives) {
            foreach node [$p nodes $archive] {
                set var [$p itemcget $node -data]
                $p itemconfigure $node -value [$archive get $var]
            }
        }

        return
    }

    ScrolledWindow $f.sw -scrollbar vertical -auto vertical
    PROPERTIES $p
    $f.sw setwidget $p
    pack $f.sw -expand 1 -fill both

    set cmd [list ::InstallJammer::FinishEditPlatformPropertyNode %W %p %n]

    $p insert end root package -text "Package Information" \
        -helptext "This section defines the information used by the\
                Register Package action if you want to register your\
                application with the local package database.\nIt is\
                highly recommended that you fill in all of the available\
                properties if you plan on registering your package."

        $p insert end package #auto -text "Package Description" \
            -variable info(PackageDescription) -browsebutton 1 \
            -browseargs [list -style Toolbutton] \
            -browsecommand [list ::editor::new \
                -title "Edit Package Description" \
                -variable ::info(PackageDescription)]

        $p insert end package #auto -text "Package License" \
            -variable info(PackageLicense)

        $p insert end package #auto -text "Package Maintainer" \
            -variable info(PackageMaintainer)

        $p insert end package #auto -text "Package Name" \
            -variable info(PackageName)

        $p insert end package #auto -text "Package Packager" \
            -variable info(PackagePackager)

        $p insert end package #auto -text "Package Release" \
            -variable info(PackageRelease)

        $p insert end package #auto -text "Package Summary" \
            -variable info(PackageSummary)

        $p insert end package #auto -text "Package Version" \
            -variable info(PackageVersion)

    set archive TarArchive
    if {[::InstallJammer::ArchiveExists $archive]} {
        $p insert end root $archive -text "Tar Archive Information" \
            -data $archive -editfinishcommand $cmd -open [$archive get Active] \
            -helptext "This section defines the attributes for creating a\
                TAR archive file of your install project."

            $p insert end $archive #auto -text "Active" \
                -values [list Yes No] -editable 0 \
                -data Active -value [$archive get Active] \
                -helptext "Whether this archive is active for your project"

            set levels [list]
            for {set i 0} {$i <= 9} {incr i} { lappend levels $i }
            $p insert end $archive #auto -text "Compression Level" \
                -data CompressionLevel -editable 0 -values $levels \
                -value [$archive get CompressionLevel] \
                -helptext "The level of gzip compression for the tar file.\
                    (0 = no compression, 9 highest compression)"

            $p insert end $archive #auto \
                -text "Default Directory Permission Mask" \
                -data DefaultDirectoryPermission \
                -value [$archive get DefaultDirectoryPermission] \
                -helptext "The default permission mask for directories on\
                    a UNIX platform (in octal format)"

            $p insert end $archive #auto -text "Default File Permission Mask" \
                -data DefaultFilePermission \
                -value [$archive get DefaultFilePermission] \
                -helptext "The default permission mask for files on a\
                    UNIX platform (in octal format)"

            $p insert end $archive #auto -text "Output File Name" \
                -data OutputFileName -value [$archive get OutputFileName] \
                -helptext "The name of the tar file to output to"

            $p insert end $archive #auto -text "Virtual Text Map" \
                -data VirtualTextMap -value [$archive get VirtualTextMap] \
                -helptext "A map of virtual text for filenames being stored in\
                    the tar file"
    }

    set archive ZipArchive
    if {[::InstallJammer::ArchiveExists $archive]} {
        $p insert end root ZipArchive -text "Zip Archive Information" \
            -data ZipArchive -editfinishcommand $cmd -open [$archive get Active]

            $p insert end $archive #auto -text "Active" \
                -values [list Yes No] -editable 0 \
                -data Active -value [$archive get Active] \
                -helptext "Whether this archive is active for your project"

            set levels [list]
            for {set i 1} {$i <= 9} {incr i} { lappend levels $i }
            $p insert end $archive #auto -text "Compression Level" \
                -data CompressionLevel -editable 0 -values $levels \
                -value [$archive get CompressionLevel] \
                -helptext "The level of compression for the zip file.\
                    (1 = lowest compression, 9 highest compression)"

            $p insert end $archive #auto -text "Output File Name" \
                -data OutputFileName -value [$archive get OutputFileName] \
                -helptext "The name of the zip file to output to"

            $p insert end $archive #auto -text "Virtual Text Map" \
                -data VirtualTextMap -value [$archive get VirtualTextMap] \
                -helptext "A map of virtual text for filenames being stored in\
                    the zip file"
    }
}

proc Frame.groupsAndFiles {} {
    global conf
    global widg
    global preferences

    set f1 [$widg(Product) getframe groupsAndFiles]
    set widg(FileGroupsMain) $f1

    ::InstallJammer::SetHelp GroupsAndFiles

    if {[winfo exists $f1.buttons]} {
        set conf(TreeFocus) $widg(FileGroupTree)

        variable ::InstallJammer::ActiveComponents
        if {[info exists ActiveComponents(filegroup)]} {
            ::InstallJammer::SetActiveComponent $ActiveComponents(filegroup)
        }

        return
    }

    set f [frame $f1.buttons]
    pack $f -anchor w

    WinButton $f.b1 -image [GetImage foldernew16] \
    	-command "::FileGroupTree::New"
    set widg(DeleteButton) [WinButton $f.b4 \
	-image [GetImage buttoncancel16] -command "::FileGroupTree::delete"]
    set widg(AddFilesButton) [WinButton $f.b2 \
    	-image [GetImage filedocument16] -command "AddFiles" -state disabled]
    set widg(AddDirButton) [WinButton $f.b3 \
    	-image [GetImage folder16] -command "AddFiles -isdir 1" -state disabled]
    WinButton $f.b5 -image [GetImage filefind16] \
        -command ::FileGroupTree::Explore
    WinButton $f.refresh -image [GetImage actreload16] \
    	-command "::InstallJammer::RefreshFileGroups"
    WinButton $f.filter -image [GetImage viewsidetree16] \
    	-command "Window show .filterFileGroups"

    pack $f.b1 $f.b4 $f.b2 $f.b3 $f.b5 $f.refresh $f.filter -side left

    DynamicHelp::register $f.b1 balloon "Add New File Group"
    DynamicHelp::register $widg(AddFilesButton) balloon \
        "Add Files to File Group"
    DynamicHelp::register $widg(AddDirButton) balloon \
        "Add Directory to File Group"
    DynamicHelp::register $f.b4 balloon "Delete"
    DynamicHelp::register $f.b5 balloon "File Explorer"
    DynamicHelp::add $f.refresh -text "Refresh File Groups"
    DynamicHelp::register $f.filter balloon \
    	"Filter file groups based on patterns"

    set widg(FileGroupPref) $f1.p

    set opts [list]
    if {[info exists preferences(Geometry,FileGroupPref)]} {
        set opts $preferences(Geometry,FileGroupPref)
    }

    eval [list PREFERENCES $widg(FileGroupPref) -treepadx 20 -showlines 1 \
        -deltay 17 -pagewidth 300 -treestretch always -pagestretch never] $opts
    pack $f1.p -expand 1 -fill both

    set widg(FileGroupTree) [$f1.p gettree]

    set tree $widg(FileGroupTree)
    ::FileGroupTree::setup $widg(FileGroupTree)

    set prop [PROPERTIES $f1.properties]
    set widg(FileGroupProperties) $prop
    $prop insert end root filegroup   -text "File Group Properties"
    $prop insert end root dir         -text "Directory Properties"
    $prop insert end root file        -text "File Properties"
    $prop insert end root fileunix    -text "File Permissions"
    $prop insert end root filewindows -text "File Permissions"

    dnd bindtarget $tree.c Files <Drop> "::Tree::DropFiles $tree %D"
    dnd bindtarget $tree.c Files <Drag> "::Tree::DragFiles $tree %x %y"

    ## Create the popup menus.
    set ::FileGroupTree::FilePopup      $f1.filePopup
    set ::FileGroupTree::MultiPopup     $f1.multiPopup
    set ::FileGroupTree::FileGroupPopup $f1.fileGroupPopup
    set ::FileGroupTree::DirectoryPopup $f1.directoryPopup

    set m [POPUP $::FileGroupTree::FilePopup]

    #$m add command -label "Select All" \
    	#-command {::FileTree::SelectAll $widg(FileGroupTree)}
    #$m add separator
    $m add command -label "Check" -underline 0 \
        -compound left -image [GetImage checkfiledocument16] \
    	-command {::FileGroupTree::Check}
    $m add command -label "Uncheck" -underline 0 \
        -compound left -image [GetImage filedocument16] \
    	-command {::FileGroupTree::Uncheck}
    $m add separator
    $m add command -label "Delete" -underline 0 \
    	-compound left -image [GetImage buttoncancel16] \
    	-command {::FileGroupTree::delete}
    $m add separator
    $m add command -label "Add to Desktop" -underline 0 \
    	-command {::FileGroupTree::AddToDesktop}
    $m add command -label "Add to Program Folder" -underline 0 \
    	-command {::FileGroupTree::AddToProgramFolder}
    #$m add command -label "Add Windows Shortcut" -underline 0 \
    	#-command {::FileGroupTree::AddWindowsShortcut}
    #$m add command -label "Add as Wrapped Script" -underline 0 \
    	#-command {::FileGroupTree::AddWrappedScript}
    #$m add command -label "Add as Wrapped Application" -underline 0 \
    	#-command {::FileGroupTree::AddWrappedApplication}
    $m add separator
    $m add command -label "Explore" -underline 1 \
        -compound left -image [GetImage filefind16] \
        -command ::FileGroupTree::Explore

    set m [POPUP $::FileGroupTree::MultiPopup]

    #$m add command -label "Select All" \
    	#-command {::FileTree::SelectAll $widg(FileGroupTree)}
    #$m add separator
    $m add command -label "Check" -underline 0 \
        -compound left -image [GetImage checkfiledocument16] \
    	-command {::FileGroupTree::Check}
    $m add command -label "Uncheck" -underline 0 \
        -compound left -image [GetImage filedocument16] \
    	-command {::FileGroupTree::Uncheck}
    $m add separator
    $m add command -label "Delete" -underline 0 \
    	-compound left -image [GetImage buttoncancel16] \
    	-command {::FileGroupTree::delete}

    set m [POPUP $::FileGroupTree::FileGroupPopup]

    $m add command -label "Open" \
        -compound left -image [GetImage folderopen16] \
        -command {
            ::InstallJammer::Tree::OpenSelectedNode $widg(FileGroupTree)
        }
    $m add command -label "Open Recursive" \
        -compound left -image [GetImage folderopen16] \
        -command {
            ::InstallJammer::Tree::OpenSelectedNode $widg(FileGroupTree) 1
        }

    $m add command -label "Close" \
        -compound left -image [GetImage folder16] \
        -command {
            ::InstallJammer::Tree::CloseSelectedNode $widg(FileGroupTree)
        }

    $m add separator

    #$m add command -label "Select All" \
    	#-command {::FileTree::SelectAll $widg(FileGroupTree)}
    #$m add command -label "Select All in this File Group" \
    	#-command {::FileTree::SelectAllBeneath $widg(FileGroupTree)}
    #$m add separator
    $m add command -label "Add Files" -underline 0 \
        -compound left -image [GetImage filedocument16] \
        -command "AddFiles"
    $m add command -label "Add Directory" -underline 0 \
        -compound left -image [GetImage folder16] \
        -command "AddFiles -isdir 1"
    $m add separator
    $m add command -label "Delete" -underline 0 \
    	-compound left -image [GetImage buttoncancel16] \
    	-command {::FileGroupTree::delete}

    set m [POPUP $::FileGroupTree::DirectoryPopup]

    $m add command -label "Open" \
        -compound left -image [GetImage folderopen16] \
        -command {
            ::InstallJammer::Tree::OpenSelectedNode $widg(FileGroupTree)
        }
    $m add command -label "Open Recursive" \
        -compound left -image [GetImage folderopen16] \
        -command {
            ::InstallJammer::Tree::OpenSelectedNode $widg(FileGroupTree) 1
        }

    $m add command -label "Close" \
        -compound left -image [GetImage folder16] \
        -command {
            ::InstallJammer::Tree::CloseSelectedNode $widg(FileGroupTree)
        }

    $m add separator
    #$m add command -label "Select All" \
    	#-command {::FileTree::SelectAll $widg(FileGroupTree)}
    #$m add separator
    $m add command -label "Check" -underline 0 \
        -compound left -image [GetImage checkfolder16] \
    	-command {::FileGroupTree::Check}
    $m add command -label "Uncheck" -underline 0 \
        -compound left -image [GetImage folder16] \
    	-command {::FileGroupTree::Uncheck}
    $m add separator
    $m add command -label "Delete" -underline 0 \
    	-compound left -image [GetImage buttoncancel16] \
    	-command {::FileGroupTree::delete}
    $m add separator
    $m add command -label "Explore" -underline 1 \
        -compound left -image [GetImage filefind16] \
        -command ::FileGroupTree::Explore

    ## Create the frame to hold file group details.
    set widg(FileGroupDetails) [ScrolledWindow $f1.details -scrollbar vertical]

    set prop [PROPERTIES $f1.details.prop -width 250]
    set widg(FileGroupDetailsProp) $prop

    $widg(FileGroupDetails) setwidget $widg(FileGroupDetailsProp)

    $prop insert end root standard -text "Standard Properties" -open 1

    ::FileGroupObject addproperties $prop foo

    ## Add a node for file / directory properties.
    $prop insert end root filestandard -text "Standard Properties" -open 1
    ::FileObject addproperties $prop file -standardnode filestandard \
        -array ::FileGroupTree::details

    $prop insert end root dir  -text "Directory Details"
        $prop insert end dir #auto -text "Name" \
            -variable ::FileGroupTree::details(name) -state disabled
        $prop insert end dir #auto -text "Location" \
            -variable ::FileGroupTree::details(location) -state disabled
        $prop insert end dir #auto -text "File Group" \
            -variable ::FileGroupTree::details(fileGroup) -state disabled
        $prop insert end dir #auto -text "File Update Method" \
            -variable ::FileGroupTree::details(fileMethod) -state disabled
        $prop insert end dir #auto -text "Install Location" \
            -variable ::FileGroupTree::details(installLocation) -state disabled
        $prop insert end dir #auto -text "Compression Method" \
            -variable ::FileGroupTree::details(compressionMethod) \
            -state disabled
        $prop insert end dir #auto -text "Version" \
            -variable ::FileGroupTree::details(fileVersion) -state disabled
        $prop insert end dir #auto -text "Created" \
            -variable ::FileGroupTree::details(created) -state disabled
        $prop insert end dir #auto -text "Modified" \
            -variable ::FileGroupTree::details(modified) -state disabled
        $prop insert end dir #auto -text "Accessed" \
            -variable ::FileGroupTree::details(accessed) -state disabled

    $prop insert end root file -text "File Details"
        $prop insert end file #auto -text "Name" \
            -variable ::FileGroupTree::details(name) -state disabled
        $prop insert end file #auto -text "Location" \
            -variable ::FileGroupTree::details(location) -state disabled
        $prop insert end file #auto -text "File Group" \
            -variable ::FileGroupTree::details(fileGroup) -state disabled
        $prop insert end file #auto -text "File Size" \
            -variable ::FileGroupTree::details(fileSize) -state disabled
        $prop insert end file #auto -text "File Update Method" \
            -variable ::FileGroupTree::details(fileMethod) -state disabled
        $prop insert end file #auto -text "Install Location" \
            -variable ::FileGroupTree::details(installLocation) -state disabled
        $prop insert end file #auto -text "Compression Method" \
            -variable ::FileGroupTree::details(compressionMethod) \
            -state disabled
        $prop insert end file #auto -text "Version" \
            -variable ::FileGroupTree::details(fileVersion) -state disabled
        $prop insert end file #auto -text "Created" \
            -variable ::FileGroupTree::details(created) -state disabled
        $prop insert end file #auto -text "Modified" \
            -variable ::FileGroupTree::details(modified) -state disabled
        $prop insert end file #auto -text "Accessed" \
            -variable ::FileGroupTree::details(accessed) -state disabled

    ## Create a property node for multiple file options
    $prop insert end root multiplefiles -text "Standard Properties" -open 1

    AddProperty $prop end multiplefiles multiplefiles Active \
        ::FileGroupTree::details(Active) -type boolean -pretty "Active"
    AddProperty $prop end multiplefiles multiplefiles Destination \
        ::FileGroupTree::details(Destination) -type installedfile \
        -pretty "Destination Directory"
    AddProperty $prop end multiplefiles multiplefiles FileUpdateMethod \
        ::FileGroupTree::details(FileUpdateMethod) -type filemethod \
        -pretty "File Update Method"
    AddProperty $prop end multiplefiles multiplefiles CompressionMethod \
        ::FileGroupTree::details(CompressionMethod) -type choice \
        -pretty "Compression Method" -choices $conf(CompressionMethods)
    AddProperty $prop end multiplefiles multiplefiles Version \
        ::FileGroupTree::details(Version) -type version \
        -pretty "Version"

    ## Create the permissions property node.
    set permf [frame $f1.permissions]
    set widg(FileGroupPermissions) $permf

    labelframe $permf.unix -text "UNIX File Permissions"
    UNIXPermissionsFrame $permf.unix UNIXDetailsPermissions \
        ::FileGroupTree::permissions
    pack $permf.unix -side left -anchor nw -padx 5

    labelframe $permf.windows -text "Windows File Attributes"
    WindowsPermissionsFrame $permf.windows WindowsDetailsPermissions \
        ::FileGroupTree::permissions
    pack $permf.windows -side left -anchor nw -fill y

    ::InstallJammer::AddPlatformPropertyNode $prop ::FileGroupTree::details 1

    $prop insert end root permissions -text "Permissions" -window $permf
}

proc Frame.components {} {
    global conf
    global widg
    global preferences

    set f2 [$widg(Product) getframe components]

    ::InstallJammer::SetHelp Components

    if {[winfo exists $f2.top]} {
        set conf(TreeFocus) $widg(ComponentTree)

        variable ::InstallJammer::ActiveComponents
        if {[info exists ActiveComponents(component)]} {
            ::InstallJammer::SetActiveComponent $ActiveComponents(component)
        }

        return
    }
    
    frame $f2.top
    pack $f2.top -side top -anchor w

    WinButton $f2.top.b1 -image [GetImage foldernew16] \
    	-command ::ComponentTree::New
    pack $f2.top.b1 -side left

    set widg(ComponentDeleteButton) [WinButton $f2.top.b3 \
    	-image [GetImage buttoncancel16] -command "::ComponentTree::delete"]
    pack $f2.top.b3 -side left

    DynamicHelp::register $f2.top.b1 balloon "Add New Component"
    DynamicHelp::register $f2.top.b3 balloon "Delete Component"

    set opts [list]
    if {[info exists preferences(Geometry,ComponentPref)]} {
        set opts $preferences(Geometry,ComponentPref)
    }

    eval [list PREFERENCES $f2.p -treepadx 20 -deltay 19 -showlines 1 \
        -pagewidth 300 -treestretch never -pagestretch always \
        -dropovermode p -dragenabled 1 -dropenabled 1 \
        -dropcmd ::InstallJammer::Tree::DropNode \
        -draginitcmd ::InstallJammer::Tree::DragInit] $opts
    pack $f2.p -expand 1 -fill both

    set widg(ComponentPref) $f2.p
    set widg(ComponentTree) [$f2.p gettree]

    ::ComponentTree::setup $widg(ComponentTree)

    ## Create the Component popup menu.
    set m [POPUP $f2.popup -tearoff 0]
    set ::ComponentTree::popup $m
    $m add command -label "Delete" -underline 0 \
    	-compound left -image [GetImage buttoncancel16] \
    	-command {::ComponentTree::delete}

    ## Create the frame to hold component details.
    set widg(ComponentDetails) $f2.details

    set f [frame $widg(ComponentDetails)]

    ScrolledWindow $f.sw
    pack $f.sw -expand 1 -fill both -padx [list 0 10] -pady [list 0 5]

    set widg(ComponentFileGroupTree) $f.sw.tree
    OPTIONTREE $widg(ComponentFileGroupTree)
    $f.sw setwidget $widg(ComponentFileGroupTree)

    ScrolledWindow $f.details -scrollbar vertical
    pack $f.details -fill x

    set prop [PROPERTIES $f.details.prop -width 250]
    set widg(ComponentDetailsProp) $prop

    $f.details setwidget $widg(ComponentDetailsProp)

    $prop insert end root standard -text "Standard Properties" -open 1
    ::ComponentObject addproperties $prop foo

    $prop insert end root text -text "Text Properties" -open 0
    ::ComponentObject addtextfields $prop text foo

    ::InstallJammer::AddPlatformPropertyNode $prop ::ComponentTree::details
}

proc Frame.setupTypes {} {
    global conf
    global widg
    global preferences

    set f3 [$widg(Product) getframe setupTypes]

    ::InstallJammer::SetHelp SetupTypes

    if {[winfo exists $f3.top]} {
        set conf(TreeFocus) $widg(SetupTypeTree)

        variable ::InstallJammer::ActiveComponents
        if {[info exists ActiveComponents(setuptype)]} {
            ::InstallJammer::SetActiveComponent $ActiveComponents(setuptype)
        }

        return
    }

    frame $f3.top
    pack $f3.top -side top -anchor w

    WinButton $f3.top.b1 -image [GetImage foldernew16] \
    	-command ::SetupTypeTree::New
    pack $f3.top.b1 -side left

    set widg(SetupTypeDeleteButton) [WinButton $f3.top.b3 \
    	-image [GetImage buttoncancel16] -command "::SetupTypeTree::delete"]
    pack $f3.top.b3 -side left

    DynamicHelp::add $f3.top.b1 -text "Add New Setup Type"
    DynamicHelp::add $f3.top.b3 -text "Delete Setup Type"

    set opts [list]
    if {[info exists preferences(Geometry,SetupTypePref)]} {
        set opts $preferences(Geometry,SetupTypePref)
    }

    eval [list PREFERENCES $f3.p -treepadx 20 -showlines 0 -deltax 0 \
        -deltay 18 -pagewidth 300 -treestretch never -pagestretch always \
        -dropovermode p -dragenabled 1 -dropenabled 1 \
        -dropcmd ::InstallJammer::Tree::DropNode \
        -draginitcmd ::InstallJammer::Tree::DragInit] $opts
    pack $f3.p -expand 1 -fill both

    set widg(SetupTypePref) $f3.p
    set widg(SetupTypeTree) [$f3.p gettree]

    ::SetupTypeTree::setup $widg(SetupTypeTree)

    ## Create the Setup Type popup menu.
    set m [POPUP $f3.popup -tearoff 0]
    set ::SetupTypeTree::popup $m
    $m add command -label "Delete" -underline 0 \
    	-compound left -image [GetImage buttoncancel16] \
        -command {::SetupTypeTree::delete}

    set widg(SetupTypeDetails) $f3.details

    set f [frame $widg(SetupTypeDetails)]

    ScrolledWindow $f.sw
    pack $f.sw -expand 1 -fill both -padx [list 0 10] -pady [list 0 5]

    set widg(SetupTypeComponentTree) $f.sw.tree
    OPTIONTREE $widg(SetupTypeComponentTree)
    $f.sw setwidget $widg(SetupTypeComponentTree)

    ## Create the frame to hold setup type details.
    ScrolledWindow $f.details -scrollbar vertical
    pack $f.details -fill x

    set prop [PROPERTIES $f.details.prop -expand 1 -width 250]
    set widg(SetupTypeDetailsProp) $prop

    $f.details setwidget $widg(SetupTypeDetailsProp)

    $prop insert end root standard -text "Standard Properties" -open 1

    ::SetupTypeObject addproperties $prop foo

    $prop insert end root text -text "Text Properties" -open 0
    ::SetupTypeObject addtextfields $prop text foo

    ::InstallJammer::AddPlatformPropertyNode $prop ::SetupTypeTree::details
}

proc Frame.install {} {
    global conf
    global widg
    global preferences

    set widg(Install) [$widg(Product) getframe install].p

    ::InstallJammer::SetHelp PanesAndActions

    if {[winfo exists $widg(Install)]} {
        set conf(TreeFocus) $widg(InstallTree)

        variable ::InstallJammer::ActiveComponents
        if {[info exists ActiveComponents(Install)]} {
            ::InstallJammer::SetActiveComponent $ActiveComponents(Install)
        }

        return
    }

    set opts [list]
    if {[info exists preferences(Geometry,Install)]} {
        set opts $preferences(Geometry,Install)
    }

    set main $widg(Install)

    eval [list PREFERENCES $widg(Install) \
        -showlines 0 -treewidth 215 -treepadx 20 -deltay 18 \
        -dropovermode p -dragenabled 1 -dropenabled 1 \
        -dropcmd ::InstallJammer::Tree::DropNode \
        -draginitcmd ::InstallJammer::Tree::DragInit] $opts
    pack $main -expand 1 -fill both -side bottom

    set tree [$widg(Install) gettree]
    set widg(InstallTree) $tree

    set p [winfo parent $widg(Install)]
    set f [frame $p.f1]
    set widg(InstallButtons) $f
    pack $f -anchor nw

    WinMenuButton $f.addPane -image [GetImage displayscreen16] \
        -menu $f.addPane.panes
    pack $f.addPane -side left -padx 2
    DynamicHelp::add $f.addPane -text "Insert Install Pane"

    ## Create the menu for the install panes, but they won't
    ## get added until a project is loaded.
    set m [MENU $f.addPane.panes]
    set widg(InstallPanesMenu) $m

    WinMenuButton $f.addAction -image [GetImage insertaction16] \
        -menu $f.addAction.actions
    pack $f.addAction -side left -padx 2
    DynamicHelp::add $f.addAction -text "Insert Action"

    set m [MENU $f.addAction.actions]
    set widg(InstallActionsMenu) $m

    $m insert end cascade -label "All Actions" -menu $m.all \
        -compound left -image [GetImage appwindow_list16]
    MENU $m.all

    foreach group [lsort [array names ::InstallJammer::actiongroups]] {
        set submenu [MENU $m.[WidgetName $group]]
        $m insert end cascade -label "$group   " -menu $submenu \
            -compound left -image [GetImage appwindow_list16]

        foreach id $::InstallJammer::actiongroups($group) {
            set allactions([$id title]) $id
            lappend actions($submenu) [$id title]
        }
    }

    foreach submenu [array names actions] {
        foreach title [lsort $actions($submenu)] {
            set id $allactions($title)
            $submenu add command -label $title \
                -compound left -image [GetImage insertaction16] \
                -command [list ::InstallJammer::AddAction Install [$id action]]
        }
    }

    foreach title [lsort [array names allactions]] {
        set id $allactions($title)
        $m.all add command -label $title \
            -compound left -image [GetImage insertaction16] \
            -command [list ::InstallJammer::AddAction Install [$id action]]
    }

    WinButton $f.addActionGroup -image [GetImage appwindow_list16] \
        -command [list ::InstallJammer::AddActionGroup Install]
    pack $f.addActionGroup -side left -padx 2
    DynamicHelp::add $f.addActionGroup -text "New Action Group"

    WinButton $f.delete -image [GetImage buttoncancel16] \
        -command [list ::InstallJammer::Tree::Delete $widg(Install)]
    pack $f.delete -side left -padx 2
    DynamicHelp::add $f.delete -text "Delete"

    set args [list -deltax 5 -padx 10 -haspage 0]
    eval $main insert end root CommonInstall -data installtype \
        [list -text "Common Components" -font TkCaptionFont] $args
    eval $main insert end root StandardInstall -data installtype \
        [list -text "Standard Install" -font TkCaptionFont] $args
    eval $main insert end root DefaultInstall -data installtype \
        [list -text "Default Install" -font TkCaptionFont] $args
    eval $main insert end root ConsoleInstall -data installtype \
        [list -text "Console Install" -font TkCaptionFont] $args
    eval $main insert end root SilentInstall -data installtype \
        [list -text "Silent Install" -font TkCaptionFont] $args
    eval $main insert end root ActionGroupsInstall -data installtype \
        [list -text "Action Groups" -font TkCaptionFont] $args

    ::InstallJammer::Tree::Setup Install $tree
}

proc Frame.uninstall {} {
    global conf
    global widg
    global preferences

    set widg(Uninstall) [$widg(Product) getframe uninstall].p

    ::InstallJammer::SetHelp PanesAndActions

    if {[winfo exists $widg(Uninstall)]} {
        set conf(TreeFocus) $widg(UninstallTree)

        variable ::InstallJammer::ActiveComponents
        if {[info exists ActiveComponents(Uninstall)]} {
            ::InstallJammer::SetActiveComponent $ActiveComponents(Uninstall)
        }

        return
    }

    set opts [list]
    if {[info exists preferences(Geometry,Uninstall)]} {
        set opts $preferences(Geometry,Uninstall)
    }

    set main $widg(Uninstall)
    eval [list PREFERENCES $widg(Uninstall) \
        -showlines 0 -treewidth 215 -treepadx 20 -deltay 18 \
        -dropovermode p -dragenabled 1 -dropenabled 1 \
        -dropcmd ::InstallJammer::Tree::DropNode \
        -draginitcmd ::InstallJammer::Tree::DragInit] $opts
    pack $main -expand 1 -fill both -side bottom

    set tree [$widg(Uninstall) gettree]
    set widg(UninstallTree) $tree

    set p [winfo parent $widg(Uninstall)]
    set f [frame $p.f1]
    set widg(UninstallButtons) $f
    pack $f -anchor nw

    WinMenuButton $f.addPane -image [GetImage displayscreen16] \
        -menu $f.addPane.panes
    pack $f.addPane -side left -padx 2
    DynamicHelp::add $f.addPane -text "Insert Uninstall Pane"

    set m [MENU $f.addPane.panes]
    set widg(UninstallPanesMenu) $m

    WinMenuButton $f.addAction -image [GetImage insertaction16] \
        -menu $f.addAction.actions
    pack $f.addAction -side left -padx 2
    DynamicHelp::add $f.addAction -text "Insert Action"

    set m [MENU $f.addAction.actions]
    set widg(UninstallActionsMenu) $m

    $m insert end cascade -label "All Actions" -menu $m.all
    MENU $m.all

    foreach group [lsort [array names ::InstallJammer::actiongroups]] {
        set submenu [MENU $m.[WidgetName $group]]
        $m insert end cascade -label "$group   " -menu $submenu

        foreach id $::InstallJammer::actiongroups($group) {
            set action [$id action]
            set allactions($action) $id
            $submenu add command -label [$id title] \
                -command [list ::InstallJammer::AddAction Uninstall $action]
        }
    }

    foreach action [lsort [array names allactions]] {
        set id $allactions($action)
        $m.all add command -label [$id title] \
            -command [list ::InstallJammer::AddAction Uninstall $action]
    }

    WinButton $f.addActionGroup -image [GetImage appwindow_list16] \
        -command [list ::InstallJammer::AddActionGroup Uninstall]
    pack $f.addActionGroup -side left -padx 2
    DynamicHelp::add $f.addActionGroup -text "New Action Group"

    WinButton $f.delete -image [GetImage buttoncancel16] \
        -command [list ::InstallJammer::Tree::Delete $widg(Uninstall)]
    pack $f.delete -side left -padx 2
    DynamicHelp::add $f.delete -text "Delete"

    set args [list -deltax 5 -padx 10 -haspage 0]
    eval $main insert end root CommonUninstall -data installtype \
        [list -text "Common Components" -font TkCaptionFont] $args
    eval $main insert end root StandardUninstall -data installtype \
        [list -text "Standard Uninstall" -font TkCaptionFont] $args
    eval $main insert end root ConsoleUninstall -data installtype \
        [list -text "Console Uninstall" -font TkCaptionFont] $args
    eval $main insert end root SilentUninstall -data installtype \
        [list -text "Silent Uninstall" -font TkCaptionFont] $args
    eval $main insert end root ActionGroupsUninstall -data installtype \
        [list -text "Action Groups" -font TkCaptionFont] $args

    ::InstallJammer::Tree::Setup Uninstall $tree
}

proc Frame.commandLine { setup } {
    global conf
    global widg

    set top [$widg(Product) getframe ${setup}CommandLine]

    ::InstallJammer::SetHelp CommandLineOptions

    if {[winfo exists $top.buttons]} {
        focus $top.sw.table
        return
    }

    set f [frame $top.buttons]
    pack $f -anchor w

    ScrolledWindow $top.sw
    pack $top.sw -expand 1 -fill both -padx 5

    set l [TableList $top.sw.table -cols 7 -bd 1 -relief ridge \
        -background #FFFFFF -selectmode extended -keycolumn 0 \
        -editstartcommand  "::InstallJammer::EditStartCommandLine  %W %i %c" \
        -editfinishcommand "::InstallJammer::EditFinishCommandLine %W %i %c"]

    $top.sw setwidget $l
    set widg(${setup}CommandLineOptionsTable) $l

    $l column configure 0 -title "Option" -width 15
    $l column configure 1 -title "Virtual Text" -width 15
    $l column configure 2 -title "Type" -width 8 \
        -editable 0 -values [list "Boolean" "Choice" "Prefix" "String" "Switch"]
    $l column configure 3 -title "Debug" -width 6 \
        -editable 0 -values [list Yes No]
    $l column configure 4 -title "Hide" -width 6 \
        -editable 0 -values [list Yes No]
    $l column configure 5 -title "Value(s)" -width 25 \
        -browsebutton 1 -browseargs [list -style Toolbutton] \
        -browsecommand "::InstallJammer::EditCommandLineOptionChoices %W %i"
    $l column configure 6 -title "Description" \
        -browsebutton 1 -browseargs [list -style Toolbutton] \
        -browsecommand "::InstallJammer::EditCommandLineOptionDescription %W %i"

    WinButton $f.add -image [GetImage filenew16] \
    	-command [list ::InstallJammer::NewCommandLineOption $l]
    pack $f.add -side left
    DynamicHelp::add $f.add -text "Add New Command Line Option"

    WinButton $f.delete -image [GetImage editdelete16] \
    	-command [list ::InstallJammer::DeleteCommandLineOption $l]
    pack $f.delete -side left
    DynamicHelp::add $f.delete -text "Delete Command Line Option"
}

proc Frame.virtualText {} {
    global conf
    global widg

    set top [$widg(Product) getframe virtualText]

    ::InstallJammer::SetHelp VirtualText

    if {[winfo exists $top.buttons]} {
        focus $top.listframe.listbox
        return
    }

    set f [frame $top.buttons]
    pack $f -anchor w

    ScrolledWindow $top.listframe
    pack $top.listframe -expand 1 -fill both -padx 5

    set l [TableList $top.listframe.listbox -cols 2 -bd 1 -relief ridge \
        -background #FFFFFF -selectmode extended -keycolumn 0 \
        -editstartcommand  "::InstallJammer::EditStartVirtualText  %W %i %c" \
        -editfinishcommand "::InstallJammer::EditFinishVirtualText %W %i %c"]

    $top.listframe setwidget $l
    set widg(VirtualTextTable) $l

    $l tag configure sel -borderwidth 1 -relief ridge
    $l column configure 0 -title "Text" -width 25
    $l column configure 1 -title "Value" \
        -browsebutton 1 -browseargs [list -style Toolbutton] \
        -browsecommand "::InstallJammer::LongEditVirtualText %W %i"

    WinButton $f.add -image [GetImage filenew16] \
    	-command "::InstallJammer::NewVirtualText $l"
    pack $f.add -side left
    DynamicHelp::add $f.add -text "Add New Virtual Text"

    WinButton $f.delete -image [GetImage editdelete16] \
    	-command "::InstallJammer::DeleteVirtualText $l"
    pack $f.delete -side left
    DynamicHelp::add $f.delete -text "Delete Virtual Text"

    ttk::label $f.langL -text "Language"
    pack $f.langL -side left -padx [list 20 2]

    ttk::combobox $f.lang -state readonly \
        -textvariable ::conf(VirtualTextLanguage) \
        -values [::InstallJammer::GetLanguages 1]
    pack $f.lang -side left -padx [list 0 20]

    bind $f.lang <<ComboboxSelected>> \
        "::InstallJammer::LoadVirtualText;after idle [list focus $l]"
}

proc Frame.diskBuilder {} {
    global conf
    global widg

    set top [$widg(Product) getframe diskBuilder]

    ::InstallJammer::SetHelp DiskBuilder

    if {[winfo exists $top.label]} {
        ## If this is the first time the user is seeing the
        ## build log, scroll to the bottom incase there's
        ## already log data in it.
        if {![info exists conf($widg(BuildLog),realized)]} {
            $widg(BuildLog) see end
            set conf($widg(BuildLog),realized) 1
        }

        return
    }

    grid rowconfigure    $top 1 -weight 1
    grid columnconfigure $top 1 -weight 1

    label $top.label -text "Platforms to Build:"
    grid  $top.label -row 0 -column 0 -sticky ws

    set f [frame $top.progressF]
    grid $f -row 0 -column 1 -sticky ew -padx 10
    grid columnconfigure $f 1 -weight 1

    label $f.l1 -text "Build Progress:"
    grid  $f.l1 -row 0 -column 0 -sticky w

    PROGRESSBAR $f.progress -variable ::conf(buildProgress)
    set widg(ProgressBuild) $f.progress
    grid $f.progress -row 0 -column 1 -sticky ew

    label $f.l2 -text "Platform Progress:"
    grid  $f.l2 -row 1 -column 0 -sticky w

    PROGRESSBAR $f.fileProgress -variable ::conf(buildPlatformProgress)
    set widg(ProgressBuildPlatform) $f.fileProgress
    grid $f.fileProgress -row 1 -column 1 -sticky ew

    ScrolledWindow $top.sw1
    grid $top.sw1 -row 1 -column 0 -sticky ns -pady [list 5 10]

    set t [OPTIONTREE $top.buildTree -width 16 -highlightthickness 0]
    $top.sw1 setwidget $t

    set widg(BuildTree) $t

    ScrolledWindow $top.sw2 -auto none
    grid $top.sw2 -row 1 -column 1 -sticky news -padx 10 -pady [list 5 2]

    set widg(BuildLog) [Text $top.log -wrap none -state readonly -height 1]
    $top.sw2 setwidget $top.log

    CHECKBUTTON $top.buildRelease -text "Build for final release" \
        -variable ::conf(buildForRelease)
    grid $top.buildRelease -row 2 -column 1 -sticky w -padx 10
    DynamicHelp::add $top.buildRelease -text "Build installers without \
        debugging options and with options optimized for final release"

    $widg(BuildLog) tag configure error -foreground red

    $widg(BuildLog) tag configure link -foreground blue -underline 1
    $widg(BuildLog) tag bind link <Enter> [list %W configure -cursor hand2]
    $widg(BuildLog) tag bind link <Leave> [list %W configure -cursor ""]
    $widg(BuildLog) tag bind link <1> {
        ::InstallJammer::Explore [InstallDir output]
    }

    set f [frame $top.buttons]
    grid $top.buttons -row 3 -column 1 -sticky e -padx 10

    BUTTON $f.clear -text "Clear Build Log" -width 14 \
        -image [GetImage editshred16] -compound left \
        -command ::InstallJammer::ClearBuildLog
    pack $f.clear -side left -padx 5

    BUTTON $f.build -text "Build Install" -width 14 -command Build \
        -image [GetImage build16] -compound left
    pack   $f.build -side left
}

proc Frame.testInstaller {} {
    global conf
    global widg

    set top [$widg(Product) getframe testInstaller]

    ::InstallJammer::SetHelp TestRun

    if {[winfo exists $top.l1]} { return }

    label $top.l1 -text "Select the options to use on the command-line:"
    pack  $top.l1 -anchor w -pady 5

    label $top.l2 -text "Command-Line:"
    pack  $top.l2 -anchor w

    ENTRY $top.e1 -textvariable ::conf(TestCommandLineOptions)
    pack  $top.e1 -anchor w -fill x
    bind  $top.e1 <Return> TestInstall

    label $top.l3 -text "Test Options:"
    pack  $top.l3 -anchor w -pady 5

    OPTIONTREE $top.options -highlightthickness 0
    pack $top.options -expand 1 -fill both

    bind $top.options <<TreeModify>> AdjustTestInstallOptions

    $top.options insert end root #auto -type checkbutton \
        -text "Save temporary directory for debugging" \
        -variable ::conf(SaveTempDir)

    $top.options insert end root #auto -type checkbutton \
        -text "Test in default mode" \
        -variable ::conf(TestAllDefaults)

    if {!$conf(windows)} {
        $top.options insert end root #auto -type checkbutton \
            -text "Test in console mode" \
            -variable ::conf(TestConsole)
    }

    $top.options insert end root #auto -type checkbutton \
        -text "Test in silent mode" \
        -variable ::conf(TestSilent)

    $top.options insert end root #auto -type checkbutton \
        -text "Test install in test mode and without installing files" \
        -variable ::conf(TestWithoutFiles)

    $top.options insert end root #auto -type checkbutton \
        -text "Test install with an open console window" \
        -variable ::conf(TestWithConsole)

    BUTTON $top.test -text "Test Install" -width 14 -command "TestInstall" \
        -image [GetImage actrun16] -compound left
    pack   $top.test -side bottom -anchor se -padx 5 -pady [list 10 0]

    bind $top <Alt-s> "focus $top.c2"
    bind $top <Alt-t> "focus $top.c1"
    bind $top <Alt-c> "focus $top.c3"
}

proc Frame.testUninstaller {} {
    global conf
    global widg

    set top [$widg(Product) getframe testUninstaller]

    ::InstallJammer::SetHelp TestUninstaller

    if {[winfo exists $top.l1]} { return }

    label $top.l1 -text "Select the options to use on the command-line:"
    pack  $top.l1 -anchor w -pady 5

    label $top.l2 -text "Command-Line:"
    pack  $top.l2 -anchor w

    ENTRY $top.e1 -textvariable ::conf(TestUninstallCommandLineOptions)
    pack  $top.e1 -anchor w -fill x
    bind  $top.e1 <Return> TestUninstall

    label $top.l3 -text "Test Options:"
    pack  $top.l3 -anchor w -pady 5

    OPTIONTREE $top.options -highlightthickness 0
    pack $top.options -expand 1 -fill both

    bind $top.options <<TreeModify>> AdjustTestUninstallOptions

    $top.options insert end root #auto -type checkbutton \
        -text "Save temporary directory for debugging" \
        -variable ::conf(TestUninstallDebugging)

    if {!$conf(windows)} {
        $top.options insert end root #auto -type checkbutton \
            -text "Test in console mode" \
            -variable ::conf(TestUninstallConsoleMode)
    }

    $top.options insert end root #auto -type checkbutton \
        -text "Test in silent mode" \
        -variable ::conf(TestUninstallSilentMode)

    $top.options insert end root #auto -type checkbutton \
        -text "Test uninstall in test mode and without uninstalling files" \
        -variable ::conf(TestUninstallWithoutFiles)

    $top.options insert end root #auto -type checkbutton \
        -text "Test uninstall with an open console window" \
        -variable ::conf(TestUninstallWithConsole)

    BUTTON $top.test -text "Test Uninstall" -width 14 \
        -command "TestUninstall" -image [GetImage edittrash16] -compound left
    pack   $top.test -side bottom -anchor se -padx 5 -pady [list 10 0]
}

proc WindowsPermissionsFrame { f tag arrayName } {
    set row -1

    incr row

    CHECKBUTTON $f.c1 -text "Archive" -variable ${arrayName}(PermArchive) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c1 -row $row -column 0 -sticky w

    CHECKBUTTON $f.c2 -text "Hidden" -variable ${arrayName}(PermHidden) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c2 -row $row -column 1 -sticky w

    CHECKBUTTON $f.c3 -text "Readonly" -variable ${arrayName}(PermReadonly) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c3 -row [incr row] -column 0 -sticky w

    CHECKBUTTON $f.c4 -text "System" -variable ${arrayName}(PermSystem) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c4 -row $row -column 1 -sticky w

    tag addtag $tag class Checkbutton class TCheckbutton children $f

    CHECKBUTTON $f.c -text "Use default attributes" \
    	-variable ${arrayName}(UseWindowsDefaultPermissions) \
    	-command "
    	    if {\$${arrayName}(UseWindowsDefaultPermissions)} {
		tag configure $tag -state disabled
	    } else {
		tag configure $tag -state normal
	    }
            ::FileGroupTree::SetPermissions $arrayName
	"

    grid $f.c -row [incr row] -column 0 -columnspan 2 -sticky w
}

proc UNIXPermissionsFrame { f tag arrayName } {
    set row -1

    set f [frame $f.unix]
    grid $f -row [incr row] -column 0 -columnspan 2 -sticky w

    incr row
    grid [label $f.exec  -text Exec]  -row $row -column 1
    grid [label $f.write -text Write] -row $row -column 2
    grid [label $f.read  -text Read]  -row $row -column 3

    grid [label $f.user  -text User]  -row [incr row] -column 0 -sticky w

    CHECKBUTTON $f.c3 -variable ${arrayName}(PermUserExecute) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c3 -row $row -column 1
    CHECKBUTTON $f.c2 -variable ${arrayName}(PermUserWrite) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c2 -row $row -column 2
    CHECKBUTTON $f.c1 -variable ${arrayName}(PermUserRead) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c1 -row $row -column 3

    grid [label $f.group -text Group] -row [incr row] -column 0 -sticky w

    CHECKBUTTON $f.c6 -variable ${arrayName}(PermGroupExecute) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c6 -row $row -column 1
    CHECKBUTTON $f.c5 -variable ${arrayName}(PermGroupWrite) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c5 -row $row -column 2
    CHECKBUTTON $f.c4 -variable ${arrayName}(PermGroupRead) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c4 -row $row -column 3

    grid [label $f.other -text Other] -row [incr row] -column 0 -sticky w

    CHECKBUTTON $f.c9 -variable ${arrayName}(PermOtherExecute) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c9 -row $row -column 1
    CHECKBUTTON $f.c8 -variable ${arrayName}(PermOtherWrite) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c8 -row $row -column 2
    CHECKBUTTON $f.c7 -variable ${arrayName}(PermOtherRead) \
        -command [list ::FileGroupTree::SetPermissions $arrayName]
    grid $f.c7 -row $row -column 3

    tag addtag $tag class Checkbutton class TCheckbutton children $f

    CHECKBUTTON $f.c -text "Use default permissions" \
    	-variable ${arrayName}(UseUNIXDefaultPermissions) \
    	-command "
    	    if {\$${arrayName}(UseUNIXDefaultPermissions)} {
		tag configure $tag -state disabled
	    } else {
		tag configure $tag -state normal
	    }

            ::FileGroupTree::SetPermissions $arrayName
	"

    grid $f.c -row [incr row] -column 0 -columnspan 4 -sticky w
}

proc Window.preferences {} {
    global widg

    set top $widg(InstallJammer).preferences

    ::InstallJammer::SetHelp InstallBuilderPreferences

    array set ::tmppreferences [array get ::preferences]

    if {[winfo exists $top]} {
	wm deiconify $top
	return
    }

    toplevel     $top
    wm withdraw  $top
    update idletasks
    wm title     $top "InstallJammer Preferences"
    wm geometry  $top 450x400
    wm protocol  $top WM_DELETE_WINDOW "CancelPreferences"
    wm transient $top $widg(InstallJammer)
    BWidget::place $top 450 400 center $widg(InstallJammer)

    bind $top <Return> "SetPreferences"
    bind $top <Escape> "CancelPreferences"

    grid rowconfigure    $top 2 -weight 1
    grid columnconfigure $top 0 -weight 1

    Buttons $top -okcmd "SetPreferences" -cancelcmd "CancelPreferences" \
    	-helpcmd "Help InstallBuilderPreferences" -pack 0

    grid $top.bbox -row 0 -column 0 -sticky e
    grid [Separator $top.bboxsp1] -row 1 -column 0 -sticky ew

    ttk::notebook $top.n
    grid $top.n -row 2 -column 0 -sticky news -pady 10

    ttk::frame $top.n.dirs
    $top.n add $top.n.dirs -text "Directories"

    ttk::frame $top.n.programs
    $top.n add $top.n.programs -text "External Programs"

    ttk::frame $top.n.update
    #$top.n add $top.n.update -text "InstallJammer Update"

    $top.n select $top.n.dirs

    ## Project Directory
    set f $top.n.dirs.f
    pack [frame $f] -anchor nw -fill x -padx 5 -pady {5 0}
    
    grid columnconfigure $f 0 -weight 1

    label $f.projectDirL -text "Project Directory Location"
    grid  $f.projectDirL -row 0 -column 0 -sticky w -padx 5

    ENTRY $f.projectDirE -width 50 -textvariable ::tmppreferences(ProjectDir)
    grid  $f.projectDirE -row 1 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.projectDirB -command \
        [list GetDir ::tmppreferences(ProjectDir) -parent $top]
    grid  $f.projectDirB -row 1 -column 1

    ## Custom Theme Dir
    set f $top.n.dirs.f2
    pack [frame $f] -anchor nw -fill x -padx 5
    
    grid columnconfigure $f 0 -weight 1

    label $f.projectDirL -text "Custom Theme Directory Location"
    grid  $f.projectDirL -row 0 -column 0 -sticky w -padx 5

    ENTRY $f.projectDirE -width 50 \
        -textvariable ::tmppreferences(CustomThemeDir)
    grid  $f.projectDirE -row 1 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.projectDirB -command \
        [list GetDir ::tmppreferences(CustomThemeDir) -parent $top]
    grid  $f.projectDirB -row 1 -column 1

    ## Custom Action Dir
    set f $top.n.dirs.f3
    pack [frame $f] -anchor nw -fill x -padx 5
    
    grid columnconfigure $f 0 -weight 1

    label $f.projectDirL -text "Custom Action Directory Location"
    grid  $f.projectDirL -row 0 -column 0 -sticky w -padx 5

    ENTRY $f.projectDirE -width 50 \
        -textvariable ::tmppreferences(CustomActionDir)
    grid  $f.projectDirE -row 1 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.projectDirB -command \
        [list GetDir ::tmppreferences(CustomActionDir) -parent $top]
    grid  $f.projectDirB -row 1 -column 1

    ## Custom Condition Dir
    set f $top.n.dirs.f4
    pack [frame $f] -anchor nw -fill x -padx 5 -pady {0 5}
    
    grid columnconfigure $f 0 -weight 1

    label $f.projectDirL -text "Custom Condition Directory Location"
    grid  $f.projectDirL -row 0 -column 0 -sticky w -padx 5

    ENTRY $f.projectDirE -width 50 \
        -textvariable ::tmppreferences(CustomConditionDir)
    grid  $f.projectDirE -row 1 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.projectDirB -command \
        [list GetDir ::tmppreferences(CustomConditionDir) -parent $top]
    grid  $f.projectDirB -row 1 -column 1


    ## Create the External Programs tab.

    set f $top.n.programs.f
    pack [frame $f] -anchor nw -expand 1 -fill x -padx 5 -pady 5
    
    grid columnconfigure $f 0 -weight 1

    label $f.l2 -text "File Explorer"
    grid  $f.l2 -row 2 -column 0 -sticky w -padx 5

    ENTRY $f.e2 -width 50 -textvariable ::tmppreferences(FileExplorer)
    grid  $f.e2 -row 3 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.b2 -command \
        [list GetFile ::tmppreferences(FileExplorer) -parent $top]
    grid  $f.b2 -row 3 -column 1

    label $f.l3 -text "Help Browser" -padx 5
    grid  $f.l3 -row 4 -column 0 -sticky w

    set browsers [::InstallJammer::HelpBrowsers]

    ttk::combobox $f.e3 -width 50 -textvariable ::tmppreferences(HelpBrowser) \
    	-values $browsers
    grid  $f.e3 -row 5 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.b3 -command \
        [list GetFile ::tmppreferences(HelpBrowser) -parent $top]
    grid  $f.b3 -row 5 -column 1

    label $f.l4 -text "Editor" -padx 5
    grid  $f.l4 -row 6 -column 0 -sticky w

    ttk::entry $f.e4 -width 50 -textvariable ::tmppreferences(Editor)
    grid  $f.e4 -row 7 -column 0 -sticky ew -padx [list 5 0]

    BrowseButton $f.b4 -command \
        [list GetFile ::tmppreferences(Editor) -parent $top]
    grid  $f.b4 -row 7 -column 1


    ## Create the InstallJammer Update tab.

    set f $top.n.update.f
    pack [frame $f] -anchor nw -expand 1 -fill x -padx 5 -pady 5
    
    grid columnconfigure $f 0 -weight 1

    ttk::checkbutton $f.check \
        -text "Check for updates to InstallJammer on startup" \
        -variable ::tmppreferences(CheckForUpdates)
    grid $f.check -row 0 -column 0 -sticky nw -pady 2

    ttk::checkbutton $f.useProxy \
        -text "Use a proxy server" \
        -variable ::tmppreferences(UseProxyServer) \
        -command {tag configure proxy -state \
        [expr {$::tmppreferences(UseProxyServer) ? "normal" : "disabled"}]}
    grid $f.useProxy -row 1 -column 0 -columnspan 2 -sticky nw -pady {10 2}

    ttk::label $f.proxyHostL -text "Proxy Host"
    grid $f.proxyHostL -row 2 -column 0 -padx 20 -pady {2 0} -sticky nw
    tag add proxy $f.proxyHostL

    ttk::entry $f.proxyHost -textvariable ::tmppreferences(ProxyHost)
    grid $f.proxyHost -row 3 -column 0 -padx 20 -sticky ew
    tag add proxy $f.proxyHost

    ttk::label $f.proxyPortL -text "Proxy Port"
    grid $f.proxyPortL -row 4 -column 0 -padx 20 -pady {2 0} -sticky nw
    tag add proxy $f.proxyPortL

    ttk::entry $f.proxyPort -textvariable ::tmppreferences(ProxyPort)
    grid $f.proxyPort -row 5 -column 0 -padx 20 -sticky ew
    tag add proxy $f.proxyPort

    $f.useProxy invoke
    $f.useProxy invoke

    ttk::button $top.n.update.checkNow -text "Check for Updates Now" \
        -padding {4 2} -command {::InstallJammer::DownloadVersionInfo 1}
    pack $top.n.update.checkNow -anchor se -padx 5 -pady 5


    wm deiconify $top
}

proc Window.filterFileGroups {} {
    global widg

    set top  .__filterFileGroups
    set tree $widg(FileGroupTree)

    set parent $widg(InstallJammer)

    ClearTmpVars

    set ::TMPARRAY(regexp)    0
    set ::TMPARRAY(include)   include
    set ::TMPARRAY(filterall) 1
    set ::TMPARRAY(recursive) 1
    set ::TMPARRAY(includePatterns) [list]
    set ::TMPARRAY(excludePatterns) [list]

    set selection [$tree selection get]
    if {![lempty $selection]} { set ::TMPARRAY(filterall) 0 }

    toplevel     $top
    wm withdraw  $top
    update idletasks
    wm transient $top $parent
    wm geometry  $top 300x260
    wm title     $top "Filter File Groups"
    wm protocol  $top WM_DELETE_WINDOW "set ::TMP 0"
    CenterWindow $top

    bind $top <Escape> "set ::TMP 0"
    bind $top <Return> "set ::TMP 1"

    Buttons $top -okcmd "set ::TMP 1" -cancelcmd "set ::TMP 0" \
    	-helpcmd "Help FilterFileGroups"

    label $top.l1 -text "Include File Patterns:"
    pack  $top.l1 -anchor w

    ENTRY $top.e1 -textvariable ::TMPARRAY(includePatterns)
    pack  $top.e1 -anchor w -fill x

    focus $top.e1

    label $top.l2 -text "Exclude File Patterns:"
    pack  $top.l2 -anchor w

    ENTRY $top.e2 -textvariable ::TMPARRAY(excludePatterns)
    pack  $top.e2 -anchor w -fill x

    CHECKBUTTON $top.c1 -text "Recursively Check File Groups" \
    	-variable ::TMPARRAY(recursive)
    pack $top.c1 -anchor w

    CHECKBUTTON $top.c2 -text "Use Regular Expression Matching" \
    	-variable ::TMPARRAY(regexp)
    pack $top.c2 -anchor w -pady [list 0 5]

    RADIOBUTTON $top.r4 -text "Filter selected file groups" \
    	-variable ::TMPARRAY(filterall) -value 0
    pack $top.r4 -anchor w

    RADIOBUTTON $top.r3 -text "Filter all file groups" \
    	-variable ::TMPARRAY(filterall) -value 1
    pack $top.r3 -anchor w -pady [list 0 5]

    RADIOBUTTON $top.r1 -text "Include files that match both" \
    	-variable ::TMPARRAY(include) -value include
    pack $top.r1 -anchor w

    RADIOBUTTON $top.r2 -text "Exclude files that match both" \
    	-variable ::TMPARRAY(include) -value exclude
    pack $top.r2 -anchor w

    wm deiconify $top
    tkwait variable ::TMP
    destroy $top
    if {!$::TMP} { return }

    lappend opts -regexp    $::TMPARRAY(regexp)
    lappend opts -include   $::TMPARRAY(includePatterns)
    lappend opts -exclude   $::TMPARRAY(excludePatterns)
    lappend opts -recursive $::TMPARRAY(recursive)
    lappend opts -defaultaction $::TMPARRAY(include)

    if {!$::TMPARRAY(filterall)} {
	lappend opts -nodes [$tree selection get]
    }

    eval ::InstallJammer::FilterFileGroups $opts
}

proc VersionFrame {path arrayName args} {
    set command ""
    array set _args $args
    if {[info exists _args(-command)]} {
        set command $_args(-command)
        unset _args(-command)
    }

    eval frame $path [array get _args]

    SPINBOX $path.e1 -textvariable ${arrayName}(MajorVersion) -width 3 -to 999 \
    	-validate key -validatecommand [list ValidateSpinBox %W %s %P] -bd 1
    bind  $path.e1 <Return> $command
    pack  $path.e1 -side left
    label $path.l1 -text "." -bd 1
    pack  $path.l1 -side left
    DynamicHelp::register $path.e1 balloon "Major Version"

    SPINBOX $path.e2 -textvariable ${arrayName}(MinorVersion) -width 3 -to 999 \
    	-validate key -validatecommand [list ValidateSpinBox %W %s %P] -bd 1
    bind  $path.e2 <Return> $command
    pack  $path.e2 -side left
    label $path.l2 -text "." -bd 1
    pack  $path.l2 -side left
    DynamicHelp::register $path.e2 balloon "Minor Version"

    SPINBOX $path.e3 -textvariable ${arrayName}(PatchVersion) -width 3 -to 999 \
    	-validate key -validatecommand [list ValidateSpinBox %W %s %P] -bd 1
    bind  $path.e3 <Return> $command
    pack  $path.e3 -side left
    label $path.l3 -text "." -bd 1
    pack  $path.l3 -side left
    DynamicHelp::register $path.e3 balloon "Patch Version"

    SPINBOX $path.e4 -textvariable ${arrayName}(BuildVersion) -width 3 -to 999 \
    	-validate key -validatecommand [list ValidateSpinBox %W %s %P] -bd 1
    bind  $path.e4 <Return> $command
    pack  $path.e4 -side left
    DynamicHelp::register $path.e4 balloon "Build Version"
}

proc ::InstallJammer::EditFinishProperty { path node } {
    upvar #0 [$path itemcget $node -variable] newvalue
    set oldvalue [$path edit value]

    if {![::InstallJammer::CheckVirtualText $newvalue]} { return 0 }

    if {![string equal $oldvalue $newvalue]} { Modified }

    return 1
}

proc ::InstallJammer::FinishEditVersion { args } {
    global info
    set old $info(InstallVersion)

    set info(InstallVersion)     $info(MajorVersion)
    append info(InstallVersion) .$info(MinorVersion)
    append info(InstallVersion) .$info(PatchVersion)
    append info(InstallVersion) .$info(BuildVersion)

    if {![string equal $old $info(InstallVersion)]} { Modified }

    return 1
}

proc SetInstallPanes {} {
    global conf
    ::msgcat::mcmset en [array get ::InstallJammer::preview::text]
    if {[info exists conf(window)]} { Cancel $conf(window) }
}

proc PopupEditMenu {w X Y} {
    global widg
    set menu $widg(RightClickEditMenu)

    set ::edit::widget $w

    focus $w

    tag configure editMenu -state normal

    if {[lempty [::edit::curselection $w]]} {
	$menu entryconfigure 0 -state disabled
	$menu entryconfigure 1 -state disabled
	$menu entryconfigure 3 -state disabled
    }

    if {[$w cget -state] == "disabled"} {
	$menu entryconfigure 0 -state disabled
	$menu entryconfigure 2 -state disabled
	$menu entryconfigure 3 -state disabled
    }

    if {[catch {clipboard get} clip]} { set clip [list] }
    if {[lempty $clip]} {
	$menu entryconfigure 2 -state disabled
    }

    $menu post $X $Y
    #if {$::tcl_platform(platform) == "unix"} { tkwait window $menu }
}

proc Buttons { w args } {
    set data(-ok) 1
    set data(-cancel) 1
    set data(-help) 1
    set data(-pack) 1

    set data(-oktxt)     OK
    set data(-helptxt)   Help
    set data(-canceltxt) Cancel

    set data(-okimg)     buttonok16
    set data(-helpimg)   acthelp16
    set data(-cancelimg) buttoncancel16

    set data(-okcmd)     "Cancel $w"
    set data(-helpcmd)   "Help"
    set data(-cancelcmd) "Cancel $w"

    array set data $args

    ## Check to see if the image names are references to another image.
    foreach opt {-okimg -cancelimg -helpimg} {
	if {[info exists data(-$data($opt))]} {
	    set data($opt) $data(-$data($opt))
	}
    }

    set f [frame $w.bbox -height 24 -width 235]

    if {$data(-help)} {
	set b [WinButton $f.help -padx 0 -pady 0 \
	    -image [GetImage $data(-helpimg)] \
	    -command $data(-helpcmd)]
	pack $b -side right
	DynamicHelp::register $f.help balloon $data(-helptxt)
    }

    if {$data(-cancel)} {
	set b [WinButton $f.cancel -padx 0 -pady 0\
	    -image [GetImage $data(-cancelimg)] \
	    -command $data(-cancelcmd)]
	pack $b -side right
	DynamicHelp::register $f.cancel balloon $data(-canceltxt)
    }

    if {$data(-ok)} {
	set b [WinButton $f.ok -padx 0 -pady 0 \
	    -image [GetImage $data(-okimg)] \
	    -command $data(-okcmd)]
	pack $b -side right
	DynamicHelp::register $f.ok balloon $data(-oktxt)
    }

    if {$data(-pack)} {
        pack $f -fill x -side top -anchor ne -pady 5
        pack [Separator $w.bboxsp1] -fill x
        pack [frame $w.bboxsp2 -height 5]
    }

    return $f
}

proc SetPreferences {} {
    array set ::preferences [array get ::tmppreferences]
    CancelPreferences
}

proc CancelPreferences {} {
    ::InstallJammer::SetHelp <last>
    wm withdraw [::InstallJammer::TopName .preferences]
}

proc ::InstallJammer::AddPlatformPropertyNode { prop arrayName
                                                {includeArchives 0} } {
    global conf

    $prop insert end root platforms -text "Build Platforms"

    set platforms [AllPlatforms]
    if {$includeArchives} { eval lappend platforms $conf(Archives) }

    foreach platform [lsort $platforms] {
        set pretty [PlatformText $platform]
        AddProperty $prop end platforms foo platform,$platform \
            ::FileGroupTree::details(platform,$platform) -data $platform \
            -pretty $pretty -node platform,$platform -type boolean
    }
}

proc InitializeBindings {} {
    global conf

    if {$conf(osx)} {
        event add <<RightClick>> <Button-2>
    } else {
        event add <<RightClick>> <Button-3>
    }

    BIND all <FocusIn>  { ::InstallJammer::WidgetFocusIn %W }
    BIND all <FocusOut> { ::InstallJammer::WidgetFocusOut %W }

    BIND all <Control-x> ::InstallJammer::EditCut
    BIND all <Control-c> ::InstallJammer::EditCopy
    BIND all <Control-v> ::InstallJammer::EditPaste

    BIND Entry  <<RightClick>> { PopupEditMenu %W %X %Y }
    BIND Entry  <Control-a>    { ::InstallJammer::EditSelectAll }
    BIND Entry  <Control-A>    { ::InstallJammer::EditSelectAll }
    BIND TEntry <Control-a>    { ::InstallJammer::EditSelectAll }
    BIND TEntry <Control-A>    { ::InstallJammer::EditSelectAll }

    BIND Text  <<RightClick>> { PopupEditMenu %W %X %Y }
    BIND Text  <Control-a>    { ::InstallJammer::EditSelectAll }
    BIND Text  <Control-A>    { ::InstallJammer::EditSelectAll }

    BIND Button <Return> { %W invoke }

    #BIND Properties <FocusOut> { ::InstallJammer::FinishEditingActiveNode }
}

proc ::InstallJammer::WidgetFocusIn { w } {
    ::InstallJammer::FinishEditingActiveNode $w

    switch -- [winfo class $w] {
        "Entry" - "TEntry" - "Text" {
            set ::edit::widget $w
        }
    }
}

proc ::InstallJammer::WidgetFocusOut { w } {
    set ::edit::widget ""
}
