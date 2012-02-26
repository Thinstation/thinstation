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

proc Open { {filename ""} } {
    global conf
    global info
    global widg

    variable ::InstallJammer::Properties

    if {$conf(loading)} { return }

    if {$filename eq ""} {
	set types {
	    {"InstallJammer Project Files"  .mpi}
	    {"All Files"                    *}
	}

	set filename [mpi_getOpenFile -filetypes $types]

        if {$filename eq ""} { return }

	update
    }

    if {![file exists $filename]} {
        return -code error "invalid file '$filename' specified"
    }

    if {!$conf(cmdline)} {
        set ext [file extension $filename]
        switch -- $ext {
            ".action" {
                ::InstallJammer::InstallNewActionFile $filename
                return
            }

            ".condition" {
                ::InstallJammer::InstallNewConditionFile $filename
                return
            }
        }
    }

    set conf(loading) 1

    if {![Close]} {
        set conf(loading) 0
        return
    }

    ## Set the project defaults.  Any variables that already exists
    ## in the info array will not be overwritten.
    Status "Setting project defaults..."
    ::InstallJammer::SetProjectDefaults 1

    Status "Opening project file..."

    ::InstallJammer::InitializeObjects

    set modified 0

    if {[info commands ::_fileClass] eq ""} {
        rename ::File ::_fileClass
        proc File { args } { lappend ::filesLoaded $args }
    }
    set ::filesLoaded {}

    if {[catch { eval [read_file $filename -encoding utf-8] } error]} {
        if {[vercmp $info(ProjectVersion) $conf(InstallJammerVersion)] == 1} {
            ::InstallJammer::Error -message "This project file was made with\
                a newer version ($info(ProjectVersion)) of InstallJammer and\
                cannot be loaded in this version."
        } else {
            ::InstallJammer::Error -message "Could not open '$filename': $error"
        }
        set conf(loading) 0
        ClearStatus
        return
    }

    set info(Project)     [file root [file tail $filename]]
    set info(ProjectDir)  [file dirname $filename]
    set info(ProjectFile) [file normalize $filename]

    ::InstallJammer::StatusPrefix "Loading $info(Project)...  "

    rename ::File ""
    rename ::_fileClass ::File

    Status "Loading files..."
    foreach file $::filesLoaded {
        eval ::File $file
    }
    unset -nocomplain ::filesLoaded

    ## Rebuild the file map before project conversion.
    Status "Rebuilding file map..."
    ::InstallJammer::RebuildFileMap

    ## Rebuild a list of aliases.
    Status "Rebuilding aliases..."
    ::InstallJammer::RebuildAliases

    ## Convert the project from lower version numbers.
    ## This only occurs if there are format changes in the projects
    ## between versions.
    incr modified [ConvertProject]

    if {$conf(cmdline) && $modified} {
        ::InstallJammer::Message -message "\nThis project must be converted\
            to the new version of\nInstallJammer before it can be built\
            from the command-line.\nPlease load the project in the\
	    InstallJammer builder\nand save the project after it has been\
	    converted.\n"
        ::exit 1
    }

    ## Check the theme for this install and see if it has been updated.
    ConvertTheme

    set conf(ActiveProject) $info(Project)

    if {!$conf(cmdline)} {
        Status "Initializing Trees..."

        AddToRecentProjects $filename

        InitComponentTrees
    }

    Status "Loading [::InstallJammer::StringToTitle $info(Theme)] Theme..."
    if {![LoadTheme $info(ProjectDir)]} {
	Close 1
        set conf(loading) 0
        ClearStatus
	return
    }

    ::InstallJammer::LoadVirtualText

    ::InstallJammer::LoadCommandLineOptions

    if {!$conf(cmdline)} {
        Status "Adding Files to tree..."

        ## Add files and directories that are a direct descendent
        ## of a file group to the tree.  The rest will be created
        ## as the user opens tree nodes.
        foreach filegroup [FileGroups children] {
            ::FileGroupTree::New -id $filegroup
            foreach file [$filegroup children] {
                AddToFileGroup -id $file
            }

            ::FileGroupTree::SortNodes [::InstallJammer::NodeName $filegroup]
        }
    }

    ## Now that everything is all in place, rebuild the file map
    ## again, just incase anything changed in the conversion process.
    if {$modified} {
        Status "Rebuilding file map after conversion..."
        ::InstallJammer::RebuildFileMap
    }

    Status "Adding Components..."
    ::InstallJammer::LoadInstallComponents

    Status "Initializing conditions..."
    ::InstallJammer::LoadInstallConditions

    if {!$conf(cmdline)} {
        Status "Loading Project Preferences..."
        ::InstallJammer::LoadProjectPreferences

        ::InstallJammer::Tree::FinishOpenProject

        tag configure project -state normal
    }

    ## Look for any platforms that didn't previously exist
    ## in our project file and build a list of them.  Set
    ## new platforms to inactive by default.

    Status "Initializing platforms..."
    set newplatforms [list]
    foreach platform [AllPlatforms] {
        if {[$platform get Active] eq "NEW"} {
            $platform set Active "No"
            lappend newplatforms $platform
        }
    }

    ## If we're not building from the command-line we want
    ## to add any new platforms to all of our File Groups,
    ## Components and Setup Types.
    ##
    ## This doesn't make these platforms active, but it does
    ## mean that if they are set to active, all of the install
    ## components will include the new platform by default.

    if {!$conf(cmdline) && [llength $newplatforms]} {
        foreach class {FileGroup Component SetupType} {
            foreach obj [itcl::find objects -class $class] {
                $obj platforms [concat [$obj platforms] $newplatforms]
            }
        }
    }

    set conf(loading)       0
    set conf(projectLoaded) 1

    ::InstallJammer::FilesModified 0

    if {!$conf(cmdline)} {
        Modified $modified

        BuildInstall
        update

        if {$modified} {
            Save
            ::InstallJammer::MessageBox -message "Your project has been\
                automatically converted to a new version.\nA backup of your\
                previous project file has been saved in the project directory."
        }

        Status "$info(Project) loaded" 3000
        ::InstallJammer::StatusPrefix
    } else {
        set platforms [concat [AllPlatforms] $conf(Archives)]
        foreach pf $platforms { set conf(build,$pf) 1 }

        if {[info exists conf(platformBuildList)]} {
            foreach pf $platforms { set conf(build,$pf) 0 }
            foreach pf $conf(platformBuildList) {
                if {$pf eq "tar"} { set pf "TarArchive" }
                if {$pf eq "zip"} { set pf "ZipArchive" }
                set conf(build,$pf) 1
            }
        }

        set buildPlatforms {}
        foreach pf $platforms {
            if {$conf(build,$pf)} {
                $pf properties props
                lappend buildPlatforms $pf
            }
        }

        if {[info exists conf(CommandLineOptions)]} {
            set platformVars [array names props]

            foreach {var val} $conf(CommandLineOptions) {
                if {[lsearch -exact $platformVars $var] < 0} {
                    set info($var) $val
                } else {
                    foreach pf $buildPlatforms {
                        $pf set $var $val
                    }
                }
            }
        }

        if {[info exists conf(CommandLineOptionFiles)]} {
            foreach optfile $conf(CommandLineOptionFiles) {
                uplevel #0 source [list $optfile]
            }
        }
    }

    lassign [split $info(InstallVersion) .] a b c d
    SafeArraySet info \
        [list MajorVersion $a MinorVersion $b PatchVersion $c BuildVersion $d]
    set    info(InstallVersion) "$info(MajorVersion).$info(MinorVersion)"
    append info(InstallVersion) ".$info(PatchVersion).$info(BuildVersion)"
    return
}

proc Save {} {
    global conf
    global info
    global widg

    if {!$conf(projectLoaded)} {
	::InstallJammer::Message -message "No project loaded!"
	return
    }

    if {![info exists info(ProjectFile)]
        || ![string length $info(ProjectFile)]} {
    	SaveAs
	return
    }

    if {[file exists $info(ProjectFile)]
        && ![file writable $info(ProjectFile)]} {
        set ans [::InstallJammer::MessageBox -type yesno -message \
            "Your project file cannot be written because it is read-only.\nDo\
            you want to make the file writable and save anyway?"]
        if {$ans eq "no"} { return }
        if {[catch {
            if {$conf(windows)} {
                file attributes $info(ProjectFile) -readonly 0
            } else {
                file attributes $info(ProjectFile) -permissions u+w
            }
        } error]} {
            ::InstallJammer::MessageBox -message "Failed to make your project\
                file writable.  Your project could not be saved."
            return
        }
    }

    ::InstallJammer::StatusPrefix "Saving $info(Project)...  "

    set info(ProjectVersion) $conf(InstallJammerVersion)

    ::InstallJammer::SaveActiveComponent

    set dir [file dirname $info(ProjectFile)]
    if {![file exists $dir]} { file mkdir $dir }

    ## Store a copy of all of the properties before we start
    ## saving because some of the save procedures might
    ## manipulate the properties.
    variable  ::InstallJammer::SaveProperties
    array set SaveProperties [array get ::InstallJammer::Properties]

    set    data ""

    Status "Storing project info..."
    append data [::InstallJammer::SaveInfoArray]\n

    append data [::InstallJammer::GetCommandLineOptionData -setup Install]\n
    append data [::InstallJammer::GetCommandLineOptionData -setup Uninstall]\n

    Status "Saving file groups..."
    append data [::InstallJammer::SaveFileGroupsAndComponents]\n

    Status "Saving interface components..."
    append data [::InstallJammer::SaveInstallComponents]\n

    Status "Saving properties..."
    append data [::InstallJammer::SaveProperties]\n

    Status "Saving text properties..."
    append data [::InstallJammer::GetTextData]\n

    set fp [open $info(ProjectFile) w]
    fconfigure $fp -translation lf -encoding utf-8
    puts -nonewline $fp $data
    close $fp

    Status "Saving project preferences..."
    ::InstallJammer::SaveProjectPreferences

    AddToRecentProjects $info(ProjectFile)

    ::InstallJammer::SetLastSaved

    Status "Done saving." 3000
    ::InstallJammer::StatusPrefix

    Modified 0
}

proc SaveAs {} {
    global info
    set file [mpi_getSaveFile]
    if {[lempty $file]} { return }
    set info(ProjectFile) [file normalize $file]
    Save
}

proc Close { {force 0} {message ""} } {
    global conf
    global info
    global widg

    if {!$conf(projectLoaded)} { return 1 }

    if {$conf(building)} {
        ::InstallJammer::MessageBox -icon error -title "Build in progress" \
            -message "A build is in progress.  You cannot close this project."
	return 0
    }

    if {!$force && $conf(modified)} {
    	if {$message eq ""} {
	    set message "Project has been modified.  Do you wish to save?"
	}

        set ans [::InstallJammer::MessageBox -type yesnocancel \
            -title "Project Modified" -message $message]
	if {$ans eq "yes"} { Save }
	if {$ans eq "cancel"} { return 0 }
    }

    if {$conf(exiting)} { return 1 }

    Status "Closing $info(Project)..."

    if {!$conf(loading)} {
        $widg(Main) tab $widg(InstallDesignerTab) -state disabled
    }

    ClearComponentTrees

    ::InstallJammer::ClearInstallComponents

    ::InstallJammer::CleanupObjects

    set vars {
        ::info
        ::InstallJammer::aliases
        ::InstallJammer::aliasmap
        ::InstallJammer::FileMap
        ::InstallJammer::Properties
        ::InstallJammer::ActiveComponent
        ::InstallJammer::ActiveComponents
    }

    foreach var $vars {
	unset -nocomplain $var
    }

    set conf(building)      0
    set conf(ActiveProject) ""

    UpdateRecentProjects

    ::InstallJammer::LoadMessages

    ::InstallJammer::ClearBuildLog

    ::InstallJammer::preview::Cleanup

    ::InstallJammer::SetActiveComponent

    unset -nocomplain ::InstallJammer::NewFiles

    if {[info exists widg(BuildTree)]} {
        eval [list $widg(BuildTree) delete] [$widg(BuildTree) nodes root]
    }

    ::InstallJammer::ClearVirtualText

    ::InstallJammer::ClearCommandLineOptions

    tag configure project -state disabled

    $widg(Product) reset
    ::InstallJammer::SetHelp <default>

    set conf(projectLoaded) 0

    if {!$conf(loading)} { $widg(Main) select $widg(InstallDesignerTab) }

    unset -nocomplain info

    Modified 0
    ::InstallJammer::FilesModified 0

    ClearStatus

    ::InstallJammer::SetMainWindowTitle

    return 1
}

proc ReadableArrayGet { arrayName {newname ""} {arrayset ""} } {
    upvar 1 $arrayName array

    if {![string length $newname]} { set newname $arrayName }
    if {![string length $arrayset]} { set arrayset "array set $newname" }

    append string "$arrayset \{\n"
    foreach elem [lsort [array names array]] {
	append string "[list $elem]\n"
        if {[catch {array set x "x \{$array($elem)\}"}]} {
            append string "[list $array($elem)]\n\n"
        } else {
            append string "\{$array($elem)\}\n\n"
        }
    }
    append string "\}"
    return $string
}

proc ProcDefinition { proc {tail 1} } {
    if {[lempty [info procs $proc]]} { return }
    set args [list]
    foreach arg [info args $proc] {
	if {[info default $proc $arg def]} {
	    lappend args [list $arg $def]
	} else {
	    lappend args $arg
	}
    }

    set body [info body $proc]

    if {$tail} { set proc [namespace tail $proc] }

    append str "proc $proc \{$args\} \{"
    append str $body
    append str "\}\n"
    return $str
}

proc ::InstallJammer::GetWindowProcData { args } {
    global info
    global conf

    variable ::InstallJammer::panes
    
    array set _args {
        -build          0
        -setups         {}
        -activeonly     0
    }
    array set _args $args

    if {![llength $_args(-setups)]} { set _args(-setups) $conf(ThemeDirs) }

    set data ""

    foreach setup $_args(-setups) {
        foreach pane $conf(PaneList,$setup) {
            uplevel #0 [list source [$panes($pane) tclfile]]
        }

        set panelist [GetPaneComponentList $setup $_args(-activeonly)]

        foreach id $panelist {
            uplevel #0 [list source [::InstallJammer::GetPaneSourceFile $id]]

            set obj [$id object]
            foreach include [$obj includes] {
                if {![info exists panes($include)]} { continue }
                if {[lsearch -exact $panelist $include] < 0} {
                    lappend panelist $include
                }
            }
        }

	set procs [list]
	foreach id $panelist {
            if {[info exists panes($id)]} {
                set pane $id
            } else {
                set pane [$id component]
            }

            set proc1  CreateWindow.$pane
            set proc2  CreateWindow.$id
            set exists [::InstallJammer::CommandExists $proc1]
            set done  0

            if {$exists} {
                set body1 [string trim [info body $proc1]]
            }

            if {[::InstallJammer::CommandExists $proc2]} {
                set body2 [string trim [info body $proc2]]
                if {!$exists || ![string equal $body1 $body2]} {
                    set done 1
                    append data [ProcDefinition $proc2]\n
                }
            }

            if {$exists && !$done && $_args(-build)} {
                ## If we're in build mode and no proc exists for
                ## this component, store the original pane proc.
                append data [ProcDefinition $proc1]\n
            }
	}
    }

    return $data
}

proc ::InstallJammer::GetTextData { args } {
    global info
    global conf

    array set _args {
        -build          0
        -setups         {}
        -activeonly     0
    }
    array set _args $args

    variable ::InstallJammer::panes

    if {![llength $_args(-setups)]} { set _args(-setups) $conf(ThemeDirs) }

    set data ""

    set languages [::InstallJammer::GetLanguageCodes]

    foreach lang $languages {
        upvar #0 ::InstallJammer::Msgs_$lang messages
        upvar 0 msgs_$lang langdata

        if {$_args(-build)} {
            array set langdata [::msgcat::mcgetall $lang]
        } else {
            array set msgs [::msgcat::mcgetall $lang]

            foreach var [array names msgs] {
                ## If we're not building, we only want to save
                ## messages that have changed from their original
                ## default values.
                if {![info exists messages($var)]
                    || $msgs($var) ne $messages($var)} {
                    set langdata($var) $msgs($var)
                }
            }
        }

        unset -nocomplain msgs
    }

    foreach lang $languages {
        if {[info exists msgs_$lang] && [llength [array names msgs_$lang]]} {
            append data \
                [ReadableArrayGet msgs_$lang $lang "::msgcat::mcmset $lang"]\n
        }
    }

    return $data
}

proc ::InstallJammer::SaveInfoArray {} {
    global conf

    set remove {
        Date
        DateFormat
        Platform
        Project
        ProjectDir
        ProjectFile

        MajorVersion
        MinorVersion
        PatchVersion
        BuildVersion
    }

    array set tmp [array get ::info]
    foreach var $remove {
        unset -nocomplain tmp($var)
    }

    return [ReadableArrayGet tmp info]\n
}

proc ::InstallJammer::SaveProperties { args } {
    global conf

    variable ::InstallJammer::PropertyMap

    array set _args {
        -build       0
        -array       "Properties"
        -activeonly  0
        -includecomments 1
    }
    set _args(-setup) $conf(ThemeDirs)
    array set _args $args

    ## FIXME: The properties saved to uninstall data do not
    ## include any changes made for the install.

    ## Use the SaveProperties array instead of the real
    ## Properties array since some properties may have
    ## changed over the course of saving.
    if {[info exists ::InstallJammer::SaveProperties]} {
        upvar #0 ::InstallJammer::SaveProperties Properties
    } else {
        variable ::InstallJammer::Properties
    }

    set build $_args(-build)

    foreach platform [AllPlatforms] {
        array set props [array get Properties $platform,*]
    }

    foreach archive $conf(Archives) {
        array set props [array get Properties $archive,*]
    }

    foreach setup $_args(-setup) {
        foreach id [GetComponentList $setup $_args(-activeonly)] {
            set obj [$id object]
            if {$obj eq ""} { continue }

            foreach prop [$obj properties] {
                ## Skip standard properties that are empty.
                if {($prop eq "Comment" || $prop eq "Data" || $prop eq "Alias")
                    && $Properties($id,$prop) eq ""} { continue }

                set value $Properties($id,$prop)
                if {$build && [info exist PropertyMap($prop)]} {
                    set value [lsearch -exact $PropertyMap($prop) $value]
                }

                if {$build || [$obj default $prop] ne $Properties($id,$prop)} {
                    set props($id,$prop) $value
                }
            }

            foreach field [$obj textfields] {
                set props($id,$field,subst) $Properties($id,$field,subst)
            }

            foreach cid [$id conditions] {
                set condobj [$cid object]

                foreach prop [$condobj properties] {
                    ## Skip standard properties that are empty.
                    if {($prop eq "Comment" || $prop eq "Data"
                        || $prop eq "Alias") && $Properties($cid,$prop) eq ""} {
                        continue
                    }

                    set value $Properties($cid,$prop)
                    if {$build && [info exist PropertyMap($prop)]} {
                        set value [lsearch -exact $PropertyMap($prop) $value]
                    }

                    set default [$condobj default $prop]
                    if {$build || $Properties($cid,$prop) ne $default} {
                        set props($cid,$prop) $value
                    }
                }

                foreach field [$condobj textfields] {
                    set props($cid,$field,subst) $Properties($cid,$field,subst)
                }
            }
        }
    }

    unset -nocomplain ::InstallJammer::SaveProperties

    if {!$_args(-includecomments)} {
        array unset props *,Comment
    }

    return [ReadableArrayGet props $_args(-array)]\n
}

proc ::InstallJammer::SaveBuildInformation { args } {
    set data ""

    ## Store a copy of all of the properties before we start
    ## saving because some of the save procedures might
    ## manipulate the properties.
    variable  ::InstallJammer::SaveProperties
    array set SaveProperties [array get ::InstallJammer::Properties]

    foreach type [list FileGroup Component SetupType] {
        append data "$type ::${type}s\n"
    }
    lappend args -build 1
    append data [eval ::InstallJammer::SaveFileGroupsAndComponents $args]

    return $data
}

proc ::InstallJammer::SavePlatforms { args } {
    global conf

    set data ""

    foreach platform [AllPlatforms] {
        append data "Platform ::$platform [$platform serialize]\n"
    }

    foreach archive $conf(Archives) {
        append data "Platform ::$archive [$archive serialize]\n"
    }

    return $data
}

proc ::InstallJammer::SaveFileGroups { args } {
    variable save

    array set _args {
        -build     0
        -savefiles 1
    }
    array set _args $args

    set data ""

    foreach id [FileGroups children] {
        if {[info exists _args(-platform)]
            && [lsearch -exact [$id platforms] $_args(-platform)] < 0} {
            continue
        }

        if {$_args(-build) && ![$id active]} { continue }

        set save($id) 1

        append data "FileGroup ::$id [$id serialize]\n"
        if {!$_args(-build) && $_args(-savefiles)} {
            append data [::InstallJammer::SaveSetupFiles $id]
        }
    }

    return $data
}

proc ::InstallJammer::SaveSetupFiles { id } {
    global info

    set data ""

    set parent [$id parent]
    if {[$parent is filegroup] && ($info(SaveOnlyToplevelDirs)
        || [string is false -strict [$parent get SaveFiles]])} { return }

    foreach id [$id children] {
        append data "File ::$id [$id serialize]\n"
        if {[$id is dir] && [string is false -strict [$id savefiles]]} {
            continue
        }
        append data [::InstallJammer::SaveSetupFiles $id]
    }

    return $data
}

proc ::InstallJammer::SaveComponents { args } {
    variable save

    variable ::InstallJammer::SaveProperties

    array set _args {
        -build  0
    }

    array set _args $args

    set data ""

    set save(Components) 1
    foreach id [Components children recursive] {
        if {[info exists _args(-platform)]
            && [lsearch -exact [$id platforms] $_args(-platform)] < 0} {
            continue
        }

        if {$_args(-build) && ![$id active]} { continue }

        set parent [$id parent]
        if {$_args(-build) && ![info exists save($parent)]} {
            BuildLog "Removing [$id name] component: parent not included"
            continue
        }

        set save($id) 1

        foreach filegroup [$id get FileGroups] {
            if {![info exists save($filegroup)]} {
                set SaveProperties($id,FileGroups) \
                    [lremove $SaveProperties($id,FileGroups) $filegroup]
                BuildLog "Removing [$filegroup name] file group from\
                    [$id name] component." -logtofile 0
            }
        }

        append data "Component ::$id [$id serialize]\n"
    }

    return $data
}

proc ::InstallJammer::SaveSetupTypes { args } {
    variable save

    variable ::InstallJammer::SaveProperties

    array set _args {
        -build  0
    }

    array set _args $args

    set data ""

    foreach id [SetupTypes children] {
        if {[info exists _args(-platform)]
            && [lsearch -exact [$id platforms] $_args(-platform)] < 0} {
            continue
        }

        if {$_args(-build) && ![$id active]} { continue }

        set save($id) 1

        foreach component [$id get Components] {
            if {![info exists save($component)]} {
                set SaveProperties($id,Components) \
                    [lremove $SaveProperties($id,Components) $component]
                BuildLog "Removing [$component name] component from\
                    [$id name] setup type." -logtofile 0
            }
        }

        append data "SetupType ::$id [$id serialize]\n"
    }

    return $data
}

proc ::InstallJammer::SaveFileGroupsAndComponents { args } {
    variable save

    unset -nocomplain save

    set data ""

    Status "Saving file groups..."
    append data [eval SaveFileGroups $args]

    Status "Saving components..."
    append data [eval SaveComponents $args]

    Status "Saving setup types..."
    append data [eval SaveSetupTypes $args]

    unset -nocomplain save

    return $data
}

proc ::InstallJammer::IgnoreDir {dir} {
    foreach pattern $::info(IgnoreDirectories) {
        if {[regexp -- $pattern $dir]} { return 1 }
    }
    return 0
}

proc ::InstallJammer::IgnoreFile {file} {
    set tail [file tail $file]
    foreach pattern $::info(IgnoreFiles) {
        if {[regexp -- $pattern $tail]} { return 1 }
    }
    return 0
}

proc ::InstallJammer::RecursiveGetFiles { parent {followLinks 1}
                                            {linkParent ""} } {
    global conf
    variable LinkDirs

    set first 0
    if {$linkParent eq ""} {
        set first 1
        set linkParent $parent
        set LinkDirs($linkParent) ""
    }

    set ids [list $parent]
    set dir [::InstallJammer::GetFileSource $parent]

    set files [glob -type f -nocomplain -directory $dir *]
    eval lappend files [glob -type {f hidden} -nocomplain -directory $dir *]

    foreach file [lsort -dict $files] {
        if {[::InstallJammer::IgnoreFile $file]} { continue }
        set id [::InstallJammer::FileObj $parent $file -type file]
        if {[$id active]} { lappend ids $id }
    }

    set dirs [glob -type d -nocomplain -directory $dir *]
    eval lappend dirs [glob -type {d hidden} -nocomplain -directory $dir *]

    foreach dir [lsort -dict $dirs] {
        if {[::InstallJammer::IgnoreDir $dir]} { continue }

        set tail [file tail $dir]
        if {$tail eq "." || $tail eq ".."} { continue }

        if {[file type $dir] eq "link"} {
            if {$followLinks} {
                set link $tail,[file normalize [file readlink $dir]]
                if {[lsearch -exact $LinkDirs($linkParent) $link] > -1} {
                    continue
                }
                lappend LinkDirs($linkParent) $link
            } else {
                set id [::InstallJammer::FileObj $parent $dir -type file]
                if {[$id active]} { lappend ids $id }
                continue
            }
        }

        set id [::InstallJammer::FileObj $parent $dir -type dir]
        if {[$id active]} {
            eval lappend ids [::InstallJammer::RecursiveGetFiles \
                $id $followLinks $linkParent]
        }
    }

    if {$first} { unset -nocomplain LinkDirs }

    return $ids
}

proc ::InstallJammer::RefreshFileGroups {} {
    global conf
    global info
    global widg

    set msg "Refreshing file groups..."

    if {$conf(building)} {
        BuildLog $msg
    } else {
        Status $msg
    }

    set conf(SortTreeNodes) {}

    if {$info(IgnoreFiles) ne $info(LastIgnoreFiles)
        || $info(IgnoreDirectories) ne $info(LastIgnoreDirectories)} {
        set ids {}
        foreach group [FileGroups children] {
            foreach id [$group children recursive] {
                set path [::InstallJammer::GetFileSource $id]

                if {[$id is dir] && [::InstallJammer::IgnoreDir $path]} {
                    lappend ids $id
                    continue
                }

                if {[::InstallJammer::IgnoreFile $path]
                    || [::InstallJammer::IgnoreDir [file dirname $path]]} {
                    lappend ids $id
                }
            }
        }

        if {[llength $ids]} { ::InstallJammer::DeleteFilesFromTree $ids }
    }

    set info(LastIgnoreFiles)       $info(IgnoreFiles)
    set info(LastIgnoreDirectories) $info(IgnoreDirectories)

    foreach group [FileGroups children] {
        foreach id [$group children] {
            if {[$id is dir]} {
                set follow [$group get FollowDirLinks]
                ::InstallJammer::RecursiveGetFiles $id $follow
            }
        }
    }

    if {[info exists widg(FileGroupTree)]} {
	foreach node [lsort -unique $conf(SortTreeNodes)] {
	    ::FileGroupTree::SortNodes $node
	}

	::InstallJammer::RedrawFileTreeNodes
    }

    unset conf(SortTreeNodes)

    ClearStatus
}

proc ::InstallJammer::GetSetupFileList { args } {
    global conf
    global info

    variable save

    array set _args {
        -platform    ""
        -checksave   0
        -includedirs 0
        -listvar     ""
        -errorvar    ""
        -procvar     ""
    }
    array set _args $args

    set append 0
    if {[string length $_args(-listvar)]} {
        set append 1
        upvar 1 $_args(-listvar) filelist
    }

    set doproc 0
    if {[string length $_args(-procvar)]} {
        set doproc 1
        upvar 1 $_args(-procvar) procData
        set procData "proc ::InstallJammer::InitFiles {} \{\n"
    }

    if {$_args(-errorvar) ne ""} {
        upvar 1 $_args(-errorvar) missing
        set missing {}
    }

    set groups [FileGroups children]

    set platform $_args(-platform)

    if {$info(SkipUnusedFileGroups)} {
        set groups     [list]
        set components [Components children recursive]
        if {$platform ne "" && [::InstallJammer::IsRealPlatform $platform]} {
            foreach component $components {
                set platforms [$component platforms]
                if {[lsearch -exact $platforms $_args(-platform)] < 0} {
                    set components [lremove $components $component]
                }
            }
        }

        foreach component $components {
            foreach group [$component get FileGroups] {
                if {[lsearch -exact $groups $group] < 0} {
                    lappend groups $group
                }
            }
        }
    }

    set files {}
    foreach group $groups {
        if {$platform ne ""
            && [lsearch -exact [$group platforms] $platform] < 0} { continue }

        if {![$group active]
            || ($_args(-checksave) && ![info exists save($group)])} { continue }

        set ids {}
        set groupsize 0

        set preserveAttributes 0
        if {$conf(windows) && $platform eq "Windows"
            && $info(PreserveFileAttributes)} { set preserveAttributes 1 }

        set preservePermissions 0
        if {!$conf(windows) && $platform ne "Windows"
            && $info(PreserveFilePermissions)} { set preservePermissions 1 }

        set followDirs  [$group get FollowDirLinks]
        set followFiles [$group get FollowFileLinks]

        set parents($group) 1
        foreach id [$group children recursive] {
            if {![::InstallJammer::GetFileActive $id]} { continue }

            if {![info exists parents([$id parent])]} { continue }

            set file [::InstallJammer::GetFileSource $id]

            if {[catch { file lstat $file s }]} {
                lappend missing $file
                continue
            }
            
            set type $s(type)
            set doappend $append
            if {$type eq "link"} {
                file stat $file s
                set type $s(type)
                if {$platform ne "Windows"} {
                    if {($s(type) eq "file" && !$followFiles)
                        || ($s(type) eq "directory" && !$followDirs)} {
                        set type link
                        set doappend 0
                    }
                }
            }

            if {$type eq "directory"} {
                set parents($id) 1
                if {!$_args(-includedirs)} { set doappend 0 }
            }

            if {$doproc} {
                append procData "    File ::$id"
                append procData " -name [list [$id destfilename]]"
                append procData " -parent [list $group]"

                set alias [$id alias]
                if {$alias ne ""} {
                    append procData " -alias [list $alias]"
                }

                set dir [::InstallJammer::GetFileDestination $id]
                if {$type ne "directory"} { set dir [file dirname $dir] }
                append procData " -directory [list $dir]"

                if {$type eq "link"} {
                    append procData " -type link"
                    append procData " -linktarget [list [file link $file]]"
                } elseif {$type eq "directory"} {
                    append procData " -type dir"
                } else {
                    if {$s(size)} { append procData " -size $s(size)" }
                    append procData " -mtime $s(mtime)"
                }

                set version [::InstallJammer::GetFileVersion $id]
                if {$version ne ""} {
                    append procData " -version $version"
                }

                set attributes [$id attributes]
                if {$attributes eq "" && $preserveAttributes} {
                    array set a [file attributes $file]
                    append attributes $a(-archive) $a(-hidden) \
                        $a(-readonly) $a(-system)
                }

                if {$attributes ne ""} {
                    append procData " -attributes $attributes"
                }

                set permissions [$id permissions]
                if {$permissions eq "" && $preservePermissions} {
                    set permissions [file attributes $file -permissions]
                }

                if {$permissions ne ""} {
                    append procData " -permissions $permissions"
                }

                set method [::InstallJammer::GetFileMethod $id 1]
                if {$method ne ""} {
                    append procData " -filemethod $method"
                }

                append procData "\n"
            }

            if {$doappend} {
                lappend filelist [list $id $file $group $s(size) $s(mtime)]
            }

            incr groupsize $s(size)
        }

        $group set FileSize $groupsize
    }

    if {$doproc} { append procData "\n\}" }

    return
}

proc ::InstallJammer::ClearInstallComponents {} {
    global conf
    global widg

    foreach setup $conf(ThemeDirs) {
        set tree $widg($setup)
        $tree reset
        foreach node [$tree nodes root] {
            $tree close $node
            eval $tree delete [$tree nodes $node]
        }
    }
}

proc ::InstallJammer::ComponentIsActive { id } {
    if {![$id active]} { return 0 }

    set parent [$id parent]
    while {[string length $parent]} {
        if {![$parent active]} { return 0 }
        set parent [$parent parent]
    }
    return 1
}

proc ::InstallJammer::SaveInstallComponents { args } {
    global conf
    global info

    array set _args {
        -setup          ""
        -build          0
        -activeonly     0
        -actiongroupvar ""
    }
    array set _args $args

    if {$_args(-build) && $_args(-actiongroupvar) ne ""} {
        upvar 1 $_args(-actiongroupvar) actionGroupData
        set _args(-actiongroupvar) actionGroupData
        set actionGroupData ""
    }

    set data ""
    foreach type [InstallTypes children] {
        set var       data
        set setup     [$type setup]
        set storetype [string map [list $setup ""] $type]

        if {$_args(-setup) ne "" && $setup ne $_args(-setup)} { continue }

        if {$_args(-build)} {
            if {[info exists actionGroupData]} {
                append actionGroupData "InstallType ::$storetype\n"

                if {[string match "ActionGroups*" $type]} {
                    set var actionGroupData
                }
            } else {
                append data "InstallType ::$storetype\n"
            }
        }

        append $var [eval ::InstallJammer::SaveComponentData \
                -type $type -object $type [array get _args]]
    }

    return $data
}

proc ::InstallJammer::SaveComponentData { args } {
    array set _args {
        -type       ""
        -setup      ""
        -build      0
        -object     ""
        -activeonly 0
    }
    array set _args $args

    set data  ""
    set type  $_args(-type)
    set setup $_args(-setup)

    set storetype [string map [list [$type setup] ""] $type]
    foreach id [$_args(-object) children] {
        if {$_args(-activeonly) && ![ComponentIsActive $id]} { continue }
        if {[string length $setup] && [$id setup] ne $setup} { continue }

        set opts [$id serialize]

        if {$_args(-build) && [[$id parent] isa InstallType]} {
            set x [lsearch -exact $opts "-parent"]
            set opts [lreplace $opts $x [incr x] -parent $storetype]
        }

        append data "InstallComponent $id $opts\n"

        foreach cid [$id conditions] {
            if {$_args(-activeonly) && ![$cid active]} { continue }
            append data "Condition $cid [$cid serialize]\n"
        }

        append data [eval ::InstallJammer:::SaveComponentData $args -object $id]
    }

    return $data
}

proc ::InstallJammer::LoadInstallComponents {} {
    global conf
    global widg

    if {$conf(cmdline)} {
        foreach object [::itcl::find object -isa ::InstallComponent] {
            $object initialize
        }
    } else {
        foreach setup $conf(ThemeDirs) {
            foreach type $conf(InstallTypes) {
                set obj $type$setup
                foreach id [$obj children recursive] {
                    if {[$widg($setup) exists $id]} { continue }

                    AddComponent [$id setup] -id $id \
                        -parent [$id parent] -title [$id title]
                }
            }

            foreach node [$widg($setup) nodes root] {
                if {![llength [$widg($setup) nodes $node]]} {
                    $widg($setup) itemconfigure $node -open 1
                }
            }
        }
    }

    foreach platform [concat [AllPlatforms] $conf(Archives)] {
        $platform active [$platform get Active]
    }

    if {!$conf(cmdline)} {
        ::InstallJammer::RefreshComponentTitles
    }
}

proc ::InstallJammer::LoadInstallConditions {} {
    foreach id [::itcl::find objects -class ::Condition] {
        [$id object] initialize $id
    }
}

proc BuildInstall {} {
    global conf
    global info
    global widg

    if {![info exists info(Project)]} {
    	::InstallJammer::Error -message "No project selected."
	return
    }

    ::InstallJammer::SetMainWindowTitle

    $widg(Main) tab $widg(InstallDesignerTab) -state normal
    pack $widg(Product) -expand 1 -fill both -pady 2

    tag configure project -state normal

    $widg(StopBuildButton) configure -state disabled

    foreach pf [concat [AllPlatforms] $conf(Archives)] {
        ## Add a check box to the build platform tree.
        set text [PlatformText $pf]

        set conf(build,$pf) 1
        $widg(BuildTree) insert end root #auto -type checkbutton \
            -variable ::conf(build,$pf) -text $text
    }

    $widg(Main) select $widg(InstallDesignerTab)
    $widg(Product) raise general
}

proc ::InstallJammer::RebuildFileMap {} {
    global conf

    variable ::InstallJammer::FileMap

    unset -nocomplain FileMap
    set conf(locations) [list]

    ## Walk through all of the children in each file group
    ## and make sure that we've properly setup the file map.
    foreach obj [itcl::find objects -class ::File] {
        set key [::InstallJammer::FileKey [$obj parent] [$obj name]]
        set FileMap($key) [$obj id]

        set location [$obj location]
        if {$location ne ""} { lappend conf(locations) $location }
    }

    set conf(locations) [lsort -unique $conf(locations)]
    return
}

proc ::InstallJammer::RebuildLocations {} {
    global conf

    variable ::InstallJammer::Locations

    set conf(locations) [list]

    foreach id [itcl::find objects -class ::File] {
        set location [$id location]
        if {$location ne ""} { lappend conf(locations) $location }
    }

    foreach id [array names Locations] {
        lappend conf(locations) $Locations($id)
    }

    set conf(locations) [lsort -unique $conf(locations)]

    return
}

proc ::InstallJammer::RebuildAliases {} {
    unset -nocomplain ::InstallJammer::aliases
    unset -nocomplain ::InstallJammer::aliasmap

    foreach object [::itcl::find object -isa ::InstallComponent] {
        set id    [$object id]
        set alias [$object get Alias]
        if {$alias ne ""} {
            set ::InstallJammer::aliases($alias) $id
            set ::InstallJammer::aliasmap($id) $alias
        }
    }
}

proc ::InstallJammer::InitializeObjects {} {
    global conf

    ::InstallJammer::CleanupObjects

    ::TreeObject ::FileGroups
    ::TreeObject ::Components
    ::TreeObject ::SetupTypes
    ::TreeObject ::InstallTypes

    ::TreeObject ::Platforms
    foreach platform [AllPlatforms] {
        ::Platform ::$platform -parent Platforms
    }

    foreach archive $conf(Archives) {
        ::Platform ::$archive
    }

    if {[::InstallJammer::ArchiveExists TarArchive]} {
        ::TarArchive set \
            Active No \
            CompressionLevel 6 \
            DefaultDirectoryPermission 0755 \
            DefaultFilePermission 0755 \
            OutputFileName "<%ShortAppName%>-<%Version%>.tar.gz" \
            VirtualTextMap {<%InstallDir%> <%ShortAppName%>}
    }

    if {[::InstallJammer::ArchiveExists ZipArchive]} {
        ::ZipArchive set \
            Active No \
            CompressionLevel 6 \
            OutputFileName "<%ShortAppName%>-<%Version%>.zip" \
            VirtualTextMap {<%InstallDir%> <%ShortAppName%>}
    }

    foreach setup $conf(ThemeDirs) {
        foreach installtype $conf(InstallTypes) {
            ::InstallType ::${installtype}${setup} \
                -parent InstallTypes -setup $setup
        }
    }
}

proc ::InstallJammer::CleanupObjects {} {
    set objs {Platforms FileGroups Components SetupTypes InstallTypes}
    lappend objs TarArchive ZipArchive

    foreach obj $objs {
        if {[::InstallJammer::ObjExists ::$obj]} { ::$obj destroy }
    }

    eval ::itcl::delete obj [::itcl::find object -class ::InstallJammer::Pane]
}

proc ::InstallJammer::SavePreferences {} {
    global widg
    global preferences

    set dir  [::InstallJammer::InstallJammerHome]
    set file [::InstallJammer::InstallJammerHome preferences]

    if {![file exists $dir]} { file mkdir $dir }
    
    set preferences(Zoomed) [expr {[wm state $widg(InstallJammer)] eq "zoomed"}]

    if {$preferences(Zoomed)} { wm state $widg(InstallJammer) normal }
    set preferences(Geometry) [wm geometry $widg(InstallJammer)]

    set preferences(Geometry,FileGroupPref) \
        [list -pagewidth [$widg(FileGroupPref) cget -pagewidth]]

    foreach widget {Product ComponentPref SetupTypePref Install Uninstall} {
        set preferences(Geometry,$widget) \
            [list -treewidth [$widg($widget) cget -treewidth]]
    }

    set fp [open $file w]
    fconfigure $fp -translation lf
    puts $fp [string trim [lindex [ReadableArrayGet preferences] end]]
    close $fp
}

proc ::InstallJammer::LoadPreferences {} {
    global preferences

    set file [::InstallJammer::InstallJammerHome preferences]

    if {[file exists $file]} {
        if {[catch { array set preferences [read_file $file] } err]} {
            file delete $file
        }
    }
}

proc ::InstallJammer::SaveProjectPreferences {} {
    global info

    variable Locations

    set home [::InstallJammer::InstallJammerHome]

    if {![file exists $home]} { file mkdir $home }

    set file [::InstallJammer::InstallJammerHome $info(ProjectID).pref]

    set pref(Locations) [array get Locations]

    if {[llength $pref(Locations)]} {
        set fp [open $file w]
        fconfigure $fp -translation lf
        puts $fp [string trim [lindex [ReadableArrayGet pref] end]]
        close $fp
    }
}

proc ::InstallJammer::LoadProjectPreferences {} {
    global info

    set file [::InstallJammer::InstallJammerHome $info(ProjectID).pref]

    if {[file exists $file]} {
        array set preferences [read_file $file]

        if {[info exists preferences(Locations)]} {
            variable Locations
            array set Locations $preferences(Locations)
            unset preferences(Locations)
        }
    }
}

proc ::InstallJammer::InstallNewActionFile { file } {
    global conf

    set contents [read_file $file]
    if {![regexp {\nGroup ([^\n]+)\n} $contents -> group]} {
        set group "CustomActions"
    }

    set dir [file join $conf(lib) Actions $group]
    if {![file exists $dir]} { file mkdir $dir }

    set new [file join $dir [file tail $file]]
    if {[file exists $new]} { file rename $new $new.bak }

    file copy -force $file $new
}

proc ::InstallJammer::InstallNewConditionFile { file } {
    global conf

    set contents [read_file $file]
    if {![regexp {\nGroup ([^\n]+)\n} $contents -> group]} {
        set group "CustomConditions"
    }

    set dir [file join $conf(lib) Conditions $group]
    if {![file exists $dir]} { file mkdir $dir }

    set new [file join $dir [file tail $file]]
    if {[file exists $new]} { file rename $new $new.bak }

    file copy -force $file $new
}
