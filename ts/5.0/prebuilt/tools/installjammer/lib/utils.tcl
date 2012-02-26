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

proc Window {args} {
    global conf

    set cmd     [lindex $args 0]
    set name    [lindex $args 1]
    if {$name == "" || $cmd == ""} { return }
    set res    [list]
    set exists [winfo exists $name]
    switch $cmd {
        show {
            if {$exists} {
		set res [eval Window$name [lrange $args 2 end]]
	    } else {
		if {[info procs Pre_Window$name] != ""} {
		    eval Pre_Window$name [lrange $args 2 end]
		}
		if {[info procs Window$name] != ""} {
		    set res [eval Window$name [lrange $args 2 end]]
		}
		if {[info procs Post_Window$name] != ""} {
		    eval Post_Window$name [lrange $args 2 end]
		}
	    }
        }

        hide    {
	    if $exists { wm withdraw $name }
	}

	destroy {
	    if $exists { destroy $name }
	}
    }

    return $res
}

proc WidgetName {list} {
    set w [join $list ""]
    return [string tolower [string index $w 0]][string range $w 1 end]
}

proc ShowDialog {window args} {
    global conf

    eval Window show $window $args
    tkwait window $window
}

proc ::InstallJammer::ExecuteInTerminal { file arguments } {
    set desktop [::InstallJammer::GetDesktopEnvironment]

    if {$desktop eq "Gnome"} {
        exec gnome-terminal -e "\"$file\" $arguments" >& /dev/null &
    } elseif {$desktop eq "KDE"} {
        eval exec konsole -e [list $file] $arguments >& /dev/null &
    } else {
        exec xterm -e "\"$file\" $arguments" >& /dev/null &
    }
}

proc TestInstall {} {
    global conf
    global info

    if {!$conf(projectLoaded)} {
	::InstallJammer::Message -message "No project loaded!"
	return
    }

    if {$conf(building)} {
        set    msg "There is a build in progress.  Please wait to test until "
        append msg "the build has completed."
        ::InstallJammer::Message -message $msg
        return
    }

    if {$conf(modified)} {
	set msg "This project has been modified.  "
	append msg "Do you want to save and rebuild before testing?"
	set res [::InstallJammer::MessageBox -type user -buttonwidth 16 \
            -buttons {"Save & Build" "Save & Quick Build" "Cancel"} \
            -title "Project Modified" -message "This project has been\
                modified.  Do you want to save and rebuild before testing?"]

        if {$res == 2} { return }

        update

        Save

        if {$res == 0} {
            Build [::InstallJammer::Platform]
            vwait ::conf(building)
        } else {
            ::InstallJammer::QuickBuild [::InstallJammer::Platform]
        }
    }

    set args $conf(TestCommandLineOptions)

    if {!$info(IncludeDebugging)} {
	foreach opt [list -T -D -C] {
	    if {[lsearch -exact $args $opt] < 0} { continue }
	    ::InstallJammer::MessageBox -title "Debugging Not Included" \
		-message "This install was not built with debugging options."
	    break
	}
    }

    set info(Platform) [::InstallJammer::Platform]
    set info(Ext)      [expr {$info(Platform) eq "Windows" ? ".exe" : ""}]

    set file [::InstallJammer::SubstText [$info(Platform) get Executable]]
    set dir  [InstallDir output]
    if {[$info(Platform) get BuildSeparateArchives]} {
        set dir [InstallDir output/$info(Platform)]
    }
    set file [file join $dir $file]

    if {![file exists $file]} {
	::InstallJammer::MessageBox -title "Build Install First" -message \
	    "You must build the install before you can test it."
	return
    }

    Status "Testing install..." 3000

    if {$conf(TestConsole)} {
        ::InstallJammer::ExecuteInTerminal $file $args
    } else {
        if {$conf(windows)} {
            installkit::Windows::shellExecute open $file $args
        } else {
            eval exec [list $file] $args &
        }
    }
}

proc TestUninstall {} {
    global conf
    global info

    set platform     [::InstallJammer::Platform]
    set dirname      [::InstallJammer::SubstText [$platform get InstallDir]]
    set olduninstall [file join $dirname uninstall$info(Ext)]

    set dir  [::InstallJammer::GetInstallInfoDir]
    set sort [list]

    set file [file join $dir install.log]
    if {[file exists $file]} {
        lappend sort [list [file mtime $file] $olduninstall]
    }

    if {[file exists $olduninstall]} {
        lappend sort [list [file mtime $olduninstall] $olduninstall]
    }

    foreach file [glob -nocomplain -dir $dir *.info] {
        ::InstallJammer::ReadPropertyFile $file tmp
        if {![info exists tmp(Uninstaller)]} {
            lappend sort [list $tmp(Date) $olduninstall]
        } else {
            lappend sort [list $tmp(Date) $tmp(Uninstaller)]
        }
    }

    if {![llength $sort]} {
        ::InstallJammer::Error -message \
            "No uninstaller found.  You must run the installer first."
        return
    }

    set args $conf(TestUninstallCommandLineOptions)
    set file [lindex [lindex [lsort -integer -index 0 $sort] end] 1]

    foreach list [lsort -decreasing -integer -index 0 $sort] {
        set file [lindex $list 1]
        if {[file exists $file]} { break }
    }

    if {$conf(TestUninstallConsoleMode)} {
        ::InstallJammer::ExecuteInTerminal $file $args
    } else {
        if {$conf(windows)} {
            installkit::Windows::shellExecute open $file $args
        } else {
            eval exec [list $file] $args &
        }
    }
}

proc AdjustTestInstallOptions {} {
    global conf
    upvar #0 conf(TestCommandLineOptions) opts

    set head --
    if {$conf(windows)} { set head / }

    array set options {
	SaveTempDir       debug
	TestWithoutFiles  test
	TestAllDefaults   {mode default}
        TestConsole       {mode console}
	TestSilent        {mode silent}
	TestWithConsole   debugconsole
    }

    set opts [list]
    foreach opt [array names options] {
	if {$conf($opt)} { eval lappend opts $head$options($opt) }
    }
}

proc AdjustTestUninstallOptions {} {
    global conf
    upvar #0 conf(TestUninstallCommandLineOptions) opts

    set head --
    if {$conf(windows)} { set head / }

    array set options {
        TestUninstallDebugging     debug
	TestUninstallSilentMode    {mode silent}
	TestUninstallConsoleMode   {mode console}
        TestUninstallWithConsole   debugconsole
	TestUninstallWithoutFiles  test
    }

    set opts [list]
    foreach opt [array names options] {
	if {$conf($opt)} { eval lappend opts $head$options($opt) }
    }
}

proc InstallKitBinary { {type ""} } {
    return [InstallKitStub [::InstallJammer::Platform] $type]
}

proc BuildBinary {} {
    return [InstallKitStub [::InstallJammer::Platform]]
}

proc InstallKitStub { platform {type ""} } {
    global conf
    global info

    set exe installkit
    if {$platform eq "Windows"} {
        if {[$platform get UseUncompressedBinaries]} { append exe "U" }
        if {[$platform get RequireAdministrator]} { append exe "A" }
        append exe .exe
    }

    set stub [file join $conf(pwd) Binaries $platform $exe]

    if {![file exists $stub]} {
        ::InstallJammer::Error -message \
	    "Could not find the appropriate installkit binary for $platform!"
	::exit
    }

    return $stub
}

proc InstallDir { {file ""} } {
    global conf
    global info

    if {[info exists info(ProjectDir)]} {
    	set dir $info(ProjectDir)
    } else {
	set dir [file join $conf(pwd) Installs $info(Project)]
    }

    if {$file ne ""} { set dir [file join $dir $file] }
    if {$conf(windows) && [file exists $dir]} {
	set dir [file attributes $dir -longname]
    }

    return $dir
}

proc AllPlatforms {} {
    global conf

    if {$conf(demo)} {
    	return [list Linux-x86 Windows]
    }

    if {![info exists conf(platforms)]} {
        set bindir [file join $::conf(pwd) Binaries]

        set conf(platforms) [list]
        set platformlist [glob -nocomplain -type d -dir $bindir *]
        foreach dir [lsort $platformlist] {
            set platform [file tail $dir]

            set exe installkit
            if {$platform eq "Windows"} { append exe .exe }

            if {[file exists [file join $dir $exe]]} {
                lappend conf(platforms) $platform
            }
        }
    }

    return $conf(platforms)
}

proc ActivePlatforms {} {
    global info

    set platforms [list]
    foreach platform [AllPlatforms] {
        if {[$platform active]} { lappend platforms $platform }
    }
    return $platforms
}

proc ::InstallJammer::IsRealPlatform { platform } {
    return [expr {[lsearch -exact [AllPlatforms] $platform] > -1}]
}

proc PlatformText { platform } {
    if {[::InstallJammer::IsRealPlatform $platform]} {
        return [join [split $platform -_]]
    }
    return [::InstallJammer::StringToTitle $platform]
}

proc PlatformName { platform } {
    return [string map [list . _] $platform]
}

proc SetPlatform {} {
    global preferences

    if {[info exists preferences(platform)]} { return }

    set platform [::InstallJammer::Platform]
    set platforms [AllPlatforms]
    if {[lsearch -exact $platforms $platform] > -1} { return }

    set top .__installJammer__selectPlatform

    toplevel    $top
    wm withdraw $top
    wm title    $top "Select Platform"
    wm protocol $top WM_DELETE_WINDOW "::exit"
    wm geometry $top 180x110
    ::InstallJammer::CenterWindow $top 180 110

    set msg "InstallJammer could not determine your platform.  Please choose "
    append msg "an appropriate platform from the list below."
    message $top.msg -text $msg -width 180
    pack $top.msg -anchor w -fill x

    label $top.l -text "Platform"
    pack  $top.l -anchor w

    frame $top.f
    pack  $top.f -anchor w

    COMBOBOX $top.f.cb -textvariable ::TMP -values $platforms
    pack $top.f.cb -side left

    button $top.f.b -text "Ok" -command "destroy $top"
    pack   $top.f.b -side left

    wm deiconify $top
    raise $top
    grab set $top
    tkwait window $top
    grab set .splash
    set ::preferences(platform) $::TMP
    unset ::TMP
}

proc ::InstallJammer::NodeName { obj } {
    if {[info exists ::InstallJammer::ObjMap($obj)]} {
        return $::InstallJammer::ObjMap($obj)
    }
    return $obj
}

proc ::InstallJammer::FileKey { parent name } {
    set name [file normalize $name]
    if {$::conf(windows)} { set name [string tolower $name] }
    if {![$parent is filegroup]} { set name [file tail $name] }
    return $parent,$name
}

proc ::InstallJammer::FileObj { parent name args } {
    global widg

    if {$::conf(windows)} { set name [file normalize $name] }

    set key [::InstallJammer::FileKey $parent $name]
    if {[info exists ::InstallJammer::FileMap($key)]} {
        set id $::InstallJammer::FileMap($key)
    } else {
        set id [::InstallJammer::uuid]

        if {![$parent is filegroup]} { set name [file tail $name] }
        eval [list ::File ::$id -name $name -parent $parent] $args
        set ::InstallJammer::FileMap($key)  $id
        set ::InstallJammer::NewFiles($key) 1

	if {[info exists widg(FileGroupTree)]} {
	    set pnode [::InstallJammer::NodeName $parent]
	    if {[$widg(FileGroupTree) visible $pnode]} {
		::InstallJammer::AddToFileTree $id -text [file tail $name]
	    }
	}

        Modified
        ::InstallJammer::FilesModified
    }

    return $id
}

proc ::InstallJammer::FileIsNew { parent name } {
    set key [::InstallJammer::FileKey $parent $name]
    return [info exists ::InstallJammer::NewFiles($key)]
}

## Add directories and files to the selected file group.
## All requests to add directories and files to a project pass through
## this routine, including drag-and-drop'd items.
proc AddFiles { args } {
    global info
    global conf
    global widg

    array set data {
        -isdir     0
        -files     ""
        -group     ""
    }
    array set data $args

    set tree $widg(FileGroupTree)
    set pref $widg(FileGroupPref)

    set n [::InstallJammer::NodeName $data(-group)]
    if {![string length $data(-group)]} { set n [$tree selection get] }

    if {[lempty $n]} { return }

    set group [$tree itemcget $n -data]
    set node  [::InstallJammer::NodeName $group]

    set files $data(-files)

    if {[lempty $files]} {
	if {$data(-isdir)} {
	    set files [list [mpi_chooseDirectory]]
	} else {
	    set files [mpi_getOpenFile -multiple 1]
	}
        if {![llength $files]} { return }
    }

    $tree configure -cursor watch
    Status "Adding files..."

    set dirList [list]
    foreach file $files {
        if {$file eq ""} { continue }

        if {[string match "file:*" $file]} {
            set file [string range $file 5 end]
            set file [::InstallAPI::DecodeURL -url $file]
        }

        if {[string equal $::tcl_platform(platform) "windows"]} {
            set file [file attributes $file -longname]
        }

        if {[file isdirectory $file]} {
            lappend dirList $file
        } else {
            AddToFileGroup -type file -group $group -parent $group -name $file
        }
    }

    foreach dir $dirList {
        if {[string equal $::tcl_platform(platform) "windows"]} {
            set dir [file attributes $dir -longname]
        }

        set dirid [AddToFileGroup -type dir -group $group \
                -parent $group -name $dir]

        ## Scan through the directory recursively so we
        ## can create a file object for every file.
        ::InstallJammer::RecursiveGetFiles $dirid [$group get FollowDirLinks]
    }

    ::FileGroupTree::SortNodes $node

    $tree configure -cursor {}
    ClearStatus

    ## Make sure the selected file group is visible by opening
    ## its parents up the tree.
    if {![$tree visible $node]} {
	set node [$tree parent $node]
	while {![string equal $node "root"]} {
	    $tree opentree $node 0
	    set node [$tree parent $node]
	}
    }
}

proc AddToFileGroup { args } {
    global info
    global conf
    global widg

    array set data {
        -id       ""
        -name     ""
        -text     ""
        -type     ""
        -group    ""
        -parent   ""
        -modify   1
    }
    array set data $args

    set tree   $widg(FileGroupTree)
    set pref   $widg(FileGroupPref)
    set name   $data(-name)
    set text   $data(-text)
    set type   $data(-type)
    set group  $data(-group)
    set parent $data(-parent)

    set node   [::InstallJammer::NodeName $parent]

    set id $data(-id)
    if {![string length $id]} {
        set id [::InstallJammer::FileObj $parent $name -type $type]
    } else {
        set name   [$id name]
        set type   [$id type]
        set group  [$id group]
        set node   [::InstallJammer::NodeName [$id parent]]
        set parent [$id parent]
    }

    set file [::InstallJammer::GetFileSource $id]

    set new     [::InstallJammer::FileIsNew $parent $file]
    set subnode [::InstallJammer::NodeName $id]

    if {[$tree exists $subnode]} { return $id }

    set treeopts [list -data $id -pagewindow $widg(FileGroupDetails)]

    ## Highlight newly-added items in blue.
    if {$new} { lappend treeopts -fill blue }

    ## If a file cannot be found, show it as disabled.
    if {![file exists $file]} { lappend treeopts -fill SystemDisabledText }

    switch -- $type {
        "dir"  {
            set img folder16
            lappend treeopts -drawcross allways
        }
        "file" {
            set img filedocument16
            lappend treeopts -drawcross auto
        }
    }

    if {[$id active]} { set img check$img }
    if {$text eq ""} { set text [file tail $name] }

    lappend treeopts -text $text -image [GetImage $img]

    eval [list $pref insert end $node $subnode] $treeopts

    if {$new && $data(-modify)} {
        Modified
        ::InstallJammer::FilesModified
    }

    return $id
}

proc ::InstallJammer::AddToFileTree { id args } {
    global conf
    global widg

    set tree   $widg(FileGroupTree)
    set pref   $widg(FileGroupPref)
    set node   [::InstallJammer::NodeName $id]
    set parent [$id parent]

    if {[$tree exists $node]} { return $id }

    set file [::InstallJammer::GetFileSource $id]

    set opts [list -data $id -pagewindow $widg(FileGroupDetails)]

    ## Highlight newly-added items in blue.
    if {[::InstallJammer::FileIsNew $parent $file]} {
        lappend opts -fill blue
    }

    ## If a file cannot be found, show it as disabled.
    if {![file exists $file]} {
        lappend opts -fill SystemDisabledText
    }

    switch -- [$id type] {
        "dir"  {
            set img folder16
            lappend opts -drawcross allways
        }
        "file" {
            set img filedocument16
            lappend opts -drawcross auto
        }
    }

    if {[$id active]} { set img check$img }

    lappend opts -image [GetImage $img]

    set parent [::InstallJammer::NodeName $parent]

    eval [list $pref insert end $parent $node] $opts $args

    if {[info exists conf(SortTreeNodes)]} {
        lappend conf(SortTreeNodes) $parent
    }
}

proc AddToRecentProjects { filename } {
    global preferences

    set filename [file normalize $filename]
    if {[lsearch -exact $preferences(RecentProjects) $filename] < 0} {
        lappend preferences(RecentProjects) $filename
    }

    UpdateRecentProjects
}

proc UpdateRecentProjects {} {
    global conf
    global info
    global widg
    global preferences

    variable ::InstallJammer::ProjectItemMap

    set w      $widg(Projects)
    set font   TkTextFont
    set header TkCaptionFont

    $w delete text

    set startX 20
    set startY 60

    set x   $startX
    set y   $startY
    set max 350
    foreach filename $preferences(RecentProjects) {
        if {![file exists $filename]} {
            set preferences(RecentProjects) \
                [lremove $preferences(RecentProjects) $filename]
            continue
        }
        lappend sort([file tail $filename]) $filename
    }

    set dir [GetPref ProjectDir]
    foreach dir [glob -nocomplain -type d -dir $dir *] {
	set tail [file tail $dir]
	set file [file join $dir $tail.mpi]
	if {[file exists $file]
	    && [lsearch -exact $preferences(RecentProjects) $file] < 0} {
	    lappend sort($tail.mpi) $file
	}
    }

    foreach project [lsort -dict [array names sort]] {
        foreach filename $sort($project) {
            set file [file tail $filename]
            set i [$w create text $x $y -text $file -anchor nw -font $header \
                -fill blue -tags [list text project]]
            DynamicHelp::add $w -item $i -text "Location $filename"
            set size [font measure $font $file]
            if {$size > $max} { set max $size }
            set ProjectItemMap($i) $filename
            set ProjectItemMap($filename) $i

            if {[info exists info(ProjectFile)]
                && [string equal -nocase $filename $info(ProjectFile)]} {
                set conf(SelectedProject) $i
            }

            incr y 20
        }
    }

    set x [expr {$startX + $max + 50}]
    set y $startY
    foreach project [lsort -dict [array names sort]] {
        foreach filename $sort($project) {
            set i $ProjectItemMap($filename)
            $w create text $x $y -text [LastSaved $filename] \
                -anchor nw -font $font -tags [list text $i-lastsaved]
            $w create text [expr {$x + 200}] $y -text [LastBuilt $filename] \
                -anchor nw -font $font -tags [list text $i-lastbuilt]

            incr y 20
        }
    }

    set conf(maxProjectSize) $max

    set y [expr {$startY - 30}]
    $w create text $startX $y -text "Project" \
        -anchor nw -font $header -tags [list text]
    $w create text $x $y -text "Last Saved" \
        -anchor nw -font $header -tags [list text]
    $w create text [expr {$x + 200}] $y -text "Last Built" \
        -anchor nw -font $header -tags [list text]

    if {![llength $preferences(RecentProjects)]} {
        $w create text $startX $startY -text "No Projects" -anchor nw -tags text
    }

    $w configure -scrollregion [$w bbox all]
}

proc ::InstallJammer::EnterProjectItem { w } {
    variable ProjectItemMap
    set i [$w find withtag current]

    $w itemconfigure $i -fill red
    Status $ProjectItemMap($i)
}

proc ::InstallJammer::LeaveProjectItem { w } {
    $w itemconfigure current -fill blue
    Status ""
}

proc LastSaved { filename } {
    global conf
    if {![file exists $filename]} { return 0 }
    return [clock format [file mtime $filename] -format "%D %r"]
}

proc LastBuilt { filename } {
    global conf
    set file [file join [file dirname $filename] build.log]
    if {![file exists $file]} {
	return "Never Built"
    } else {
	return [clock format [file mtime $file] -format "%D %r"]
    }
}

proc ::InstallJammer::SetLastSaved {} {
    global info
    global widg
    variable ProjectItemMap

    set filename [file normalize $info(ProjectFile)]
    set i $ProjectItemMap($filename)
    $widg(Projects) itemconfigure $i-lastsaved -text [LastSaved $filename]
}

proc ::InstallJammer::SetLastBuilt {} {
    global conf
    global info
    global widg
    variable ProjectItemMap

    if {$conf(cmdline)} { return }

    set filename [file normalize $info(ProjectFile)]
    set i $ProjectItemMap($filename)
    $widg(Projects) itemconfigure $i-lastbuilt -text [LastBuilt $filename]
}

proc ::InstallJammer::LoadProject { {force 0} } {
    global conf
    global widg
    variable ProjectItemMap

    if {$force || $conf(SelectedProject) eq ""} {
        set conf(SelectedProject) [$widg(Projects) find withtag current]
    }

    Open $ProjectItemMap($conf(SelectedProject))
}

proc ::InstallJammer::ProjectPopup { X Y } {
    global conf
    global widg

    set conf(SelectedProject) [$widg(Projects) find withtag current]

    set menu $widg(Projects).rightClick

    $menu post $X $Y
}

proc ::InstallJammer::DeleteProject {} {
    global conf
    global info
    global widg
    variable ::InstallJammer::ProjectItemMap

    set i       $conf(SelectedProject)
    set file    $ProjectItemMap($i)
    set dir     [file dirname $file]
    set project [file root [file tail $file]]

    set ans [::InstallJammer::MessageBox -parent $widg(InstallJammer) \
        -title "Delete Project" -type yesno \
	-message "The project directory '$dir' will be completely\
	    deleted.\nAre you sure you want to delete $project?"]

    if {$ans eq "no"} { return }

    if {[info exists info(Project)] && $project eq $info(Project)} {
    	if {![Close 1]} { return }
    }

    set dir [file dirname $file]

    set     files [list $file]
    lappend files [file join $dir build.log]
    lappend files [file join $dir build]
    lappend files [file join $dir output]

    eval [list file delete -force] $files

    if {[::InstallJammer::DirIsEmpty $dir]} {
    	file delete -force $dir
    } else {
    	::InstallJammer::MessageBox -title "Project Deleted" -message \
	    "Your project has been deleted, but the directory could not\
	     be removed because it is not empty."
    }

    UpdateRecentProjects
}

proc ::InstallJammer::DuplicateProject {} {
    global conf
    global info
    global widg

    variable ::InstallJammer::ProjectItemMap

    set w $widg(Projects)

    set dir [GetPref ProjectDir]

    set i $conf(SelectedProject)

    set projectFile $ProjectItemMap($i)
    set projectName [file root [file tail $projectFile]]

    set ans [::InstallJammer::MessageBox -type yesno \
    	-title "Duplicate Project" \
    	-message "Are you sure you want to duplicate $projectName?"]

    if {$ans eq "yes"} {
	if {[info exists info(Project)] && $projectName eq $info(Project)} {
	    set msg "This project must be closed before it can be\
	    	duplicated, and there are modifications.\nDo you wish to\
		save your changes before duplicating?"

	    if {![Close 0 $msg]} { return }
	}

        set new     [NextProjectName $projectName]
	set newdir  [file join $dir $new]
	set newfile [file join $newdir $new.mpi]
	set filedir [file dirname $projectFile]

	file mkdir $newdir

	foreach file [glob -nocomplain -dir $filedir *] {
	    set tail [file tail $file]

	    if {$file eq $projectFile
	    	|| $tail eq "build"
		|| $tail eq "output"
		|| $tail eq "build.log"} { continue }

	    set newfile [string map [list $filedir $newdir] $file]
	    set newdir  [file dirname $newfile]

	    file mkdir $newdir

	    file copy $file $newfile
	}

	file copy $projectFile $newfile

	AddToRecentProjects $newfile

	set conf(SelectedProject) $ProjectItemMap($newfile)

	::InstallJammer::RenameProject
    }
}

proc ::InstallJammer::RenameProject {} {
    global conf
    global info
    global widg

    variable ::InstallJammer::ProjectItemMap

    set w       $widg(Projects)
    set i       $conf(SelectedProject)
    set file    $ProjectItemMap($i)
    set project [file root [file tail $file]]

    lassign [$w bbox $i] x y

    if {[info exists info(Project)] && $project eq $info(Project)} {
	set msg "This project must be closed before it can be\
	    renamed, and there are modifications.\nDo you wish to\
	    save your changes before renaming?"

    	if {![Close 0 $msg]} { return }
    }

    ClearTmpVars

    set e $w.renameProject
    entry $w.renameProject -relief sunken -bd 1 -textvariable ::TMPARRAY(p)

    bind $e <Escape> {set ::TMP 0}
    bind $e <Return> {set ::TMP 1}

    $e insert 0 $project
    $e selection range 0 end

    set n [$w create window [list $x $y] -window $e -anchor nw \
        -width $conf(maxProjectSize)]

    after idle [list focus -force $e]

    tkwait variable ::TMP

    destroy $e
    $w delete $n

    if {$::TMP && $::TMPARRAY(p) ne $project} {
    	set new $::TMPARRAY(p)
	set dir [file dirname $file]

	set tail [file tail $dir]

	set newdir $dir
	if {$tail eq $project} {
	    set newdir [file join [file dirname $dir] $new]
	    file rename $dir $newdir
	}

	set oldfile [file join $newdir [file tail $file]]
	set newfile [file join $newdir $new.mpi]

	file rename $oldfile $newfile

	AddToRecentProjects $newfile
    }
}

proc ::InstallJammer::ExploreProject {} {
    global conf
    global widg
    variable ::InstallJammer::ProjectItemMap

    set i    $conf(SelectedProject)
    set file $ProjectItemMap($i)

    ::InstallJammer::Explore [file dirname $file]
}

proc ::InstallJammer::BackupProjectFile { args } {
    global info

    if {[llength $args] == 2} {
        lassign $args oldFile newFile
    } else {
        set newFile [lindex $args 0]
        set oldFile $info(ProjectFile)
    }

    set oldFile [::InstallJammer::SubstText $oldFile]
    set newFile [::InstallJammer::SubstText $newFile]

    if {[file pathtype $newFile] eq "relative"} {
        set newFile [file join $info(ProjectDir) $newFile]
    }

    file copy -force $oldFile $newFile
}

proc ::InstallJammer::ExploreTestInstall {} {
    global conf
    global info

    if {!$conf(projectLoaded)} {
	::InstallJammer::Message -message "Project must be loaded first."
	return
    }

    set platform [::InstallJammer::Platform]
    set dirname  [::InstallJammer::SubstText [$platform get InstallDir]]

    set dir  [::InstallJammer::GetInstallInfoDir]
    set sort [list]

    set file [file join $dir install.log]
    if {[file exists $file]} {
        lappend sort [list [file mtime $file] $dirname]
    }

    foreach file [glob -nocomplain -dir $dir *.info] {
        ::InstallJammer::ReadPropertyFile $file tmp
        lappend sort [list $tmp(Date) $tmp(Dir)]
    }

    set dirname [lindex [lindex [lsort -integer -index 0 $sort] end] 1]

    if {![file exists $dirname]} {
        ::InstallJammer::Message -message \
            "No install found.  You must run the installer first."
    } else {
        ::InstallJammer::Explore $dirname
    }
}

proc NewNode {} {
    variable ::InstallJammer::nNodes
    if {![info exists nNodes]} { set nNodes 0 }
    return [incr nNodes]
}

proc Exit {} {
    global conf

    if {$conf(exiting)} { return }

    set conf(exiting) 1
    
    if {$conf(modified) && ![Close]} {
        set conf(exiting) 0
        return
    }

    ::InstallJammer::SavePreferences

    foreach font [font names] { font delete $font }

    exit
}

proc FileList {dir} {
    global conf

    set list [glob -nocomplain [file join $conf(pwd) $dir *]]
    set return {}
    foreach dir [lsort -dict $list] {
    	lappend return [file tail $dir]
    }
    return $return
}

proc ProjectList {} {
    global conf

    set list [FileList Installs]
    set projects {}
    ## Find all the project directories.  If a directory doesn't have a
    ## install.cfg file, it's just some random directory in our Projects folder,
    ## so we skip it.
    set dir [file join $conf(pwd) Installs]
    foreach project $list {
	set file [file join $dir $project install install.cfg]
	if {![file isdirectory [file join $dir $project]]} { continue }
	if {![file exists $file]} { continue }
	lappend projects $project
    }
    return $projects
}

# -------------------------------------------------------------------
# Routines for encoding and decoding base64
# encoding from Time Janes,
# decoding from Pascual Alonso,
# namespace'ing and bugs from Parand Tony Darugar
# (tdarugar@binevolve.com)
#
# -------------------------------------------------------------------

namespace eval base64 {
  set charset "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

  # This proc by Christian Gavin
  proc encode_file {filename} {
     set inID [open $filename r]
     fconfigure $inID -translation binary
     set contents [read $inID]
     close $inID

     set encoded [::base64::encode $contents]
     set length  [string length $encoded]
     set chunk   60
     set result  ""

     for {set index 0} {$index < $length} {set index [expr $index + $chunk] } {
         set index_end [expr $index + $chunk - 1]

         if {$index_end >= $length} {
             set index_end [expr $length - 1]
             append result [string range $encoded $index $index_end]
         } else {
             append result [string range $encoded $index $index_end]
         }
     }

     return $result
  }

  # ----------------------------------------
  # encode the given text
  proc encode {text} {
    set encoded ""
    set y 0
    for {set i 0} {$i < [string length $text] } {incr i} {
      binary scan [string index $text $i] c x
      if { $x < 0 } {
        set x [expr $x + 256 ]
      }
      set y [expr ( $y << 8 ) + $x]
      if { [expr $i % 3 ] == 2}  {
        append  encoded [string index $base64::charset [expr ( $y & 0xfc0000 ) >> 18 ]]
        append  encoded [string index $base64::charset [expr ( $y & 0x03f000 ) >> 12 ]]
        append  encoded [string index $base64::charset [expr ( $y & 0x000fc0 ) >> 6 ]]
        append  encoded [string index $base64::charset [expr ( $y & 0x00003f ) ]]
        set y 0
      }
    }
    if { [expr $i % 3 ] == 1 } {
      set y [ expr $y << 4 ]
      append encoded [string index $base64::charset [ expr ( $y & 0x000fc0 ) >> 6]]
      append encoded [string index $base64::charset [ expr ( $y & 0x00003f ) ]]
      append encoded "=="
    }
    if { [expr $i % 3 ] == 2 } {
      set y [ expr $y << 2 ]
      append  encoded [string index $base64::charset [expr ( $y & 0x03f000 ) >> 12 ]]
      append  encoded [string index $base64::charset [expr ( $y & 0x000fc0 ) >> 6 ]]
      append  encoded [string index $base64::charset [expr ( $y & 0x00003f ) ]]
      append encoded "="
    }
    return $encoded
  }

  # ----------------------------------------
  # decode the given text
  # Generously contributed by Pascual Alonso
  proc decode {text} {
    set decoded ""
    set y 0
    if {[string first = $text] == -1} {
      set lenx [string length $text]
    } else {
      set lenx [string first = $text]
    }
    for {set i 0} {$i < $lenx } {incr i} {
      set x [string first [string index $text $i] $base64::charset]
      set y [expr ( $y << 6 ) + $x]
      if { [expr $i % 4 ] == 3}  {
        append decoded \
	  [binary format c [expr $y >> 16 ]]
	append decoded \
	  [binary format c [expr ( $y & 0x00ff00 ) >> 8 ]]
	append decoded \
	  [binary format c [expr ( $y & 0x0000ff ) ]]
	set y 0
      }
    }
    if { [expr $i % 4 ] == 3 } {
      set y [ expr $y >> 2 ]
	append decoded \
	  [binary format c [expr ( $y & 0x00ff00 ) >> 8 ]]
	append decoded \
	  [binary format c [expr ( $y & 0x0000ff ) ]]
    }
    if { [expr $i % 4 ] == 2 } {
      set y [ expr $y >> 4 ]
	append decoded \
	  [binary format c [expr ( $y & 0x0000ff ) ]]
    }
    return $decoded
  }
}

proc GetFile { varName args } {
    set x [eval mpi_getOpenFile $args]
    if {[lempty $x]} { return }
    upvar $varName var
    set var $x
}

proc GetDir { varName args } {
    upvar $varName var
    if {[info exists var]} { lappend args -initialdir $var }
    set x [eval mpi_chooseDirectory $args]
    if {[string length $x]} { set var $x }
}

proc GetImageFile {varName} {
    set types {
    	{"Images"		{.gif .png}}
    }

    set x [mpi_getOpenFile -filetypes $types]
    if {$x == ""} { return }
    upvar $varName var
    set var $x
}

proc GetIconFile { varName } {
    set types {
    	{"Windows Icons"        .ico}
    }

    set x [mpi_getOpenFile -filetypes $types]
    if {$x == ""} { return }
    upvar $varName var
    set var $x
}

proc GetColor { w varName {property 0} } {
    upvar #0 $varName color

    if {$property} { set w [$w edit browsepath] }

    set top [::InstallJammer::TopName .__getColor]

    if {$color eq "" || $color eq "system"} { set color #FFFFFF }

    set newcolor [SelectColor::menu $top [list right $w] -color $color]

    if {![lempty $newcolor]} { set color $newcolor }
}

proc Children {win} {
    set children [winfo children $win]

    set list {}
    foreach w $children {
	lappend list $w
	eval lappend list [Children $w]
    }
    return $list
}

proc ::InstallJammer::EditPaneProc { id } {
    set obj  [$id object]
    set pane [$id component]

    uplevel #0 [list source [::InstallJammer::GetPaneSourceFile $id]]

    ClearTmpVars

    set proc  [::InstallJammer::GetPaneProc $id CreateWindow]
    set old   [string trim [info body $proc] \n]
    set ::TMP $old
    ::editor::new -font "Courier 10" -title "Editing $pane pane for $id" \
        -variable ::TMP
    set body [string trim $::TMP \n]

    if {$body ne $old} {
        proc ::CreateWindow.$id [info args $proc] \n$body\n

        set file [InstallDir Theme/[$id setup]/$id.tcl]
        file mkdir [file dirname $file]

        set fp [open $file w]
        puts  $fp [ProcDefinition ::CreateWindow.$id]
        close $fp

        Modified
    }
}

proc ::InstallJammer::RestorePaneProc { id } {
    set ans [::InstallJammer::MessageBox -icon question -type yesno \
        -message "Are you sure you want to restore the original code\
                        for this pane?"]
    if {$ans eq "yes"} {
        set file [InstallDir Theme/[$id setup]/$id.tcl]
        file delete $file

        if {[::InstallJammer::CommandExists ::CreateWindow.$id]} {
            rename ::CreateWindow.$id ""
        }
    }
}

proc EditTextField { id field title varName {multilang 1} args } {
    global conf
    upvar #0 $varName var

    variable ::InstallJammer::languages

    if {![::InstallJammer::ObjExists $id]} {
        set id [::InstallJammer::GetActiveComponent]
    }

    if {[GetPref Editor] ne ""} {
        set cmd [list ::InstallJammer::FinishExternalEditTextField $id $field]
        ::InstallJammer::LaunchExternalEditor $var $cmd
        return
    }

    set conf(editOldText)   $var
    set conf(editTextField) [list $id $field]

    set args [linsert $args 0 -title $title -variable $varName]

    if {$multilang} {
        set args [linsert $args 0 -languages 1 \
            -languagecommand ::InstallJammer::EditorLanguageChanged]
    }

    set res [eval ::editor::new $args]

    if {$multilang} {
        if {$res} {
            if {[string index $var end] eq "\n"} {
                set var [string range $var 0 end-1]
            }

            if {$var ne $conf(editOldText)} {
                set lang [list [::editor::language]]
                ::InstallJammer::SetVirtualText $lang $id $field $var
            }
        }

        set var [::InstallJammer::GetText $id $field -subst 0]
    }

    if {$var ne $conf(editOldText)} { Modified }
}

proc ::InstallJammer::EditorLanguageChanged {} {
    global conf

    variable languages

    lassign $conf(editTextField) id field

    if {[::editor::modified]} {
        set ans [::InstallJammer::Message \
            -type yesnocancel -title "Text Modified" \
            -message "Text has been modified.  Do you want to save changes?"]

        if {$ans eq "cancel"} { return }
        if {$ans eq "yes"} {
            set lang [list [::editor::lastlanguage]]
            set text [::editor::gettext]
            if {[string index $text end] eq "\n"} {
                set text [string range $text 0 end-1]
            }
            ::InstallJammer::SetVirtualText $lang $id $field $text
            Modified
        }
    }

    set lang [list [::editor::language]]
    set text [::InstallJammer::GetText $id $field -language $lang -subst 0]

    ::editor::settext $text

    set conf(editOldText) $text
}

proc BindMouseWheel { w {cmd WheelScroll} } {
    set top [winfo toplevel $w]
    switch -- $::tcl_platform(platform) {
	"windows" {
	    bind $top <MouseWheel> "$cmd $w 5 units %D"
	    bind $top <Control-MouseWheel> "$cmd $w 1 units %D"
	    bind $top <Shift-MouseWheel> "$cmd $w 1 pages %D"
	}

	"unix" {
	    bind $top <4> "$cmd $w -5 units"
	    bind $top <5> "$cmd $w  5 units"
	    bind $top <Control-4> "$cmd $w -1 units"
	    bind $top <Control-5> "$cmd $w  1 units"
	    bind $top <Shift-4> "$cmd $w -1 pages"
	    bind $top <Shift-5> "$cmd $w  1 pages"
	}
    }
}

proc WheelScroll {w num type {delta 0}} {
    if {$delta > 0} { set num -$num }
    $w yview scroll $num $type
}

proc Modified { {status 1} } {
    if {$status != $::conf(modified)} {
        set ::conf(modified) $status
        ::InstallJammer::SetMainWindowTitle
    }
}

proc ::InstallJammer::FilesModified { {status 1} } {
    set ::conf(filesModified) $status
}

proc ClearTmpVars {} {
    unset -nocomplain ::TMP
    unset -nocomplain ::TMPARRAY
    unset -nocomplain ::platforms
}

proc InstallDirList { platform {group ""} } {
    global conf
    global info
    global widg

    set list [list <%InstallDir%> <%ProgramFolder%> <%Temp%> <%Home%>]

    if {[string equal $platform "Windows"]} {
	foreach dir [lsort $conf(WindowsSpecialDirs)] { lappend list <%$dir%> }
    } else {
	#lappend list <%CommonStartMenu%>
	#lappend list <%KDEDesktop%> <%KDEStartMenu%> <%KDECommonStartMenu%>
	#lappend list <%GnomeDesktop%> <%GnomeStartMenu%>
        #lappend list <%GnomeCommonStartMenu%>
	lappend list <%KDEDesktop%> <%GnomeDesktop%>
	lappend list /usr/bin /usr/local/bin /opt
    }

    foreach filegroup [FileGroups children] {
        lappend list "<%FileGroup [$filegroup name]%>"
    }

    return $list
}

proc ::InstallJammer::CheckForInstallDirLoop { id destination } {
    ## If it's not another file group, we're not gonna' loop.
    if {![regexp {<%FileGroup (.*)%>} $destination -> folder]} { return 1 }

    set list   [list [::InstallJammer::GetFileSource $id]]
    set groups [FileGroups children]
    while {1} {
        set obj [::InstallJammer::FindObjByName $folder $groups]
        if {![string length $obj]} { return 1 }

        lappend list $folder

	## Check the destination dir.  If it's not a file group, we're done.
        set dir [$obj get Destination]
	if {![regexp {<%FileGroup (.*)%>} $dir -> folder]} { return 1 }

        if {[lsearch -exact $list $folder] > -1} { return 0 }
    }

    return 1
}

proc AddComponent { setup args } {
    array set _args {
        -id      ""
        -parent  "root"
    }
    array set _args $args

    set id     $_args(-id)
    set parent $_args(-parent)

    switch -- [$id type] {
        "pane" - "window" {
            set command ::InstallJammer::AddPane
            set result [eval [list $command $setup [$id component]] $args]
        }

        "action" {
            set command ::InstallJammer::AddAction
            set result [eval [list $command $setup [$id component]] $args]
        }

        "actiongroup" {
            set command ::InstallJammer::AddActionGroup
            set result [eval [list $command $setup] $args -edit 0]
        }
    }

    return $result
}

proc ::InstallJammer::AddPane { setup pane args } {
    global widg

    variable ::InstallJammer::panes

    set obj    $panes($pane)
    set pref   $widg($setup)
    set sel    [lindex [$pref selection get] 0]
    set parent [::InstallJammer::Tree::GetPaneParent $pref $sel]

    set title [$obj title]
    if {![string length $title]} { $obj get Title value title }

    set data(-id)     ""
    set data(-index)  end
    set data(-title)  $title
    set data(-parent) $parent
    set data(-addnew) 1
    array set data $args

    set id     $data(-id)
    set index  $data(-index)
    set parent $data(-parent)

    if {[lempty $parent]} {
        ::InstallJammer::Error -message "You cannot add a pane here."
        return
    }

    set image [GetImage appdisplay16]

    set new 0
    if {![string length $id]} {
        set new  1

        if {[string length $sel]} {
            if {![$sel is installtype]} { set index [$pref index $sel] }
        }

        set id   [::InstallJammer::uuid]
        set type pane
        if {[$obj get Toplevel value toplevel] && $toplevel} { set type window }
        InstallComponent ::$id -parent $parent -setup $setup -index $index \
            -component $pane -type $type -title $data(-title)

        if {[lsearch -exact [$panes($pane) installtypes] "Common"] < 0} {
            $id set Active Yes
        }
    }

    $obj initialize $id

    foreach field [$obj textfields] {
        $obj get $field subst subst
        $id set -safe $field \
            [::InstallJammer::GetText $id $field -label 1 -subst 0]
        $id set -safe $field,subst $subst
    }

    $pref insert $index $parent $id -text $data(-title) -image $image \
        -data pane -createcommand [list CreatePaneFrame $id] \
        -fill [expr {$new ? "#0000FF" : "#000000"}]

    if {$new && $data(-addnew)} {
        variable ::InstallJammer::actions

        ## Add all the conditions for this pane.
        foreach list [$obj conditions pane] {
            lassign $list condition args
            set cid  [::InstallJammer::AddCondition $condition -parent $id]
            set cobj [$cid object]

            unset -nocomplain tmp
            array set tmp $args

            if {[info exists tmp(<Title>)]} {
                $cid title $tmp(<Title>)
                unset tmp(<Title>)
            }

            set props [$cobj properties]
            set texts [$cobj textfields]

            foreach [list arg val] [array get tmp] {
                if {[lsearch -exact $props $arg] > -1} {
                    $cid set $arg $val
                } elseif {[lsearch -exact $texts $arg] > -1} {
                    ::InstallJammer::SetVirtualText en $cid [list $arg $val]
                }
            }
        }

        ## Add all the actions for this pane.
        set actionlist [$obj actions]
        if {[lempty $actionlist]} { $pref itemconfigure $id -open 1 }

        foreach list $actionlist {
            incr0 i

            lassign $list action args

            set aobj $actions($action)

            unset -nocomplain tmp
            array set tmp $args

            ## Make a special case for an argument called <InstallMode>
            ## that specifies that this action should only be added
            ## if we're adding to that install mode.
            if {[info exists tmp(<InstallMode>)]} {
                if {$parent ne "$tmp(<InstallMode>)Install"} { continue }
                unset tmp(<InstallMode>)
            }

            ## Make a special case for an argument called <Title>
            ## that specifies the title of the object.
            set title [$aobj title]
            if {[info exists tmp(<Title>)]} {
                set title $tmp(<Title>)
                unset tmp(<Title>)
            }

            set act [::InstallJammer::AddAction $setup $action \
                -parent $id -title $title]

            set props [$aobj properties]
            set texts [$aobj textfields]

            ## Walk through the arguments for this action and setup
            ## any text fields and properties that were passed.
            foreach [list arg val] [array get tmp] {
                if {[lsearch -exact $props $arg] > -1} {
                    $act set $arg $val
                } elseif {[lsearch -exact $texts $arg] > -1} {
                    ::InstallJammer::SetVirtualText en $act [list $arg $val]
                }
            }

            ## Add any conditions for this action.
            foreach list [$obj conditions action$i] {
                lassign $list condition args
                set cid  [::InstallJammer::AddCondition $condition -parent $act]
                set cobj [$cid object]

                unset -nocomplain tmp
                array set tmp $args

                if {[info exists tmp(<Title>)]} {
                    $cid title $tmp(<Title>)
                    unset tmp(<Title>)
                }

                set props [$cobj properties]
                set texts [$cobj textfields]

                foreach [list arg val] $args {
                    if {[lsearch -exact $props $arg] > -1} {
                        $cid set $arg $val
                    } elseif {[lsearch -exact $texts $arg] > -1} {
                        ::InstallJammer::SetVirtualText en $cid [list $arg $val]
                    }
                }
            }
        }
    }

    Modified

    ::InstallJammer::RefreshComponentTitles $id

    return $id
}

proc CreatePaneFrame { id } {
    global widg

    variable ::InstallJammer::panes
    
    set pane  [$id component]
    set setup [$id setup]

    set obj  $panes($pane)
    set pref $widg($setup)

    set frame [$pref getframe $id]

    if {[winfo exists $frame.sw]} { return }

    ScrolledWindow $frame.sw -scrollbar vertical

    set prop [PROPERTIES $frame.sw.p]
    pack $frame.sw -expand 1 -fill both
    $frame.sw setwidget $frame.sw.p

    set f [frame $frame.buttons]
    pack $f -side bottom -anchor se -pady 2

    BUTTON $f.design  -text "Edit Pane Code" -width 18 \
        -command [list ::InstallJammer::EditPaneProc $id]
    pack   $f.design -side left -padx 5

    BUTTON $f.restore  -text "Restore Original Pane" -width 18 \
        -command [list ::InstallJammer::RestorePaneProc $id]
    pack   $f.restore -side left -padx [list 0 20]

    BUTTON $f.preview -text "Preview Pane" -width 18 \
        -command [list ::InstallJammer::PreviewWindow $id]
    pack   $f.preview -side left

    $prop insert end root standard -text "Standard Properties" -open 1
    if {[llength [$obj properties 0]]} {
        $prop insert end root advanced -text "Advanced Properties" -open 0
    }
    $obj addproperties $prop $id

    $prop insert end root text -text "Text Properties"
    $obj addtextfields $prop text $id
}

proc AddProperty { prop index parent id name varName args } {
    upvar #0 $varName var

    array set data {
        -node    "#auto"
        -type    ""
        -data    ""
        -help    ""
        -pretty  ""
        -choices ""
    }
    array set data $args

    set type $data(-type)
    if {[string equal $type "hidden"]} { return }

    set scmd ::InstallJammer::StartEditPropertyNode
    set fcmd ::InstallJammer::FinishEditPropertyNode
    set opts [list -text $data(-pretty) -variable $varName]
    lappend opts -data $data(-data) -helptext $data(-help)
    lappend opts -browseargs [list -style Toolbutton]
    lappend opts -editstartcommand  [list $scmd $prop $id $name $type $varName]
    lappend opts -editfinishcommand [list $fcmd $prop $id $name $type $varName]

    switch -- $data(-type) {
        "text" {
            set title "Edit [::InstallJammer::StringToTitle $name]"
            lappend opts -browsebutton 1
            lappend opts -browsecommand
            lappend opts [list EditTextField $id $name $title $varName 0]
        }

        "code" {
            set title "Edit [::InstallJammer::StringToTitle $name]"
            lappend opts -browsebutton 1
            lappend opts -browsecommand
            lappend opts [list EditTextField $id $name $title $varName 0 \
                                -font "Courier 10"]
        }

        "file" {
            lappend opts -browsebutton 1
            lappend opts -browsecommand [list GetFile $varName]
        }

        "image" {
            lappend opts -browsebutton 1
            lappend opts -browsecommand [list GetImageFile $varName]
        }

        "boolean" - "yesno" {
            if {[info exists var]} {
                if {[string is true $var]} {
                    set var Yes
                } else {
                    set var No
                }
            }
            lappend opts -values [list Yes No] -editable 0
        }

        "nullboolean" {
            lappend opts -values [list "" Yes No] -editable 0
        }

        "editboolean" {
            lappend opts -values [list "" Yes No] -editable 1
        }

        "color" {
            lappend opts -browsebutton 1
            lappend opts -browsecommand [list GetColor %W $varName 1]
        }

        "installedfile" {
            lappend opts -valuescommand [list InstallDirList Windows]
        }

        "windowsicon" {
            lappend opts -browsebutton  1
            lappend opts -browsecommand [list GetIconFile $varName]
            lappend opts -valuescommand [list GetIconList]
        }

        "choice" - "editchoice" {
            lappend opts -values $data(-choices)
            lappend opts -editable [expr {$data(-type) eq "editchoice"}]
        }

        "anchor" {
            set list [list center n ne e se s sw w nw]
            lappend opts -values $list -editable 0
        }

        "buttons" {
            variable ::InstallJammer::theme
            lappend opts -values $theme(Buttons) -editable 0
        }

        "readonly" {
            lappend opts -state disabled
        }

        "action" {
            lappend opts -valuescommand ::InstallJammer::ActionList
        }

        "conditions" {
            lappend opts -editable     0
            lappend opts -browsebutton 1
            lappend opts -browsecommand
            lappend opts [list ::InstallJammer::ConditionsWizard active]
        }

        "pane" - "window" {
            lappend opts -valuescommand
	    lappend opts ::InstallJammer::GetPaneListForActiveComponent
        }

        "filemethod" {
            lappend opts -editable 0
            lappend opts -values $::InstallJammer::PropertyMap(FileUpdateMethod)
        }

        "custom" {
            set command Edit.[$id component].$name

            lappend opts -browsebutton  1
            lappend opts -browsecommand [list $command $id]
        }

        "widget" {
            lappend opts -valuescommand
            lappend opts [list ::InstallJammer::FindWidgetsForID $id]
        }

        "language" {
            lappend opts -editable 0
            lappend opts -valuescommand "::InstallJammer::GetLanguages 1"
        }

        "location" {
            lappend opts -editable 0
            lappend opts -browsebutton  1
            lappend opts -browsecommand [list ::InstallJammer::EditLocation $id]
        }

        "stringmap" {
            set title "Edit [::InstallJammer::StringToTitle $name]"
            lappend opts -browsebutton 1
            lappend opts -browsecommand
            lappend opts [list EditTextField $id $name $title $varName 0]
        }

        "addwidgettype" {
            lappend opts -values $data(-choices)
            lappend opts -editable [expr {$data(-type) eq "editchoice"}]
            lappend opts -modifycommand
            lappend opts [list ::InstallJammer::ConfigureAddWidgetFrame $id]
        }

        "platform" {
            lappend opts -valuescommand "AllPlatforms"
        }
    }

    eval $prop insert $index $parent $data(-node) $opts
}

proc ::InstallJammer::CheckAlias { id alias {showError 1} } {
    variable aliases

    if {$alias eq "all"} {
        if {$showError} {
            ::InstallJammer::Error -message \
                "The word '$alias' is reserved and cannot be used as an alias"
        }
        return 0
    }

    if {[info exists aliases($alias)] && $aliases($alias) ne $id} {
        if {$showError} {
            ::InstallJammer::Error -message \
                "The alias '$alias' is being used by another object"
        }
        return 0
    }

    return 1
}

proc ::InstallJammer::SetActivePropertyNode { path } {
    global conf

    set conf(editprop) $path
    set conf(editnode) [$path edit current]
}

proc ::InstallJammer::FinishEditingActiveNode { w } {
    global conf

    if {![info exists conf(editprop)]} { return }
    if {![winfo exists $conf(editprop)]} { return }
    if {[$conf(editprop) edit active] eq ""} { return }

    if {[string match "$w*" $conf(editprop)]} { return }
    if {[string match "$conf(editprop)*" $w]} { return }

    set window [$conf(editprop) edit editwindow]
    if {$window ne "" && [string match "$window*" $w]} { return }

    $conf(editprop) edit finish
    unset -nocomplain conf(editprop) conf(editnode)
}

proc ::InstallJammer::StartEditPropertyNode { path id property type varName } {

}

proc ::InstallJammer::FinishEditPropertyNode { path id property type varName } {
    global widg

    upvar #0 $varName var

    set updatefiles 0
    if {$id eq "file" || $id eq "multiplefiles"} {
        set updatefiles 1
        set ids [::FileGroupTree::GetSelectedItems]
    } elseif {$id eq "condition"} {
        set id [::InstallJammer::GetActiveCondition]
        if {![::InstallJammer::ObjExists $id]} { return 1 }
        set ids [list $id]
    } else {
        set id [::InstallJammer::GetActiveComponent]
        if {![::InstallJammer::ObjExists $id]} { return 1 }
        set ids [list $id]
    }

    foreach id $ids {
        switch -- $property {
            "Name" {
                if {[$id is filegroup component setuptype]} {
                    ::InstallJammer::RenameComponent $id $var
                }
            }

            "Alias" {
                if {![::InstallJammer::CheckAlias $id $var]} { return 0 }

                if {[$id is pane action actiongroup]} {
                    set alias   [$id alias]
                    set default [::InstallJammer::GetDefaultTitle $id]
                    if {$var eq "" && ($alias eq "" || $alias eq [$id title])} {
                        $id title $default
                    } elseif {[$id title] eq $default} {
                        $id title $var
                    }
                    set tree $widg([$id setup]Tree)
                    $tree itemconfigure $id -text [$id title]
                }
            }

            "Destination" {
                if {[$id is filegroup]
                    && ![::InstallJammer::CheckForInstallDirLoop $id $var]} {
                    ::InstallJammer::MessageBox -message \
                        "Destination creates an infinite loop."
                    after idle [list focus [$path edit entrypath]]
                    return 0
                }
            }
        }
    }

    switch -- $type {
        "installedfile" {
            set var [string trim $var]
        }

        "stringmap" {
            set var [string trim $var]

            if {[catch { llength $var } len] || [expr {$len % 2}]} {
                ::InstallJammer::MessageBox -icon error -message \
                    "Invalid string map.  Must be an even number of values."
                after idle [list focus [$path edit entrypath]]
                return 0
            }
        }

        "version" {
            set ver [::InstallJammer::SubstText $var]
            if {[string length $ver]
                && [scan $ver "%d.%d.%d.%d" major minor patch build] != 4} {
                ::InstallJammer::MessageBox -icon error -message \
                    "Invalid version.  Must be in the format X.X.X.X"
                after idle [list focus [$path edit entrypath]]
                return 0
            }
        }
    }

    if {$updatefiles} {
        if {$var != [$path edit value]} {
            ::FileGroupTree::UpdateSelectedItems $property $var
        }
    } else {
        if {$var != [$path edit value]} { Modified }
        $id set $property $var
    }

    return 1
}

proc ::InstallJammer::EditVersionNode { name } {
    variable ::InstallJammer::active

    lassign [split $active($name) .] \
        active(MajorVersion) active(MinorVersion) \
        active(PatchVersion) active(BuildVersion)

    foreach x [list Major Minor Patch Build] {
        if {![string length $active(${x}Version)]} {
            set active(${x}Version) 0
        }
    }

    return 1
}

proc ::InstallJammer::EditTextFieldNode { path id field varName substVarName } {
    global conf

    set conf(editTextField) [list $id $field]

    set frame [$path edit editpath]
    set entry [$path edit entrypath]
    set check $path.editTextFieldSubst

    $check configure -variable $substVarName
    pack  $check -in $frame -side left -before $entry
    raise $check

    return 1
}

proc ::InstallJammer::FinishEditTextFieldNode { path id field varName
                                                substVarName } {
    upvar #0 $varName var $substVarName subst
    set newtext $var

    if {[catch { $id title }]} {
        set id $::InstallJammer::ActiveComponent
    }

    if {$subst && ![::InstallJammer::CheckVirtualText $newtext]} { return 0 }

    if {$newtext ne [::InstallJammer::GetText $id $field -subst 0]} {
        ::InstallJammer::SetVirtualText en $id [list $field $newtext]
        Modified
    }
    return 1
}
proc ::InstallJammer::FinishExternalEditTextField { id field old new } {
    ::InstallJammer::SetVirtualText en $id $field $new
    ::InstallJammer::UpdateActiveComponent
    Modified
}

proc ::InstallJammer::FinishEditPlatformNode { path id property varName } {
    upvar #0 $varName var

    if {$var != [$path edit value]} { Modified }

    set platform  [$path itemcget $property -data]
    set original  [$id platforms]
    set platforms $original

    if {$var} {
        lappend platforms $platform
    } else {
        set platforms [lremove $platforms $platform]
    }
    set platforms [lsort -unique $platforms]

    if {[llength $platforms] != [llength $original]} {
        $id platforms $platforms
        Modified
    }

    return 1
}

proc ::InstallJammer::FinishEditPlatformPropertyNode { path parent node } {
    set value [$path itemcget $node -value]

    if {![::InstallJammer::CheckVirtualText $value]} { return 0 }

    if {$value != [$path edit value]} { Modified }

    set platform [$path itemcget $parent -data]
    set property [$path itemcget $node -data]

    $platform set $property $value

    return 1
}

proc GetComponentList { {setup ""} {activeOnly 0} } {
    global conf

    set list [list]

    foreach id [::itcl::find objects -isa InstallComponent] {
        if {$setup ne "" && [$id setup] ne $setup} { continue }
        if {$activeOnly && ![$id active]} { continue }
        lappend list $id
    }

    return $list
}

proc GetPaneComponentList { {setup Install} {activeOnly 0} } {
    set list [list]
    foreach id [GetComponentList $setup $activeOnly] {
        if {[$id ispane]} { lappend list $id }
    }

    return $list
}

proc GetPaneList { {setup Install} {activeOnly 0} } {
    set panes [list]
    foreach id [GetPaneComponentList $setup $activeOnly] {
        lappend panes [$id component]
    }
    return [lsort -unique $panes]
}

proc ::InstallJammer::GetPaneListForActiveComponent {} {
    set id [::InstallJammer::GetActiveComponent]
    return [GetPaneComponentList [$id setup]]
}

proc GetImageList { setup {activeOnly 0} } {
    variable ::InstallJammer::ComponentObjectMap

    set images [list]
    foreach id [GetComponentList $setup $activeOnly] {
        if {![info exists ComponentObjectMap($id)]} { continue }
	foreach img [$ComponentObjectMap($id) images] {
	    lappend images $id $img
	}
    }
    return $images
}

proc GetImageData { setups {activeOnly 0} } {
    global conf
    global info

    foreach setup $setups {
        foreach [list id image] [GetImageList $setup $activeOnly] {
            set img  [$id get $image]
            set name [::InstallJammer::SubstText $img]
            set file $name
            if {$file eq ""} { continue }

            if {[file pathtype $file] eq "relative"
                && ![::InstallJammer::HasVirtualText $file]} {
                ## The image file's path is relative.  Look for it
                ## first in our project directory and then in the
                ## InstallJammer Images/ directory.
                if {[file exists [file join $info(ProjectDir) $file]]} {
                    set file [file join $info(ProjectDir) $file]
                } elseif {[file exists [file join $conf(pwd) Images $file]]} {
                    set file [file join $conf(pwd) Images $file]
                }
            }

            set imageArray($id,$image) $img
            if {[file exists $file]} {
                set name [::InstallJammer::Normalize $name unix]
                set files($name) [file normalize $file]
            }
        }
    }

    set data "array set ::images [list [array get imageArray]]\n"
    foreach {name file} [array get files] {
        if {![file exists $file]} { continue }
        set x [list [::base64::encode_file $file]]
	append data "set \"::images($name)\" \[image create photo -data $x]\n"
    }

    return $data
}

proc ShrinkCode { string } {
    set output ""
    foreach line [split [string trim $string] \n] {
	set line [string trim $line]
	## Drop comments.
	if {[string index $line 0] == "#"} { continue }

	## Merge split lines back
	if {[string index $line end] == "\\"} {
	    append output [string replace $line end end " "]
	} else {
	    append output $line\n
	}
    }

    return $output
}

proc ShrinkFile {file} {
    if {[file exists $file]} {
        return [ShrinkCode [read_file $file]]
    }
}

proc ::InstallJammer::Explore { {initdir ""} } {
    global conf
    global preferences

    set explorer ""

    if {$initdir ne "" && ![file exists $initdir]} {
        ::InstallJammer::Error -message \
	    "Directory '$initdir' does not exist"
        return
    }

    if {[info exists preferences(FileExplorer)] 
	&& $preferences(FileExplorer) ne ""} {
	set explorer [list exec $preferences(FileExplorer)]
    } else {
        if {$conf(windows)} {
	    set explorer [list exec [auto_execok explorer.exe]]
            if {$initdir ne ""} {
                set initdir  [file nativename $initdir]
                set explorer [list ::installkit::Windows::shellExecute explore]
	    }
        } elseif {$conf(osx)} {
            set explorer [list exec open]
	} else {
            set explorer [list exec xdg-open]
            if {$initdir eq ""} { set initdir [file normalize ~] }
	}
    }

    if {$explorer eq ""} {
        ::InstallJammer::Error -message \
	    "Could not find a suitable file explorer."
	return
    }

    Status "Launching File Explorer..." 3000

    if {$initdir eq ""} {
	set res [catch { eval $explorer & } error]
    } else {
	set res [catch { eval $explorer [list $initdir] & } error]
    }

    if {$res} {
        ::InstallJammer::MessageBox -message $error
    }
}

proc NextProjectName { project {start 2} } {
    global preferences

    set dirs [list]
    foreach filename $preferences(RecentProjects) {
        lappend dirs [file dirname $filename]
        lappend dirs [file dirname [file dirname $filename]]
    }

    set n [lindex $project end]
    if {![string is integer $n]} {
        set n $start
        set new "$project $n"
    } else {
        set project [lrange $project 0 end-1]
        set new "$project [incr n]"
    }

    while {1} {
        set found 0
        foreach dir [lsort -unique $dirs] {
            if {[file exists [file join $dir $new]]} { set found 1; break }
        }
        if {!$found} { return $new }
        set new "$project [incr n]"
    }
}

proc GetImage { image } {
    return [InstallJammerIcons image $image]
}

proc GetIconList {} {
    return [glob -nocomplain -tails -directory $::conf(winico) *.ico]
}

proc SetIconTheme {} {
    global conf
    global widg

    IconLibrary InstallJammerIcons

    set prefs prefs
    if {[IsWindowsXP]} { set prefs xpprefs }

    set dir  [file join $conf(lib) Icons]
    set file [file join $dir InstallJammer.tkico]

    ## Load the common InstallJammer icons.
    InstallJammerIcons load -file $file -groups [list common crystal $prefs]

    ## Load the Crystal theme icons for InstallJammer.
    set file [file join $dir InstallJammer.crystal.png.tkico]
    InstallJammerIcons load -file $file

    set file [file join $dir InstallJammer.crystal.dialog.png.tkico]
    InstallJammerIcons load -file $file

    set file [file join $dir InstallJammer.crystal.toolbar.png.tkico]
    InstallJammerIcons load -file $file

    ## Create the checked file and folder icons.
    foreach icon [list folder16 filedocument16] {
        InstallJammerIcons add check$icon -create 1
        set image [GetImage check$icon]
        $image copy [GetImage $icon]
        $image copy [GetImage check]
    }
}

proc GetPref {pref} {
    global info
    global preferences

    if {[info exists preferences($pref)]} { return $preferences($pref) }
    if {[info exists info($pref)]} { return $info($pref) }
    return 0
}

proc ValidateSpinBox {w oldString newString} {
    if {![string is integer $newString]} { return 0 }
    return 1
}

proc IsWindows {} {
    if {$::tcl_platform(platform) ne "windows"} { return 0 }
    if {$::tcl_platform(osVersion) > 5.0} { return 0 }
    return 1
}

proc IsWindowsXP {} {
    if {$::tcl_platform(platform) ne "windows"} { return 0 }
    if {$::tcl_platform(osVersion) < 5.1} { return 0 }
    return 1
}

proc ::InstallJammer::SetMenuState {menu state} {
    for {set i 0} {$i < [$menu index end]} {incr i} {
	if {[$menu type $i] == "separator"} { continue }
	$menu entryconfigure $i -state $state
    }
}

proc ::InstallJammer::TopName { name } {
    global widg
    if {![string equal [string index $name 0] "."]} { set name .$name }
    return $widg(InstallJammer)$name
}

proc ::InstallJammer::PaneWindowBody { id prefix } {
    set pane [$id component]

    set proc ::InstallJammer::preview::$prefix.$id
    if {![::InstallJammer::CommandExists $proc]} {
    	set proc ::InstallJammer::preview::$prefix.$pane
    }
    if {![::InstallJammer::CommandExists $proc]} { return }
    return [info body $proc]
}

proc ::InstallJammer::Error { args } {
    global widg
    set args [linsert $args 0 -title "InstallJammer Error" -icon error]
    eval ::InstallJammer::MessageBox $args
}

proc ::InstallJammer::CopyPropertiesValue {} {
    global conf
    set data [$conf(prop) itemcget $conf(node) -value]
    if {$data eq ""} { return }
    clipboard clear
    clipboard append $data
}

proc ::InstallJammer::PastePropertiesValue {} {
    global conf

    set data [clipboard get]

    ## Edit the property
    $conf(prop) edit start $conf(node)

    set values   [$conf(prop) edit values]
    set editable [$conf(prop) edit editable]

    if {[llength $values] && !$editable && [lsearch -exact $values $data] < 0} {
        ## This property has a strict list of values, and our new value
        ## doesn't match anything in the list.
        $conf(prop) edit cancel
    } else {
        ## Get the variable for the node we're editing.
        upvar #0 [$conf(prop) variable $conf(node)] value

        ## Set the new value to the contents of the clipboard.
        set value $data

        ## Finish editing the property.
        $conf(prop) edit finish
    }
}

proc ::InstallJammer::GetSetupTypeNames { platform } {
    set names [list]
    foreach id [SetupTypes children] {
        if {[lsearch -exact [$id platforms] $platform] > -1} {
            lappend names [$id name]
        }
    }
    return $names
}

proc ::InstallJammer::SetMainWindowTitle {} {
    global info
    global conf
    global widg

    if {$conf(cmdline) || $conf(loading)} { return }

    set percent [expr {$conf(building) ? "$conf(buildProgress)% " : ""}]

    set mod [expr {$conf(modified) ? "*" : ""}]

    set title "${percent}InstallJammer - "
    if {![info exists info(Project)] || ![string length $info(Project)]} {
        append title "Multiplatform Installer"
    } else {
        append title "$info(Project) ${mod}($info(ProjectFile))"
    }

    if {$title ne [wm title $widg(InstallJammer)]} {
        wm title $widg(InstallJammer) $title
    }
}

proc ::InstallJammer::FlashMainWindow {} {
    global conf
    global widg

    if {![info exists conf(hwin)]} { return }
    if {[wm state $widg(InstallJammer)] ne "iconic"} { return }

    twapi::flash_window_caption $conf(hwin) -toggle

    after 1000 ::InstallJammer::FlashMainWindow
}

proc ::InstallJammer::BooleanValue { value } {
    return [expr {$value ? "Yes" : "No"}]
}

proc ::InstallJammer::AskYesNo { args } {
    set ans [eval [list ::InstallJammer::MessageBox -type yesno] $args]
    return [string equal $ans "yes"]
}

proc ::InstallJammer::Dialog { args } {
    variable count
    if {![info exists count]} { set count 0 }

    if {![llength $args] || [string index [lindex $args 0] 0] eq "-"} {
        set path .__dialog[incr count]
    } else {
        set path [lindex $args 0]
        set args [lrange $args 1 end]
    }
    set path [::InstallJammer::TopName $path]
    eval [list StandardDialog $path] $args
}

proc ::InstallJammer::StringToTitle { string } {
    if {[regexp {[_-]} $string]} {
        set words [split $string _-]
    } else {
        regsub -all {[A-Z]} $string { \0} words
    }

    foreach word $words {
        lappend list [string toupper $word 0]
    }

    return [join $list " "]
}

proc ::InstallJammer::SaveActiveComponent {} {
    variable ::InstallJammer::active
    variable ::InstallJammer::Properties

    if {[info exists ::InstallJammer::ActiveComponent]} {
        ## Store the previous active component's values
        ## into the Properties array.
        set old $::InstallJammer::ActiveComponent
        if {![catch { $old object } obj]} {
            foreach prop [$obj properties] {
                if {$prop eq "ID" || $prop eq "Component"} { continue }
                set Properties($old,$prop) $active($prop)
            }

            foreach prop [$obj textfields] {
                set Properties($old,$prop,subst) $active($prop,subst)
            }
        }
    }
}

proc ::InstallJammer::UpdateActiveComponent {} {
    variable ::InstallJammer::active
    variable ::InstallJammer::Properties

    set id [::InstallJammer::GetActiveComponent]
    if {[catch { $id object } obj]} { return }

    foreach var [array names active] {
        set active($var) ""
    }

    foreach prop [$obj properties] {
        set active($prop) $Properties($id,$prop)
    }

    foreach prop [$obj textfields] {
        set active($prop) [::InstallJammer::GetText $id $prop -subst 0 -label 1]
        set active($prop,subst) $Properties($id,$prop,subst)
    }

    set active(ID)        $id
    set active(Component) [[$id object] title]

    ::InstallJammer::SetActiveComponentConditions
}

proc ::InstallJammer::SetActiveComponent { {id ""} } {
    variable ::InstallJammer::active

    ::InstallJammer::SaveActiveComponent

    if {$id eq ""} {
        set active(ID)        ""
        set active(Component) ""
        unset -nocomplain ::InstallJammer::ActiveComponent
        return
    }

    if {![::InstallJammer::ObjExists $id]} { return }

    set ::InstallJammer::ActiveComponent $id
    
    ::InstallJammer::UpdateActiveComponent

    switch -- [$id type] {
        "filegroup" {
            ::InstallJammer::SetHelp GroupsAndFiles
            set ::InstallJammer::ActiveComponents(filegroup) $id
        }

        "file" - "dir" {
            ::InstallJammer::SetHelp FilesAndDirectories
            set ::InstallJammer::ActiveComponents(filegroup) $id
        }

        "component" - "setuptype" {
            set ::InstallJammer::ActiveComponents([$id type]) $id
        }

        "action" {
            ::InstallJammer::SetHelp [$id component]
            set ::InstallJammer::ActiveComponents([$id setup]) $id
        }

        "actiongroup" {
            ::InstallJammer::SetHelp WhatAreActionGroups
            set ::InstallJammer::ActiveComponents([$id setup]) $id
        }

        "pane" {
            ::InstallJammer::SetHelp WhatArePanes
            set ::InstallJammer::ActiveComponents([$id setup]) $id
        }

        default {
            ::InstallJammer::SetHelp TheUserInterfaceTree
            set ::InstallJammer::ActiveComponents([$id setup]) $id
        }
    }
}

proc ::InstallJammer::GetActiveComponent {} {
    if {[info exists ::InstallJammer::ActiveComponent]} {
        return $::InstallJammer::ActiveComponent
    }
}

proc ::InstallJammer::SetActiveProperty {prop value} {
    set ::InstallJammer::active($prop) $value
}

proc ::InstallJammer::RenameComponent { id name } {
    global widg

    set node $id

    switch -- [$id type] {
        "filegroup" {
            set node [::InstallJammer::NodeName $id]
            ::InstallJammer::Tree::DoRename $widg(FileGroupTree) $node $name
        }

        "component" {
            ::InstallJammer::Tree::DoRename $widg(ComponentTree) $node $name
        }

        "setuptype" {
            ::InstallJammer::Tree::DoRename $widg(SetupTypeTree) $node $name
        }

        default {
            $id title $name
        }
    }
}

proc ::InstallJammer::FontConfigure { font args } {
    set command configure
    if {[lsearch -exact [font names] $font] < 0} { set command create }
    eval [list font $command $font] $args
}

proc ::InstallJammer::IsVirtualTextValid { str } {
    return [expr {[regsub -all {<%} $str {} x] == [regsub -all {%>} $str {} x]}]
}

proc ::InstallJammer::CheckVirtualText { string } {
    if {![::InstallJammer::IsVirtualTextValid $string]} {
        ::InstallJammer::Error -message "Virtual text is invalid."
        return 0
    }
    return 1
}

proc ::InstallJammer::FindWidgetsForID { id } {
    set widgets [list]
    switch -- [$id type] {
        "pane" {
            set widgets [::InstallJammer::GetPaneWidgets $id]
        }

        "action" {
            set parent [$id parent]
            if {![$parent is actiongroup]} {
                set widgets [::InstallJammer::GetPaneWidgets $parent]
            }
        }
    }

    set return [list]
    foreach widget $widgets {
        if {[::InstallJammer::ObjExists $widget]} {
            lappend return $widget
        } else {
            lappend return [::InstallJammer::StringToTitle $widget]
        }
    }

    return [lsort $return]
}

proc ::InstallJammer::GetPaneWidgets { id } {
    variable ::InstallJammer::theme
    variable ::InstallJammer::panes

    if {[catch { $id object } obj]} { return }

    set widgets [list]

    foreach line $theme(Buttons) {
        foreach button [split $line /] {
            lappend widgets ${button}Button
        }
    }

    set files [list [$obj tclfile]]

    foreach include [$obj includes] {
        if {[info exists panes($include)]} {
            lappend files [$panes($include) tclfile]
        }
    }

    foreach file $files {
        set x [read_file $file]
        foreach {x widget} [regexp -all -inline -- { widget set ([^ ]+)} $x] {
            lappend widgets $widget
        }
    }

    foreach child [$id children recursive] {
        if {[$child is action] && [$child component] eq "AddWidget"} {
            lappend widgets $child
        }
    }

    return [lsort -unique $widgets]
}

proc ::InstallJammer::Platform {} {
    global tcl_platform

    if {[string equal $tcl_platform(platform) "windows"]} { return Windows }

    set os      $tcl_platform(os)
    set machine $tcl_platform(machine)
    set version $tcl_platform(osVersion)

    switch -glob -- $machine {
	"intel" - "*86" {
            set machine "x86"
        }

	"Power*" {
            set machine "ppc"
        }

	"sun*" {
            set machine "sparc"
        }
    }

    switch -- $os {
	"AIX" {
	    return $os-ppc
	}

        "Darwin" {
            return MacOS-X
        }

        "IRIX" - "IRIX64" {
            return IRIX-mips
        }

        "SunOS" {
	    return Solaris-$machine
	}

	"HP-UX" {
	    return HPUX-hppa
	}

        "FreeBSD" {
    	    set ver [lindex [split $version -] 0]
	    if {[lempty $ver]} { set ver $version }
	    set major [lindex [split $ver .] 0]
	    return $os-$major-$machine
	}

        default {
            return $os-$machine
        }
    }
}

proc ::InstallJammer::FadeWindowIn { window } {
    global conf

    if {$conf(unix)} {
        wm deiconify $window
        return
    }

    wm attributes $window -alpha 0.1
    wm deiconify $window

    for {set i 0} {$i < 1.0} {iincr i 0.03} {
        wm attributes $window -alpha $i
        after 10
        update idletasks
    }

    wm attributes $window -alpha 0.99999
}

proc ::InstallJammer::FadeWindowOut { window {destroy 0} } {
    global conf

    if {$conf(unix)} {
        if {$destroy} {
            destroy $window
        } else {
            wm withdraw $window
        }
        return
    }

    for {set i [wm attrib $window -alpha]} {$i >= .01} {iincr i -0.03} {
        wm attribute $window -alpha $i
        after 10
        update idletasks
    }

    if {$destroy} {
        destroy $window
    } else {
        wm withdraw   $window
        wm attributes $window -alpha 0.99999
    }
}

proc ::InstallJammer::LoadMessages { args } {
    global conf

    array set _args {
        -dir   ""
        -clear 0
    }
    array set _args $args

    if {![string length $_args(-dir)]} {
        set _args(-dir)   [file join $conf(lib) msgs]
        set _args(-clear) 1
    }
    
    set list [list]
    foreach id [itcl::find object -isa ::InstallJammer::ComponentDetails] {
        lappend list [$id name]
    }
    set list [lsort -unique $list]

    foreach file [recursive_glob $_args(-dir) *.msg] {
        set lang [file root [file tail $file]]

        upvar #0 ::InstallJammer::Msgs_$lang messages

        if {$_args(-clear)} {
            ::msgcat::mcclear $lang
            unset -nocomplain messages
        }

        set data [read_textfile $file]

        unset -nocomplain first
        foreach line [split $data \n] {
            set line [string trim $line]
            if {$line eq ""} { continue }
            if {![info exists first]} { set first $line; continue }
            set second $line
            break
        }

        if {![string match {"*"} $second] && ![string match "*\{" $first]} {
            continue
        }
        if {[catch {array set msg $data}]} { continue }
        foreach text [array names msg] {
            if {[lsearch -exact $list $text] > -1} {
                ## This is an action or something, so it has
                ## multiple text definitions.
                foreach {name value} $msg($text) {
                    set messages($text,$name) $value
                    ::msgcat::mcset $lang $text,$name $value
                }
            } else {
                set messages($text) $msg($text)
                ::msgcat::mcset $lang $text $msg($text)
            }
        }

        unset msg
    }
}

proc ::InstallJammer::ArchiveExists { archive } {
    global conf
    return [expr [lsearch -exact $conf(Archives) $archive] > -1]
}

proc ::InstallJammer::GetActiveLanguages {} {
    global info

    variable ::InstallJammer::languages
    variable ::InstallJammer::languagecodes

    set langs [list]

    foreach code [::InstallJammer::GetLanguageCodes] {
        if {$info(Language,$code)} {
            lappend langs $code $languagecodes($code)
        }
    }

    if {[lsearch -exact $langs "English"] < 0} {
    	lappend langs en English
    }

    return $langs
}

proc ::InstallJammer::DumpObject { obj } {
    variable ::InstallJammer::Properties

    ## List = type properties options textproperties children
    set list {}

    lappend list [$obj type]

    $obj properties props
    lappend list [array get props]

    array set opts [$obj serialize]
    foreach opt {-setup -parent -command -conditions} {
        unset -nocomplain opts($opt)
    }

    lappend list [array get opts]

    set textprops {}
    foreach prop [[$obj object] textfields] {
        foreach lang [::InstallJammer::GetLanguageCodes] {
            lappend textprops $prop
            lappend textprops $lang
            lappend textprops [::InstallJammer::GetText $obj $prop -subst 0 \
                -language $lang -forcelang 1]
            lappend textprops [$obj get $prop,subst]
        }
    }

    lappend list $textprops

    set childlist {}
    if {![catch { $obj conditions } conditions]} {
        foreach condition $conditions {
            lappend childlist [::InstallJammer::DumpObject $condition]
        }
    }

    if {![catch { $obj children } children]} {
        foreach child $children {
            lappend childlist [::InstallJammer::DumpObject $child]
        }
    }

    lappend list $childlist

    return $list
}

proc ::InstallJammer::CreateComponentFromDump { setup list {parent ""} } {
    lassign $list type props opts textprops children

    array set _opts $opts

    set component $_opts(-component)

    set args [list]

    if {$parent ne ""} {
        lappend args -parent $parent
    }

    if {[info exists _opts(-title)]} {
        lappend args -title $_opts(-title)
    }

    switch -- $type {
        "pane" - "window" {
            set id [::InstallJammer::AddPane $setup $_opts(-component) \
                -addnew 0 -title $_opts(-title)]
        }

        "action" {
            set id [eval ::InstallJammer::AddAction $setup $component $args]
        }

        "actiongroup" {
            set id [eval ::InstallJammer::AddActionGroup $setup $args -edit 0]
        }

        "condition" {
            set id [eval ::InstallJammer::AddCondition $component $args]
        }
    }

    if {$id ne ""} {
        eval $id configure $opts

        $id set $props

        foreach {prop lang text subst} $textprops {
            ::InstallJammer::SetVirtualText $lang $id $prop $text
            $id set $prop,subst $subst
        }

        foreach childlist $children {
            ::InstallJammer::CreateComponentFromDump $setup $childlist $id
        }
    }
}

proc ::InstallJammer::OutputDir { {file ""} } {
    global conf

    if {[info exists conf(OutputDir)]} {
        set output $conf(OutputDir)
    } else {
    	set output [InstallDir output]
    }

    if {$file ne ""} { set output [file join $output $file] }
    return $output
}

proc ::InstallJammer::BuildDir { {file ""} } {
    global conf

    if {[info exists conf(BuildDir)]} {
        set build $conf(BuildDir)
    } else {
    	set build [InstallDir build]
    }

    if {$file ne ""} { set build [file join $build $file] }
    return $build
}

proc ::InstallJammer::LibDir { {file ""} } {
    global conf
    set return $conf(lib)
    if {$file ne ""} { set return [file join $return $file] }
    return $return
}

proc ::InstallJammer::GetBuildLogFile {} {
    global conf
    if {![info exists conf(buildLogFile)]} {
        set conf(buildLogFile) [InstallDir build.log]
    }
    return $conf(buildLogFile)
}

proc ::InstallJammer::GetDefaultTitle { id } {
    return [[$id object] title]
}

proc ::InstallJammer::OpenTempFile { {varName ""} {mode "w"} } {
    if {$varName ne ""} { upvar 1 $varName file }
    set file [::InstallJammer::TmpDir [pid][clock clicks].tmp]
    return [open $file $mode]
}

proc ::InstallJammer::WatchExternalFile { pid file command n } {
    if {$::conf(watch,$file) ne [file mtime $file]} {
        set ::conf(watch,$file) [file mtime $file]
        set data [read_file $file]
        if {[string index $data end] eq "\n"} {
            set data [string range $data 0 end-1]
        }
        uplevel #0 $command [list $::conf(watch,$file,text) $data]
        set n 10
    }

    ## Every 3 seconds, check to see if the editor process is still
    ## active.  If it's not, do cleanup and stop.
    if {[incr n] >= 10} {
        if {[::InstallAPI::FindProcesses -pid $pid] eq ""} {
            unset -nocomplain ::conf(watch,$file) ::conf(watch,$file,text)
            file delete -force $file
            return
        }
        set n 0
    }
    after 300 [lreplace [info level 0] end end $n]
}

proc ::InstallJammer::LaunchExternalEditor { value command } {
    global conf

    set fp [::InstallJammer::OpenTempFile file]
    puts $fp $value
    close $fp

    set editor [GetPref Editor]
    if {[string match "*%filename%*" $editor]} {
        set editor [string map [list "%filename%" $file] $editor]
    } else {
        lappend editor $file
    }
    set pid [eval exec $editor &]
    set conf(watch,$file) [file mtime $file]
    set conf(watch,$file,text) $value
    ::InstallJammer::WatchExternalFile $pid $file $command 0
}

proc ::InstallJammer::FindFile {file args} {
    if {$file eq ""} { return }
    if {[file pathtype $file] eq "absolute"} { return $file }

    set dirs [linsert $args 0 [InstallDir]]
    foreach dir $dirs {
        set path [file join $dir $file]
        if {[file exists $path]} { return $path }
    }

    return $file
}

proc ::InstallJammer::GetWindowGeometry {window default} {
    global preferences
    variable WindowGeometry

    set geometry $default
    if {[info exists preferences(Geometry,$window)]} {
        set geometry $preferences(Geometry,$window)
        lassign [split $geometry x+] w h x y
        lassign [wm maxsize .] maxW maxH

        ## If this is the first time to display this window, and it's
        ## outside of the viewing area, readjust to use the default geometry.
        if {![info exists WindowGeometry($window)]
            && ($x < 0 || ($x + $w) > $maxW || $y < 0 || ($y + $h) > $maxH)} {
            set geometry $default
        }
    }

    set WindowGeometry($window) $geometry
    return $geometry
}

proc ::InstallJammer::SendReadySignal {} {
    global conf

    if {![info exists conf(commandSocks)]} { return }

    update
    foreach sock $conf(commandSocks) {
        puts  $sock "OK"
        flush $sock
    }
}

proc ::InstallJammer::AcceptCommandConnection {sock ip port} {
    global conf

    lappend conf(commandSocks) $sock
    fconfigure $sock -blocking 0 -buffering line -buffersize 1000000
    fileevent  $sock readable [list ::InstallJammer::ReadCommandPort $sock]
}

proc ::InstallJammer::ReadCommandPort {sock} {
    global conf

    set data [read $sock]

    if {$data eq ""} {
        catch {close $sock}
        set conf(commandSocks) [lremove $conf(commandSocks) $sock]
    } else {
        catch {uplevel #0 $data} result
        puts  $sock $result
        puts  $sock "OK"
        flush $sock
    }
}
