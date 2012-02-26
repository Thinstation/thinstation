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

namespace eval ::ComponentTree {
    variable tree ""
    variable popup ""
}

proc ::ComponentTree::setup { tree } {
    $tree bindText  <Button-1>		"::ComponentTree::select 1"
    $tree bindImage <Button-1>		"::ComponentTree::select 1"
    $tree bindText  <ButtonRelease-1>	"::ComponentTree::dorename"
    $tree bindImage <ButtonRelease-1>	"::ComponentTree::dorename"
    $tree bindText  <Double-Button-1>	"::ComponentTree::select 2"
    $tree bindImage <Double-Button-1>	"::ComponentTree::select 2"
    $tree bindText  <Shift-Button-1>	"::ComponentTree::select 3"
    $tree bindImage <Shift-Button-1>	"::ComponentTree::select 3"
    $tree bindText  <Control-Button-1>	"::ComponentTree::select 4"
    $tree bindImage <Control-Button-1>	"::ComponentTree::select 4"

    $tree bindText  <Button-3>          "::ComponentTree::popup %X %Y"
    $tree bindImage <Button-3>          "::ComponentTree::popup %X %Y"

    ::FileTree::Setup $tree
}

proc ::ComponentTree::init {} {
    global widg
    variable tree $widg(ComponentTree)
    variable pref $widg(ComponentPref)

    ::ComponentTree::Clear

    $pref insert end root Components -text "My Product" -haspage 0 -open 1 \
        -data component -image [GetImage component16]
    
    foreach id [::ComponentTree::List] {
	set node [::ComponentTree::New -id $id]
    }
}

proc ::ComponentTree::Clear {} {
    global widg
    variable pref
    variable FileGroupIncludes

    if {![string length $pref]} { return }

    $pref selection clear

    eval [list $pref delete] [$pref nodes root]

    set tree $widg(ComponentFileGroupTree)
    eval $tree delete [$tree nodes root]
    unset -nocomplain FileGroupIncludes
}

proc ::ComponentTree::New { args } {
    global info
    global widg

    variable pref

    array set data {
        -id     ""
        -text   ""
    }
    array set data $args

    set id  $data(-id)
    set new 0
    if {![string length $id]} {
        set parent [$pref selection get]
        if {![string length $parent]} { set parent Components }

        set id   [::InstallJammer::uuid]
        set text $data(-text)

        Component ::$id -name $text -parent $parent

        if {![string length $text]} {
            set new 1
            set text "New Component"
            ::InstallJammer::EditNewNode $pref end $parent $id \
                -text $text -image [GetImage component16] -fill blue \
                -data component -pagewindow $widg(ComponentDetails) -open 1
            set text [$pref itemcget $id -text]
            $id configure -name $text
            focus [$pref gettree]
        }

        $id platforms [AllPlatforms]
    }

    set text   [$id name]
    set parent [$id parent]

    ::ComponentObject initialize $id Name $text

    if {!$new} {
        $pref insert end $parent $id -text $text \
            -image [GetImage component16] -data component \
            -pagewindow $widg(ComponentDetails) -open 1
    } else {
        ::ComponentTree::select 1 $id
    }

    if {[string equal $parent "Components"]} { set parent root }

    if {[$id is component]} {
        set tree $widg(SetupTypeComponentTree)
        $tree insert end $parent $id \
            -type checkbutton -open 1 -text $text \
            -variable ::SetupTypeTree::ComponentIncludes($id) \
            -command [list ::SetupTypeTree::SetComponentInclude $tree $id]
    }

    Modified

    return $id
}

proc ::ComponentTree::List { args } {
    return [Components children recursive]
}

proc ::ComponentTree::select {mode node} {
    global conf
    global info
    global widg

    variable tree

    after cancel $conf(renameAfterId)

    variable old [$tree selection get]

    if {$mode == 1} {
	$tree selection set $node

        ::ComponentTree::RaiseNode $node

        variable last $old
    }

    if {$mode == 2} {
	## It's a double-click.
	## If there is no data associated with the node, it's a platform
	## or component, so we need to open or close it.

        variable double 1
        after idle [list unset -nocomplain [namespace current]::double]

	$tree selection set $node

        $tree toggle $node

        ::ComponentTree::RaiseNode $node
    }

    if {$mode == 3 && [$tree parent $node] != "root"} {
	## They executed a shift-click.
	## If both nodes are not in the same parent node, ignore it.
	if {[lempty $old]} { return }
	set old [lindex $old 0]
	if {[$tree parent $node] != [$tree parent $old]} { return }
	set p [$tree parent $old]
	set first [$tree index $old]
	set last  [$tree index $node]	
	if {$last < $first} {
	    set items [$tree nodes $p $last $first]
	} else {
	    set items [$tree nodes $p $first $last]
	}

	eval $tree selection set $items
    }

    if {$mode == 4 && [$tree parent $node] != "root"} {
	## They executed a ctrl-click.
	if {[lsearch $old $node] > -1} {
	    $tree selection remove $node
	} else {
	    $tree selection add $node
	}
    }

    if {$mode == 5} {
	$tree selection set $node
    }
}

proc ::ComponentTree::dorename { node } {
    global conf

    variable old
    variable tree
    variable double

    after cancel $conf(renameAfterId)

    ## They're renaming the node.
    if {![info exists double] && $node eq $old && $node ne "Components"} {
        set text [$tree itemcget $node -text]
        set cmd  [list ::InstallJammer::Tree::DoRename $tree $node]
        set conf(renameAfterId) [after 800 [list $tree edit $node $text $cmd]]
        return
    }
}

proc ::ComponentTree::rename { id newtext } {
    global widg
    variable pref

    variable ::InstallJammer::active

    $id name $newtext
    $id set Name $newtext

    $widg(SetupTypeComponentTree) itemconfigure $id -text $newtext

    set active(Name) $newtext
}

proc ::ComponentTree::delete {} {
    global widg

    variable pref

    set ans [::InstallJammer::MessageBox -type yesno \
        -message "Are you sure you want to delete the selected components?"]
    if {$ans eq "no"} { return }

    set idlist [list]
    foreach id [$pref selection get] {
        if {![$pref exists $id]} { continue }

        if {$id eq "Components"} { continue }

        $pref delete $id
        $widg(SetupTypeComponentTree) delete $id
        $id destroy

        lappend idlist $id
    }

    if {[llength $idlist]} {
        foreach id [SetupTypes children] {
            set components [$id get Components]
            set components [eval [list lremove $components] $idlist]
            $id set Components $components
        }
        Modified
    }
}

proc ::ComponentTree::popup { X Y item } {
    variable tree
    variable popup

    focus $tree

    $popup post $X $Y
    if {$::tcl_platform(platform) == "unix"} { tkwait window $popup }
}

proc ::ComponentTree::RaiseNode { node } {
    global widg

    variable pref
    variable FileGroupIncludes

    if {[string equal $node "Components"]} { return }

    ## If this is the same node already raised, don't do anything
    if {[string equal [$pref raise] $node]} { return }

    $pref raise $node
    set id $node

    set tree $widg(ComponentFileGroupTree)

    set include [$id get FileGroups]
    foreach node [::InstallJammer::Tree::AllNodes $tree] {
        if {[lsearch -exact $include $node] > -1} {
            set FileGroupIncludes($node) 1
        } else {
            set FileGroupIncludes($node) 0
        }
    }

    ::InstallJammer::SetActiveComponent $id

    ::InstallJammer::SetupPlatformProperties $id $widg(ComponentDetailsProp)
}

proc ::ComponentTree::SetFileGroupInclude { tree node } {
    variable pref
    variable FileGroupIncludes

    set component [$pref raise]
    if {![string length $component]} { return }

    set include [list]
    foreach node [::InstallJammer::Tree::AllNodes $tree] {
        if {$FileGroupIncludes($node)} { lappend include $node }
    }

    $component set FileGroups $include

    if {$component eq $::InstallJammer::ActiveComponent} {
        set ::InstallJammer::active(FileGroups) $include
    }
}
