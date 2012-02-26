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

namespace eval ::FileGroupTree {
    variable old   ""
    variable tree  ""
    variable popup ""
}

proc ::FileGroupTree::setup { tree } {
    $tree configure \
        -opencmd  "::FileGroupTree::open  $tree" \
        -closecmd "::FileGroupTree::close $tree" \
        -selectcommand "::FileGroupTree::UpdateSelection"

    $tree bindText  <Button-1>		"::FileGroupTree::select 1"
    $tree bindImage <Button-1>		"::FileGroupTree::select 1"
    $tree bindText  <ButtonRelease-1>   "::FileGroupTree::dorename"
    $tree bindImage <ButtonRelease-1>   "::FileGroupTree::dorename"
    $tree bindText  <Double-Button-1>	"::FileGroupTree::select 2"
    $tree bindImage <Double-Button-1>	"::FileGroupTree::select 2"
    $tree bindText  <Shift-Button-1>	"::FileGroupTree::select 3"
    $tree bindImage <Shift-Button-1>	"::FileGroupTree::select 3"
    $tree bindText  <Control-Button-1>	"::FileGroupTree::select 4"
    $tree bindImage <Control-Button-1>	"::FileGroupTree::select 4"

    $tree bindText  <Button-3>          "::FileGroupTree::popup %X %Y"
    $tree bindImage <Button-3>          "::FileGroupTree::popup %X %Y"

    ::FileTree::Setup $tree
}

proc ::FileGroupTree::init {} {
    global widg

    variable tree $widg(FileGroupTree)
    variable pref $widg(FileGroupPref)

    ::FileGroupTree::Clear
}

proc ::FileGroupTree::Clear {} {
    global widg

    variable pref
    variable done

    if {![string length $pref]} { return }

    $pref selection clear

    eval [list $pref delete] [$pref nodes root]

    unset -nocomplain done
}

proc ::FileGroupTree::New { args } {
    global conf
    global info
    global widg

    variable pref

    array set data {
        -id        ""
        -text      ""
        -directory "<%InstallDir%>"
    }
    array set data $args

    set text $data(-text)
    set dest $data(-directory)

    set id  $data(-id)
    set new 0
    if {![string length $data(-id)]} {
        set id [::InstallJammer::uuid]

        FileGroup ::$id -name $text -parent FileGroups
        set node [::InstallJammer::NodeName $id]

        if {![string length $text]} {
            set new 1
            set text "New File Group"
            ::InstallJammer::EditNewNode $pref end root $node \
                -text $text -image [GetImage filegroup16] \
                -data $id -pagewindow $widg(FileGroupDetails)
            set text [$pref itemcget $node -text]
            $id configure -name $text
            focus [$pref gettree]
        }

        $id platforms [concat [AllPlatforms] $conf(Archives)]
    }

    set text [$id name]
    set node [::InstallJammer::NodeName $id]

    ::FileGroupObject initialize $id Name $text Destination $dest

    if {!$new} {
        $pref insert end root $node \
            -text $text -image [GetImage filegroup16] \
            -data $id -pagewindow $widg(FileGroupDetails)
    } else {
        ::FileGroupTree::select 1 $node
    }

    set tree $widg(ComponentFileGroupTree)
    $tree insert end root $id \
        -type checkbutton -text $text \
        -variable ::ComponentTree::FileGroupIncludes($id) \
        -command [list ::ComponentTree::SetFileGroupInclude $tree $id]

    Modified
    ::InstallJammer::FilesModified

    return $id
}

proc ::FileGroupTree::select { mode node } {
    global conf
    global info
    global widg

    variable old
    variable tree
    variable pref

    after cancel $conf(renameAfterId)

    ## Tree specific configurations.
    set p    [$tree parent $node]
    set id   [$tree itemcget $node -data]
    set text [$tree itemcget $node -text]
    set type [$id type]

    $widg(DeleteButton) configure -state normal

    if {[$id is filegroup]} {
        $widg(AddDirButton)   configure -state normal
        $widg(AddFilesButton) configure -state normal
    } else {
        $widg(AddDirButton)   configure -state disabled
        $widg(AddFilesButton) configure -state disabled
    }

    if {$mode == 1} {
	::FileGroupTree::selection set $node

        ::FileGroupTree::RaiseNode $node
    }

    if {$mode == 2} {
	## It's a double-click.  Open or close the node depending.

        variable double 1
        after idle [list unset -nocomplain [namespace current]::double]

	::FileGroupTree::selection set $node
        ::FileGroupTree::RaiseNode $node

        if {[$id is dir] || [$id is file]} {
            if {[$id active]} {
		Uncheck $node
	    } else {
		Check $node
	    }
	} else {
            $pref toggle $node
	}
    }

    if {$mode == 3} {
	## They executed a shift-click.

        set nodes [::InstallJammer::Tree::AllNodes $tree]

        set idx1 0
        if {[string length $old]} { set idx1 [lsearch -exact $nodes $old] }
        if {$idx1 < 0} { set idx1 0 }

        set idx2 [lsearch -exact $nodes $node]

        if {$idx2 < $idx1} {
            set x $idx1
            set idx1 $idx2
            set idx2 $x
        }

        set items [list]
        foreach n [lrange $nodes $idx1 $idx2] {
            if {[$tree visible $n]} { lappend items $n }
	}

	::FileGroupTree::selection set $items
    }

    if {$mode == 4} {
	## They executed a ctrl-click.
	if {[lsearch -exact [$tree selection get] $node] > -1} {
	    ::FileGroupTree::selection remove $node
	} else {
	    ::FileGroupTree::selection add $node
	}
    }
}

proc ::FileGroupTree::open { tree node } {
    global conf
    global info
    variable LinkDirs

    set id [$tree itemcget $node -data]

    ## Check to see if this node has already been opened.
    if {[$tree itemcget $node -drawcross] eq "auto"} { return }

    set found 0
    foreach child [$id children] {
        set found 1
        AddToFileGroup -id $child
    }

    set dir [::InstallJammer::GetFileSource $id]
    if {[file exists $dir]} {
        set topdir   [::FileGroupTree::GetTopDirectory $node]
        set platform [::FileTree::GetPlatform $tree $node]

        if {[file type $dir] eq "link"} {
            ## If we find a recursive link we only open the topmost
            ## directory link.  Going any deeper will just put us
            ## into an infinite loop, so we stop at one level deep.
            if {![info exists LinkDirs($topdir)]} { set LinkDirs($topdir) "" }
            set link [file tail $dir],[file normalize [file readlink $dir]]
            if {[lsearch -exact $LinkDirs($topdir) $link] > -1} {
                $tree itemconfigure $node -drawcross auto
                return
            }
            lappend LinkDirs($topdir) $link
        }

        set group [::FileGroupTree::GetFileGroup $node]
        set group [$tree itemcget $group -data]

        set filelist [glob -nocomplain -directory $dir *]
        eval lappend filelist [glob -nocomplain -type hidden -directory $dir *]

        foreach file $filelist {
            set found 1
            set type file
            set tail [file tail $file]
            if {[file isdir $file]} {
                if {$tail eq "." || $tail eq ".."} { continue }
                if {[::InstallJammer::IgnoreDir $file]} { continue }
                set type dir
            } else {
                if {[::InstallJammer::IgnoreFile $tail]} { continue }
            }

            AddToFileGroup -type $type -platform $platform -group $group \
                -name $file -text $tail -parent $id -modify 0
        }
    }

    if {$found} { ::FileGroupTree::SortNodes $node }
    $tree itemconfigure $node -drawcross auto
}

proc ::FileGroupTree::close { tree node } {
    #set id [$tree itemcget $node -data]
    #if {[$id type] eq "filegroup"} {
        #$tree itemconfigure $node -image [GetImage folder16]
    #}
}

proc ::FileGroupTree::dorename { node } {
    global conf

    variable old
    variable tree
    variable double

    after cancel $conf(renameAfterId)

    set type [[$tree itemcget $node -data] type]
    if {![info exists double] && $node eq $old && $type eq "filegroup"} {
        ## They clicked the same node again.  After a 1 second delay,
        ## edit the name of the node to rename it.
        set text [$tree itemcget $node -text]
        set cmd  [list ::InstallJammer::Tree::DoRename $tree $node]
        set conf(renameAfterId) [after 800 [list $tree edit $node $text $cmd]]
        return
    }

    set old $node
}

proc ::FileGroupTree::rename { node newtext } {
    global widg

    variable pref

    variable ::InstallJammer::active

    set id [$pref itemcget $node -data]

    $id name $newtext
    $id set Name $newtext

    $widg(ComponentFileGroupTree) itemconfigure $id -text $newtext

    set active(Name) $newtext
}

proc ::InstallJammer::DeleteFilesFromTree {objects} {
    global widg

    if {![info exists widg(FileGroupTree)]} { return }
    set tree $widg(FileGroupTree)

    set items {}
    foreach id $objects {
        set node [::InstallJammer::NodeName $id]
	if {[$tree exists $node]} { lappend items $node }
        if {[::InstallJammer::ObjExists $id]} { $id destroy }
    }

    if {[llength $items]} {
        eval $tree selection remove $items
        eval $tree delete $items
        ::InstallJammer::RebuildFileMap
        Modified
        ::InstallJammer::FilesModified
    }
}

proc ::FileGroupTree::delete { {selection ""} } {
    global widg

    variable tree

    if {![llength $selection]} { set selection [$tree selection get] }

    if {![llength $selection]} { return }

    set ans [::InstallJammer::MessageBox -type yesno -title "Delete Items" \
        -message "Are you sure you want to delete the selected items?"]

    if {$ans eq "no"} { return }

    set items  [list]
    set idlist [list]
    foreach i $selection {
	if {![$tree exists $i]} { continue }

	set id [$tree itemcget $i -data]

        switch -- [$id type] {
            "dir" - "file" {
                ## We only delete files and directories who are
                ## direct children of a file group.
                set file [::InstallJammer::GetFileSource $id]
                if {[[$id parent] is filegroup] || ![file exists $file]} {
                    lappend items $i
                    $id destroy
                }
            }

            "filegroup" {
                lappend items  $i
                lappend idlist $id
                $id destroy

                $widg(ComponentFileGroupTree) delete $id
            }
        }
    }

    if {[llength $items]} {
        eval $tree selection remove $items
        eval $tree delete $items
        ::InstallJammer::RebuildFileMap
        Modified
        ::InstallJammer::FilesModified
    }

    if {[llength $idlist]} { 
        foreach id [Components children recursive] {
            set filegroups [$id get FileGroups]
            set filegroups [eval [list lremove $filegroups] $idlist]
            $id set FileGroups $filegroups
        }
        Modified
        ::InstallJammer::FilesModified
    }
}

proc ::FileGroupTree::popup { args } {
    variable tree

    focus $tree

    if {![lempty $args]} { lassign $args X Y item }

    set sel [$tree selection get]

    if {[lsearch -exact $sel $item] < 0} {
	::FileGroupTree::select 1 $item
	set sel $item
    }

    if {[llength $sel] > 1} {
        set menu $::FileGroupTree::MultiPopup
    } elseif {[llength $sel] == 1} {
	set id [$tree itemcget $sel -data]

        if {[$id is filegroup]} {
	    set menu $::FileGroupTree::FileGroupPopup
        } else {
            if {[$id isfile]} {
                set menu $::FileGroupTree::FilePopup
            } else {
	        set menu $::FileGroupTree::DirectoryPopup
            }
	}
    }

    if {[info exists X]} {
	$menu post $X $Y

        if {[string equal $::tcl_platform(platform) "unix"]} {
            tkwait window $menu
        }
    }
}

proc ::FileGroupTree::selection { cmd items } {
    global conf
    global info
    global widg

    variable tree

    eval $tree selection $cmd $items
}

proc ::FileGroupTree::GetTopDirectory {node} {
    variable tree
    set id [$tree itemcget $node -data]
    foreach parent [$id parent recursive] {
        if {[$parent type] eq "dir"} { break }
    }
    return $parent
}

proc ::FileGroupTree::GetFileGroup {node} {
    variable tree

    set type [[$tree itemcget $node -data] type]
    while {![string equal $type "filegroup"]} {
        set node [$tree parent $node]
        set type [[$tree itemcget $node -data] type]
    }

    return $node
}

proc ::FileGroupTree::AddToProgramFolder {} {
    variable tree

    set items [$tree selection get]

    foreach i $items {
        set id [$tree itemcget $i -data]
        if {![$id is file]} { continue }
	set filename [$tree itemcget $i -text]
	set parent [$tree parent $i]
        set group  [$tree itemcget $parent -data]

	set file     [file tail $filename]
	set linkName [file root $file]
	set objPath  [::InstallJammer::GetFileDestination $id]

        set parent [::BuilderAPI::GetActionGroup -alias "Install Actions"]

        set act [::InstallJammer::AddAction Install \
            InstallProgramFolderShortcut \
            -parent $parent -title "$linkName Shortcut"]

        $act set FileName       "<%ShortAppName%>-program-[join $linkName {}]"
        $act set ShortcutName   $linkName
        $act set TargetFileName $objPath

        if {[string match "*.html" $file]} {
            $act set ShortcutType   "Link"
            $act set TargetFileName "file://$objPath"
        }
    }
}

proc ::FileGroupTree::AddToDesktop {} {
    variable tree

    set items [$tree selection get]

    foreach i $items {
        set id [$tree itemcget $i -data]
        if {![$id is file]} { continue }

	set parent   [$tree parent $i]
        set group    [$tree itemcget $parent -data]
	set filename [$tree itemcget $i -text]

	set file     [file tail $filename]
	set linkName [file root $file]
	set objPath  [::InstallJammer::GetFileDestination $id]

        set parent [::BuilderAPI::GetActionGroup -alias "Install Actions"]

        set act [::InstallJammer::AddAction Install InstallDesktopShortcut \
                -parent $parent -title "$linkName Shortcut"]

        $act set FileName       "<%ShortAppName%>-desktop-[join $linkName {}]"
        $act set ShortcutName   $linkName
        $act set TargetFileName $objPath

        if {[string match "*.html" $file]} {
            $act set ShortcutType   "Link"
            $act set TargetFileName "file://$objPath"
        }
    }
}

proc ::FileGroupTree::Check { {items ""} } {
    variable tree
    if {[lempty $items]} { set items [$tree selection get] }

    foreach i $items {
        if {![$tree exists $i]} { continue }
        set id [$tree itemcget $i -data]
        if {![$id is file] && ![$id is dir]} { continue }
        $id active 1
	set image folder16
        if {[$id is file]} { set image filedocument16 }
	$tree itemconfigure $i -image [GetImage check$image]
	Modified
        ::InstallJammer::FilesModified
    }

    ::FileGroupTree::UpdateDetails
}

proc ::FileGroupTree::Uncheck { {items ""} } {
    variable tree
    if {[lempty $items]} { set items [$tree selection get] }

    foreach i $items {
        if {![$tree exists $i]} { continue }
        set id [$tree itemcget $i -data]
        if {![$id is dir] && ![$id is file]} { continue }
        $id active 0
	set image folder16
        if {[$id is file]} { set image filedocument16 }
	$tree itemconfigure $i -image [GetImage $image]
	Modified
        ::InstallJammer::FilesModified
    }

    ::FileGroupTree::UpdateDetails
}

proc ::FileGroupTree::Explore {} {
    variable tree

    set initdir ""

    set i [$tree selection get]
    if {[llength $i] == 1} {
	set id [$tree itemcget $i -data]

	switch -- [$id type] {
	    "dir" {
		set initdir [::InstallJammer::GetFileSource $id]

	    }
	    "file" {
		set initdir [file dirname [::InstallJammer::GetFileSource $id]]
	    }
	}
    }

    if {$initdir ne "" && ![file exists $initdir]} {
        ::InstallJammer::Error -message "Could not locate directory '$initdir'"
        return
    }

    ::InstallJammer::Explore $initdir
}

proc ::FileGroupTree::SetupPermissionsArray { id } {
    variable permissions

    if {[$id is filegroup]} {
        set attrs [$id get Attributes]
        set perms [$id get Permissions]
    } else {
        set attrs [$id attributes]
        set perms [$id permissions]
    }

    set defaultw [expr ![string length $attrs]]
    set defaultu [expr ![string length $perms]]

    if {![$id is filegroup]} {
        set file [::InstallJammer::GetFileSource $id]

        if {$::conf(windows)} {
            if {![string length $attrs] && [file exists $file]} {
                array set tmp [file attributes $file]
                append attrs $tmp(-archive)  $tmp(-hidden)
                append attrs $tmp(-readonly) $tmp(-system)
            }
        } else {
            if {![string length $perms] && [file exists $file]} {
                set perms [file attributes $file -permissions]
            }
        }
    }

    set permissions(UseWindowsDefaultPermissions) $defaultw
    tag configure WindowsDetailsPermissions -state \
        [expr {$defaultw ? "disabled" : "normal"}]

    set permissions(UseUNIXDefaultPermissions) $defaultu
    tag configure UNIXDetailsPermissions -state \
        [expr {$defaultu ? "disabled" : "normal"}]

    ## Windows permissions are stored as XXXX for
    ## archive,hidden,readonly,system
    if {$attrs eq ""} { set attrs 0000 }
    lassign_array [split $attrs ""] permissions \
        PermArchive PermHidden PermReadonly PermSystem

    ## UNIX permissions.
    if {$perms eq ""} { set perms 000 }
    set Other [string index $perms end]
    set Group [string index $perms end-1]
    set User  [string index $perms end-2]

    foreach x [list User Group Other] {
        upvar 0 $x which
        set permissions(Perm${x}Execute) 0
        if {[expr $which & 1] == 1} {
            set permissions(Perm${x}Execute) 1
        }
        set permissions(Perm${x}Write) 0
        if {[expr $which & 2] == 2} {
            set permissions(Perm${x}Write) 1
        }
        set permissions(Perm${x}Read) 0
        if {[expr $which & 4] == 4} {
            set permissions(Perm${x}Read) 1
        }
    }
}

proc ::FileGroupTree::SetPermissions { arrayName {idlist ""} } {
    variable tree

    if {![string length $tree]} { return }

    if {![llength $idlist]} {
        set sel [$tree selection get]
        if {![llength $sel]} { return }
        foreach node $sel {
            lappend idlist [$tree itemcget $node -data]
        }
    }

    upvar #0 $arrayName array

    set attributes  ""
    set permissions ""
    if {!$array(UseWindowsDefaultPermissions)} {
        set    attributes $array(PermArchive)
        append attributes $array(PermHidden)
        append attributes $array(PermReadonly)
        append attributes $array(PermSystem)
    }

    if {!$array(UseUNIXDefaultPermissions)} {
        foreach x {User Group Other} {
            set tmp($x) 0

            if {$array(Perm${x}Execute)} {
                set tmp($x) [expr $tmp($x) | 1]
            }
            if {$array(Perm${x}Write)} {
                set tmp($x) [expr $tmp($x) | 2]
            }
            if {$array(Perm${x}Read)} {
                set tmp($x) [expr $tmp($x) | 4]
            }
        }

        set permissions 00$tmp(User)$tmp(Group)$tmp(Other)
    }

    foreach id $idlist {
        if {$id eq [::InstallJammer::GetActiveComponent]} {
            set ::InstallJammer::active(Attributes)  $attributes
            set ::InstallJammer::active(Permissions) $permissions
        }

        if {[$id is filegroup]} {
            $id set Permissions $permissions Attributes $attributes
        } else {
            $id configure -permissions $permissions -attributes $attributes
        }
    }

    if {[llength $idlist]} {
        Modified
        ::InstallJammer::FilesModified
    }
}

proc ::FileGroupTree::GetSelectedItems {} {
    variable tree
    set ids [list]
    foreach node [$tree selection get] {
        lappend ids [$tree itemcget $node -data]
    }
    return $ids
}

proc ::FileGroupTree::UpdateSelectedItems { args } {
    variable tree

    foreach id [::FileGroupTree::GetSelectedItems] {
        foreach {property value} $args {
            if {[$id is filegroup]} {
                $id set $property $value
            } else {
                switch -- $property {
                    "Active" {
                        if {$value} {
                            lappend check [::InstallJammer::NodeName $id]
                        } else {
                            lappend uncheck [::InstallJammer::NodeName $id]
                        }
                        continue
                    }

                    "Destination" {
                        set property directory
                    }

                    "FileUpdateMethod" {
                        set property filemethod
                    }

                    "Location" {
                        ## Location is set in a popup dialog.
                        ## Since Location is only set on single objects,
                        ## we can just return instead of continuing on
                        ## to the next object.
                        return
                    }

                    default {
                        set property [string tolower $property]
                    }
                }

                $id $property $value
            }
        }

        Modified
        ::InstallJammer::FilesModified
    }

    if {[info exists check]} { ::FileGroupTree::Check $check }
    if {[info exists uncheck]} { ::FileGroupTree::Uncheck $uncheck }

    ::FileGroupTree::UpdateDetails
}

proc ::FileGroupTree::UpdateSelection { tree nodes } {
    if {[llength $nodes] > 1} {
        global widg

        variable details

        ## Clear the active component.
        ::InstallJammer::SetActiveComponent

        set prop $widg(FileGroupDetailsProp)

        foreach node [$prop nodes root] {
            $prop itemconfigure $node -state hidden
        }

        $prop itemconfigure permissions -state normal
        $prop itemconfigure multiplefiles -state normal

        set details(Active)            ""
        set details(Destination)       ""
        set details(CompressionMethod) ""
        set details(FileUpdateMethod)  ""
        set details(Location)          ""
        set details(Version)           ""
        set details(SaveFiles)         ""
    }
}

proc ::FileGroupTree::UpdateDetails {} {
    global info

    variable tree
    variable details

    set sel [$tree selection get]

    if {[llength $sel] == 1} {
        set id [$tree itemcget [lindex $sel 0] -data]

        set details(Active)  [expr {[$id active] ? "Yes" : "No"}]
        set details(Comment) [$id comment]

        if {[$id is dir file]} {
            array set details {
                name              ""
                location          ""
                fileSize          ""
                fileGroup         ""
                installLocation   ""
                fileMethod        ""
                fileVersion       ""
                created           ""
                modified          ""
                accessed          ""
                compressionMethod ""
            }

            set file  [::InstallJammer::GetFileSource $id]

            set details(name)      [file tail $file]
            set details(location)  [file dirname $file]
            set details(fileGroup) [[$id group] name]

            if {[::InstallJammer::GetFileActive $id]} {
                set details(installLocation) \
                    [::InstallJammer::GetFileDestination $id]
            } else {
                set details(installLocation) "Inactive (will not be installed)"
            }

            set details(fileMethod)  [::InstallJammer::GetFileMethod $id]
            set details(fileVersion) [::InstallJammer::GetFileVersion $id]
            if {![string length $details(fileVersion)]} {
                set details(fileVersion) $info(InstallVersion)
            }

            set details(compressionMethod) \
                [::InstallJammer::GetFileCompressionMethod $id]

            set details(Location) [$id location]
            if {[info exists ::InstallJammer::Locations($id)]} {
                set details(Location) $::InstallJammer::Locations($id)
            }

            if {![file exists $file]} {
                set details(fileSize) "(file not found)"
                set details(created)  "(file not found)"
                set details(modified) "(file not found)"
                set details(accessed) "(file not found)"
            } else {
                file stat $file stats
                set fsize [::InstallJammer::FormatDiskSpace $stats(size)]

                ## Setup file details
                set fmt "%A, %B %d, %Y %H:%M:%S %p"
                set details(fileSize) "$fsize ($stats(size) bytes)"
                set details(created)  [clock format $stats(ctime) -format $fmt]
                set details(modified) [clock format $stats(mtime) -format $fmt]
                set details(accessed) [clock format $stats(atime) -format $fmt]
            }
        }
    }
}

proc ::FileGroupTree::RaiseNode { node } {
    global widg

    variable tree
    variable pref
    variable details
    variable ActiveFile

    set prop $widg(FileGroupDetailsProp)

    set id [$tree itemcget $node -data]

    set ActiveFile $id

    foreach n [list dir file] {
        if {[$id is $n]} {
            $prop itemconfigure $n -state normal
        } else {
            $prop itemconfigure $n -state hidden
        }
    }
    $prop itemconfigure multiplefiles -state hidden

    if {[$id is filegroup]} {
        ::InstallJammer::SetHelp GroupsAndFiles

        $prop itemconfigure standard  -state normal
        $prop itemconfigure platforms -state normal

        $prop itemconfigure filestandard -state hidden

        ::InstallJammer::SetActiveComponent $id

        ::InstallJammer::SetupPlatformProperties $id $prop
    } else {
        ## Hide the File Group tables.
        $prop itemconfigure standard  -state hidden
        $prop itemconfigure platforms -state hidden

        ## Show the file standard properties.
        $prop itemconfigure filestandard -state normal

        ## Walk the properties and disable the Target Filename
        ## property if the given id is a directory.  Directories
        ## use Destination Directory as their install location.
        set type [$id type]
        foreach subnode [$prop nodes filestandard] {
            set data   [$prop itemcget $subnode -data]
            set parent [$id parent]

            if {$data eq "TargetFilename" && $type eq "dir"} {
                $prop itemconfigure $subnode -state hidden
                continue
            }

            if {$data eq "SaveFiles" && $type eq "file"} {
                $prop itemconfigure $subnode -state hidden
                continue
            }

            $prop itemconfigure $subnode -state normal
        }

        ## Setup Standard Properties
        set details(ID)                $id
        set details(Active)            [expr {[$id active] ? "Yes" : "No"}]
        set details(Alias)             [$id alias]
        set details(Comment)           [$id get Comment]
        set details(Destination)       [$id directory]
        set details(DisplayName)       [$id get DisplayName]
        set details(TargetFilename)    [$id targetfilename]
        set details(FileUpdateMethod)  [$id filemethod]
        set details(CompressionMethod) [$id compressionmethod]
        set details(Version)           [$id version]
        set details(SaveFiles)         [$id savefiles]

        ::FileGroupTree::UpdateDetails
        ::InstallJammer::SetHelp FilesAndDirectories
    }

    ::FileGroupTree::SetupPermissionsArray $id

    $pref raise $node
}

proc ::FileGroupTree::SortNodes { groupNode } {
    variable tree

    set dirs  [list]
    set files [list]
    foreach node [$tree nodes $groupNode] {
        set id   [$tree itemcget $node -data]
        set text [$tree itemcget $node -text]
        if {[$id is dir]} {
            lappend dirs [list $text $node]
        } else {
            lappend files [list $text $node]
        }
    }

    set nodes [list]
    foreach list [lsort -dict -index 0 $dirs] {
        lappend nodes [lindex $list 1]
    }

    foreach list [lsort -dict -index 0 $files] {
        lappend nodes [lindex $list 1]
    }

    $tree reorder $groupNode $nodes
}

proc ::InstallJammer::FilterFile { file args } {
    array set opts {
	-include	""
	-exclude	""
	-defaultaction	1
	-regexp		0
    }

    array set opts $args

    set matchInclude 0
    set matchExclude 0
    foreach pattern $opts(-include) {
	if {$opts(-regexp)} {
	    set res [regexp $pattern $file]
	} else {
	    set res [string match $pattern $file]
	}

	if {$res} {
	    set matchInclude 1
	    if {$opts(-defaultaction)} { return 1 }
	}
    }

    foreach pattern $opts(-exclude) {
	if {$opts(-regexp)} {
	    set res [regexp $pattern $file]
	} else {
	    set res [string match $pattern $file]
	}
	if {$res} {
	    set matchExclude 1
	    if {!$opts(-defaultaction)} { return 0 }
	}
    }

    if {$matchInclude} { return 1 }
    if {$matchExclude} { return 0 }
    return -1
}

proc ::InstallJammer::FilterFileGroups { args } {
    global info
    global widg

    set tree $widg(FileGroupTree)

    array set opts {
	-nodes		"all"
	-regexp		0
	-include	""
	-exclude	""
	-recursive      1
	-defaultaction	"include"
    }

    array set opts $args

    set act [string equal $opts(-defaultaction) "include"]
    lappend filterArgs -regexp  $opts(-regexp)
    lappend filterArgs -include $opts(-include)
    lappend filterArgs -exclude $opts(-exclude)
    lappend filterArgs -defaultaction $act

    if {[string equal $opts(-nodes) "all"]} {
        set opts(-nodes) [$tree nodes root]
    }

    ::InstallJammer::RefreshFileGroups

    Status "Filtering file groups..."

    set ids [list]
    foreach node $opts(-nodes) {
        set id [$tree itemcget $node -data]

        if {$opts(-recursive)} {
            eval lappend ids $id [$id children recursive]
        }
    }

    foreach id $ids {
        if {[$id is filegroup]} { continue }

        set file [::InstallJammer::GetFileSource $id]
        set res  [eval [list FilterFile $file] $filterArgs]

        if {$res < 0} { continue }

        set node [::InstallJammer::NodeName $id]

        $id active $res
        Modified
        ::InstallJammer::FilesModified

        if {$res == 0} {
            ::FileGroupTree::Uncheck $node
        } elseif {$res == 1} {
            ::FileGroupTree::Check   $node
        }
    }

    ClearStatus
}

proc ::InstallJammer::GetFileSource { id {subst 1} } {
    global info

    variable Locations

    set name     [$id srcfilename]
    set parent   [$id parent]
    set location [$id location]

    if {[info exists Locations($id)]} {
        set location $Locations($id)
    }

    if {$location ne ""} {
        if {[$id is dir]} {
            set dir $location
        } else {
            set dir [file join $location $name]
        }
    } elseif {[$parent is filegroup]} {
        ## If we reach the file group before we've found
        ## a working directory, just return the original
        ## filename.
        if {$info(DefaultDirectoryLocation) eq ""} {
            set dir [$id name]
        } else {
            set dir $info(DefaultDirectoryLocation)
        }
    } else {
        set dir [file join [::InstallJammer::GetFileSource $parent] $name]
    }

    if {$subst} { set dir [::InstallJammer::SubstText $dir] }

    if {[file pathtype $dir] eq "relative"} {
        set dir [file join $info(ProjectDir) $dir]
    }

    return [file normalize $dir]
}

proc ::InstallJammer::GetFileDestination { id } {
    set dir    [$id destdirname]
    set name   [$id destfilename]
    set parent [$id parent]

    if {$dir ne ""} {
        set dest $dir
        if {[$id isfile]} { set dest [file join $dir $name] }
    } elseif {[$parent is filegroup]} {
        set dir [$parent destdirname]
        if {$dir eq ""} { set dir "<%InstallDir%>" }
        set dest [file join $dir $name]
    } else {
        set dest [file join [::InstallJammer::GetFileDestination $parent] $name]
    }

    return $dest
}

proc ::InstallJammer::GetFileActive { id } {
    if {![$id active]} { return 0 }
    foreach parent [lreverse [lrange [$id parent recursive] 1 end]] {
        if {![$parent active]} { return 0 }
    }
    return 1
}

proc ::InstallJammer::GetFileVersion { id } {
    if {[string length [$id version]]} { return [$id version] }
    foreach parent [lreverse [lrange [$id parent recursive] 1 end]] {
        if {[string length [$parent version]]} { return [$parent version] }
    }
}

proc ::InstallJammer::GetFileMethod { id {map 0} } {
    set method [$id filemethod]
    if {$method eq ""} {
        foreach parent [lreverse [lrange [$id parent recursive] 1 end]] {
            set method [$parent filemethod]
            if {$method ne ""} { break }
        }
    }
    if {$map} {
        variable ::InstallJammer::PropertyMap
        set method [lsearch -exact $PropertyMap(FileUpdateMethod) $method]
    }
    return $method
}

proc ::InstallJammer::GetFileCompressionMethod { id } {
    global info

    if {[$id compressionmethod] ne ""} { return [$id compressionmethod] }

    foreach parent [lreverse [lrange [$id parent recursive] 1 end]] {
        set method [$parent compressionmethod]
        if {$method ne ""} { return $method }
    }

    return $info(CompressionMethod)
}

proc ::InstallJammer::EditLocation { id } {
    global widg

    if {![::InstallJammer::ObjExists $id]} {
        set id $::FileGroupTree::ActiveFile
    }

    ClearTmpVars

    set ::TMP(projectLocation) [$id location]

    set ::TMP(preferenceLocation) ""
    if {[info exists ::InstallJammer::Locations($id)]} {
        set ::TMP(preferenceLocation) $::InstallJammer::Locations($id)
    }

    set top [::InstallJammer::TopName .__setLocation]
    Dialog .__setLocation -title "Set Location" -geometry "400x150" \
        -applybutton 0

    set frame [$top getframe]

    grid rowconfigure    $frame 4 -weight 1
    grid columnconfigure $frame 0 -weight 1

    ttk::label $frame.projectL -text "Location in Project File"
    grid $frame.projectL -row 0 -column 0 -sticky nw -padx 2

    ttk::entry $frame.project -textvariable ::TMP(projectLocation)
    grid $frame.project -row 1 -column 0 -sticky new -padx {2 0}

    focus $frame.project

    ttk::button $frame.projectB -style Toolbutton -text "..." \
        -takefocus 0 -command [list GetDir ::TMP(projectLocation)]
    grid $frame.projectB -row 1 -column 1

    ttk::label $frame.preferenceL -text "Location in Local Preferences"
    grid $frame.preferenceL -row 2 -column 0 -sticky nw -padx 2 -pady {5 0}

    ttk::entry $frame.preference -textvariable ::TMP(preferenceLocation)
    grid $frame.preference -row 3 -column 0 -sticky new -padx {2 0}

    ttk::button $frame.preferenceB -style Toolbutton -text "..." \
        -takefocus 0 -command [list GetDir ::TMP(preferenceLocation)]
    grid $frame.preferenceB -row 3 -column 1

    set res [$top draw]

    if {$res eq "ok"} {
        ::InstallJammer::SetLocation $id \
            $::TMP(projectLocation) $::TMP(preferenceLocation)
    }

    destroy $top
}

proc ::InstallJammer::SetLocation { id projectLocation preferenceLocation } {
    global widg

    if {![::InstallJammer::ObjExists $id]} {
        set id $::FileGroupTree::ActiveFile
    }

    $id location $projectLocation

    if {$preferenceLocation eq ""} {
        unset -nocomplain ::InstallJammer::Locations($id)
    } else {
        set ::InstallJammer::Locations($id) $preferenceLocation
    }

    ::FileGroupTree::UpdateDetails

    set node [::InstallJammer::NodeName $id]

    if {[$widg(FileGroupTree) exists $node]} {
        set file [::InstallJammer::GetFileSource $id]
        set fill SystemWindowText
        if {![file exists $file]} { set fill SystemDisabledText }
        $widg(FileGroupTree) itemconfigure $node -fill $fill

        if {![$id isfile]} {
            eval $widg(FileGroupTree) delete [$widg(FileGroupTree) nodes $node]
            $widg(FileGroupTree) itemconfigure $node -drawcross allways
            ::FileGroupTree::open $widg(FileGroupTree) $node
        }
    }

    ::InstallJammer::RebuildLocations
}

proc ::InstallJammer::GetFileNodeColor { id } {
    set file [::InstallJammer::GetFileSource $id]
    set tail [file tail $file]

    if {$::conf(windows)} { set tail [string tolower $tail] }

    set fill SystemWindowText

    if {[info exists ::InstallJammer::NewFiles([$id parent],$tail)]} {
        set fill blue
    }

    if {![file exists $file]} {
        set fill SystemDisabledText
    }

    return $fill
}

proc ::InstallJammer::RedrawFileTreeNodes { {node root} } {
    global conf
    global widg

    set tree $widg(FileGroupTree)

    foreach node [$tree nodes $node] {
        set id [$tree itemcget $node -data]

        if {![$id is filegroup]} {
            $tree itemconfigure $node \
                -fill [::InstallJammer::GetFileNodeColor $id]
        }

        if {![$id is file]} {
            ::InstallJammer::RedrawFileTreeNodes $node
        }
    }
}
