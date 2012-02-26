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

namespace eval ::Tree {}
namespace eval ::FileTree {}
namespace eval ::InstallJammer::Tree {}

proc InitComponentTrees {} {
    ::SetupTypeTree::init
    ::ComponentTree::init
    ::FileGroupTree::init
}

proc ClearComponentTrees {} {
    ::SetupTypeTree::Clear
    ::ComponentTree::Clear
    ::FileGroupTree::Clear

    unset -nocomplain ::InstallJammer::Tree::select
}

proc ::FileTree::Setup { tree } {
    set canvas [$tree getcanvas]
    bind $canvas <F2>     [list ::InstallJammer::Tree::Rename $tree]
    bind $canvas <Delete> [list ::InstallJammer::Tree::Delete $tree]
}

proc ::FileTree::GetPlatform {tree node} {
    set a $node
    set p [$tree parent $node]
    while { $p != "root" } {
	set a $p
	set p [$tree parent $p]
    }
    return $a
}

proc ::FileTree::SelectAll {tree} {
    foreach platform [$tree nodes root] {
	SelectAllPlatform $tree $platform
    }
}

proc ::FileTree::SelectAllPlatform {tree {platform ""}} {
    if {[lempty $platform]} {
    	set platform [$tree selection get]
    }
    foreach item [$tree nodes $platform] {
	SelectAllBeneath $tree $item
    }
}

proc ::FileTree::SelectAllBeneath {tree {node ""}} {
    if {[lempty $node]} { set node [$tree selection get] }
    $tree selection add $node
    foreach item [$tree nodes $node] {
	$tree selection add $item
    }
}

proc ::FileTree::Check { tree {types ""} } {
    set sel [$tree selection get]

    foreach i $sel {
	set data [$tree itemcget $i -data]
	set type [lindex $data 0]
	if {$type == "platform"} { continue }
	if {[lsearch $types $type] > -1} { continue }
	upvar #0 $data var
	if {![info exists var]} { continue }
	set var 1
	$tree itemconfigure $i -image [GetImage checkfolder16]
	Modified
    }
}

proc ::FileTree::Uncheck {tree {types ""}} {
    set sel [$tree selection get]

    foreach i $sel {
	set data [$tree itemcget $i -data]
	set type [lindex $data 0]
	if {$type == "platform"} { continue }
	if {[lsearch $types $type] > -1} { continue }
	upvar #0 $data var
	if {![info exists var]} { continue }
	set var 0
	$tree itemconfigure $i -image [GetImage folder16]
	Modified
    }
}

proc ::Tree::DropFiles { tree files } {
    set node [lindex [$tree selection get] 0]
    if {$node eq ""} { return }

    set id [$tree itemcget $node -data]
    if {[$id type] eq "filegroup"} {
        AddFiles -files [lsort $files]
    }
}

proc ::Tree::DragFiles { tree x y } {
    variable drag

    set node [$tree find @$x,$y]

    if {[info exists drag(node)] && ![string equal $drag(node) $node]} {
        after cancel $drag($drag(node))
    }

    if {[string length $node] && 
        (![info exists drag(node)] || ![string equal $drag(node) $node])} {
        set drag(node)  $node
        set drag($node) [after 500 [list $tree opentree $drag(node) 0]]
        set id [$tree itemcget $drag(node) -data]
        if {[$id type] eq "filegroup"} {
	    $tree selection set $drag(node)
	}
    }
    return default
}

proc ::InstallJammer::EditNewNode { widget args } {
    set node [eval $widget insert $args]
    $widget edit $node [$widget itemcget $node -text] \
        [list ::InstallJammer::FinishEditNewNode $widget $node]
    return $node
}

proc ::InstallJammer::FinishEditNewNode { widget node newtext } {
    if {[string equal [$widget itemcget $node -data] "actiongroup"]} {
        set n [::InstallJammer::FindActionGroup $widget $newtext]
        if {![lempty $n] && $n != $node} {
            ::InstallJammer::Error \
                -message "An Action Group with that name already exists."
            return 0
        }
    }

    $widget itemconfigure $node -text $newtext
    return 1
}

proc ::InstallJammer::Tree::AllNodes { tree {parent root} } {
    set nodes [list]
    foreach node [$tree nodes $parent] {
        lappend nodes $node
        eval lappend nodes [AllNodes $tree $node]
    }
    return $nodes
}

proc ::InstallJammer::Tree::Setup { setup tree } {
    global conf

    set canv [$tree getcanvas]

    $tree bindText  <ButtonRelease-1> \
        [list ::InstallJammer::Tree::SelectItem $tree]
    $tree bindImage <ButtonRelease-1> ::InstallJammer::SetActiveComponent

    $tree bindText  <Shift-1>   [list ::InstallJammer::Tree::SelectItem $tree 3]
    $tree bindImage <Shift-1>   [list ::InstallJammer::Tree::SelectItem $tree 3]
    $tree bindText  <Control-1> [list ::InstallJammer::Tree::SelectItem $tree 4]
    $tree bindImage <Control-1> [list ::InstallJammer::Tree::SelectItem $tree 4]

    $tree bindText  <Double-1>  [list ::InstallJammer::Tree::Toggle $tree]
    $tree bindImage <Double-1>  [list ::InstallJammer::Tree::Toggle $tree]

    set command [list ::InstallJammer::Tree::Popup $setup $tree %X %Y]
    $tree bindText  <Button-3> $command
    $tree bindImage <Button-3> $command

    bind $canv <F2>     [list ::InstallJammer::Tree::Rename $tree]
    bind $canv <Delete> [list ::InstallJammer::Tree::Delete $tree]

    set rc [MENU $tree.installtypeRightClick]
    $rc insert end command -label "Copy" \
        -compound left -image [GetImage editcopy16] \
        -command ::InstallJammer::EditCopy
    $rc insert end command -label "Paste" \
        -compound left -image [GetImage editpaste16] \
        -command ::InstallJammer::EditPaste
    $rc insert end separator
    $rc insert end cascade -label "Insert Pane  " \
        -compound left -image [GetImage displayscreen16]

    set rc [MENU $tree.paneRightClick]
    $rc insert end command -label "Copy" \
        -compound left -image [GetImage editcopy16] \
        -command ::InstallJammer::EditCopy
    $rc insert end command -label "Paste" \
        -compound left -image [GetImage editpaste16] \
        -command ::InstallJammer::EditPaste
    $rc insert end separator
    $rc insert end cascade -label "Insert Pane  " \
        -compound left -image [GetImage displayscreen16]
    $rc insert end cascade -label "Insert Action  " \
        -compound left -image [GetImage insertaction16]
    $rc insert end separator
    $rc insert end command -label "Delete Pane" \
        -compound left -image [GetImage buttoncancel16] \
        -command [list ::InstallJammer::Tree::Delete $tree]

    set rc [MENU $tree.actionRightClick]
    $rc insert end command -label "Copy" \
        -compound left -image [GetImage editcopy16] \
        -command ::InstallJammer::EditCopy
    $rc insert end command -label "Paste" \
        -compound left -image [GetImage editpaste16] \
        -command ::InstallJammer::EditPaste
    $rc insert end separator
    $rc insert end cascade -label "Insert Action  " \
        -compound left -image [GetImage insertaction16]
    $rc insert end separator
    $rc insert end command -label "Delete Action" \
        -compound left -image [GetImage buttoncancel16] \
        -command [list ::InstallJammer::Tree::Delete $tree]

    set rc [MENU $tree.actiongroupRightClick]
    $rc insert end command -label "Copy" \
        -compound left -image [GetImage editcopy16] \
        -command ::InstallJammer::EditCopy
    $rc insert end command -label "Paste" \
        -compound left -image [GetImage editpaste16] \
        -command ::InstallJammer::EditPaste
    $rc insert end separator
    $rc insert end cascade -label "Insert Action  " \
        -compound left -image [GetImage insertaction16]
    $rc insert end separator
    $rc insert end command -label "Delete Action Group" \
        -compound left -image [GetImage buttoncancel16] \
        -command [list ::InstallJammer::Tree::Delete $tree]

    set rc [MENU $tree.silentRightClick]
    $rc insert end command -label "Copy" \
        -compound left -image [GetImage editcopy16] \
        -command ::InstallJammer::EditCopy
    $rc insert end command -label "Paste" \
        -compound left -image [GetImage editpaste16] \
        -command ::InstallJammer::EditPaste
    $rc insert end separator
    $rc insert end cascade -label "Insert Action  " \
        -compound left -image [GetImage insertaction16]

    set rc [MENU $tree.actionGroupsRightClick]
    $rc insert end command -label "Copy" \
        -compound left -image [GetImage editcopy16] \
        -command ::InstallJammer::EditCopy
    $rc insert end command -label "Paste" \
        -compound left -image [GetImage editpaste16] \
        -command ::InstallJammer::EditPaste
    $rc insert end separator
    $rc insert end command -label "New Action Group" \
        -compound left -image [GetImage appwindow_list16] \
        -command [list ::InstallJammer::AddActionGroup $setup]
}

proc ::InstallJammer::Tree::Toggle { tree node } {
    variable double 1
    ::InstallJammer::SetActiveComponent $node
    after idle [list unset -nocomplain ::InstallJammer::Tree::double]
    $tree toggle $node
}

proc ::InstallJammer::Tree::SelectItem { args } {
    global conf

    variable select
    variable double

    if {[llength $args] == 2} {
        set which 1
        lassign $args tree node
    }  else {
        lassign $args tree which node
    }

    after cancel $conf(renameAfterId)

    if {$which == 3 && ![info exists select($tree)]} { set which 1 }

    if {$which == 1} {
        ## Single click.

        ::InstallJammer::SetActiveComponent $node

        if {[info exists double]} {
            unset double
            return
        }

        if {[info exists select($tree)] 
            && [string equal $select($tree) $node]} {
            set cmd [list ::InstallJammer::Tree::Rename $tree]
            set conf(renameAfterId) [after 800 $cmd]
        }

        set select($tree) $node
    } elseif {$which == 3} {
        ## Shift click

        set nodes [::InstallJammer::Tree::AllNodes $tree]

        set old  $select($tree)
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

        eval $tree selection set $items
    } elseif {$which == 4} {
        ## Control click.

	if {[lsearch -exact [$tree selection get] $node] > -1} {
            $tree selection remove $node
	} else {
            $tree selection add $node
	}
    }
}

proc ::InstallJammer::Tree::Rename { tree } {
    global widg

    set item [$tree selection get]
    set id   $item

    if {$tree eq $widg(FileGroupTree)} {
        set id [$tree itemcget $item -data]
    }

    set type [$id type]

    if {$tree eq $widg(FileGroupTree)
        || $tree eq $widg(ComponentTree)
        || $tree eq $widg(SetupTypeTree)} {
        set types [list filegroup component setuptype]
        if {[lsearch -exact $types $type] < 0} { return }
        set text  [$item name]
    } else {
        set types [list pane action actiongroup]
        if {[lsearch -exact $types $type] < 0} { return }
        set text  [$item title]
    }

    $tree edit $item $text [list ::InstallJammer::Tree::DoRename $tree $item]
}

proc ::InstallJammer::Tree::DoRename { tree item newtext } {
    global widg

    set oldtext [$tree itemcget $item -text]

    if {$newtext ne $oldtext} {
        $tree itemconfigure $item -text $newtext

        if {$tree eq $widg(FileGroupTree)} {
            ::FileGroupTree::rename $item $newtext
        } elseif {$tree eq $widg(ComponentTree)} {
            ::ComponentTree::rename $item $newtext
        } elseif {$tree eq $widg(SetupTypeTree)} {
            ::SetupTypeTree::rename $item $newtext
        } else {
            set alias   [$item alias]
            set default [::InstallJammer::GetDefaultTitle $item]
            if {$newtext ne $default && ($alias eq "" || $alias eq $oldtext)
                && [::InstallJammer::CheckAlias $item $newtext 0]} {
                $item alias $newtext
                ::InstallJammer::SetActiveProperty Alias $newtext
            }

            $item title $newtext

            ::InstallJammer::RefreshComponentTitles $item
        }

        Modified
    }

    focus $tree

    return 1
}

proc ::InstallJammer::Tree::Delete { tree {prompt 1} } {
    global widg

    if {$tree eq $widg(FileGroupTree)} {
        ::FileGroupTree::delete
    } elseif {$tree eq $widg(ComponentTree)} {
        ::ComponentTree::delete
    } elseif {$tree eq $widg(SetupTypeTree)} {
        ::SetupTypeTree::delete
    } else {
        set msg "Are you sure you want to delete the selected items?"
        if {$prompt && ![::InstallJammer::AskYesNo -message $msg]} { return }

        foreach node [$tree selection get] {
            if {[IsInstallType $tree $node]} { continue }
            set setup [$node setup]
            $tree delete $node
            $node destroy
            Modified
        }

        if {[info exists setup]} {
            unset -nocomplain ::InstallJammer::ActiveComponent
            unset -nocomplain ::InstallJammer::ActiveComponents($setup)
            ::InstallJammer::SetActiveComponent
        }
    }
}

proc ::InstallJammer::Tree::Popup { setup tree X Y item } {
    global conf
    global widg

    set type [$tree itemcget $item -data]

    if {$type eq "installtype"} {
        switch -glob -- $item {
            "Common*" - "Console*" - "Silent*" - "ActionGroups*" {
                set type [string range $item 0 end-[string length $setup]]
                set type [string tolower $type 0]
            }
        }
    }

    set menu $tree.${type}RightClick
    if {![winfo exists $menu]} { return }

    if {[llength [$tree selection get]] < 2} {
        $tree selection set $item
    }

    switch -- $type {
        "installtype" {
            $menu entryconfigure "Insert Pane  " -menu $widg(${setup}PanesMenu)
        }

        "pane" {
            $menu entryconfigure "Insert Pane  " -menu $widg(${setup}PanesMenu)
            $menu entryconfigure "Insert Action  " \
                -menu $widg(${setup}ActionsMenu)
        }

        "action" - "actiongroup" - "silent" {
            $menu entryconfigure "Insert Action  " \
                -menu $widg(${setup}ActionsMenu)
        }
    }

    $menu post $X $Y

    #if {!$conf(windows)} { tkwait window $menu }
}

proc ::InstallJammer::Tree::FinishOpenProject {} {
    global widg

    ## Walk the Install tree and open every empty pane.
    ## This lets us drag-and-drop actions into nodes that
    ## have no children.  The node must be open to allow this.
    set tree [$widg(Install) gettree]
    foreach root [$tree nodes root] {
        foreach node [$tree nodes $root] {
            if {![lempty [$tree nodes $node]]} { continue }
            $tree itemconfigure $node -open 1
        }
    }

    #set tree $widg(FileGroupTree)
    #foreach platform [$tree nodes root] {
        #foreach node [$tree nodes $platform] {
            #if {![lempty [$tree nodes $node]]} { continue }
            #$tree itemconfigure $node -open 1
        #}
    #}
}

proc ::InstallJammer::Tree::IsInstallType { tree node } {
    if {[string equal $node "root"] || ![$tree exists $node]} { return 0 }
    return [string equal [$tree itemcget $node -data] "installtype"]
}

proc ::InstallJammer::Tree::IsActionParent { tree node } {
    if {$node eq "root" || ![$tree exists $node]} { return 0 }

    set data [$tree itemcget $node -data]

    if {$data eq "pane" || $data eq "actiongroup"
        || [string match "Silent*" $node] || [string match "Console*" $node]} {
        return 1
    }

    return 0
}

proc ::InstallJammer::Tree::IsPaneParent { tree node } {
    if {[string equal $node "root"] || ![$tree exists $node]} { return 0 }

    if {[string match "Common*" $node]
        || [string match "Console*" $node]
        || [string match "Silent*" $node]
        || [$tree itemcget $node -data] ne "installtype"} { return 0 }

    return 1
}

proc ::InstallJammer::Tree::GetPaneParent { tree node } {
    if {![string length $node]} { return }

    set n $node
    set p [$tree parent $n]
    while {![IsInstallType $tree $n]} {
        if {[string equal $p "root"]} { return }
        set n $p
        set p [$tree parent $n]
    }

    ## Can't add a pane to Common or a Silent install or under Action Groups.
    switch -glob -- $n {
        "Common*" - "Console*" - "Silent*" - "ActionGroups*" { return }
    }

    return $n
}

proc ::InstallJammer::Tree::GetActionParent { tree node } {
    if {[lempty $node]} { return }

    set n $node
    set p [$tree parent $n]
    set d [$tree itemcget $n -data]
    while {![string equal $d "pane"]} {
        if {[IsActionParent $tree $n]} { return $n }
        set n $p
        set p [$tree parent $n]
        if {![$tree exists $p]} { return }
        set d [$tree itemcget $n -data]
    }

    return $n
}

proc ::InstallJammer::Tree::DragInit { tree node top } {
    set p [$tree parent $node]
    if {$p eq "root" && [$tree itemcget $node -data] ne "setuptype"} { return }

    global conf
    after cancel $conf(renameAfterId)

    return [list TREE_NODE {move} $node]
}

proc ::InstallJammer::Tree::DropNode { tree source nodeData op type node } {
    global widg

    ## This proc only handles drag-and-drop commands within itself.
    ## If the widget this came from is not our widget (minus the canvas),
    ## we don't want to do anything.  They need to handle this themselves.
    if {![string equal [winfo parent $source] $tree]} { return }

    if {[llength $nodeData] != 3} { return }

    set parent [lindex $nodeData 1]
    set index  [lindex $nodeData 2]
    set data   [$tree itemcget $node -data]

    set parentNode $parent

    switch -- $data {
        "pane" {
            if {![IsPaneParent $tree $parent]} { return }
        }

        "action" {
            if {![IsActionParent $tree $parent]} { return }
        }

        "component" {
            if {$parent eq "root"} { return }
        }

        "setuptype" {
            set parent     SetupTypes
            set parentNode root
        }
    }

    if {[catch { $tree move $parentNode $node $index } error]} { return }

    $node reparent $parent
    $parent children reorder [$tree nodes $parentNode]

    if {$data eq "component"} {
        ## Reorder the components in each setup type so that
        ## they display in the correct order during installation.

        set allComponents [Components children recursive]

        foreach setuptype [SetupTypes children] {
            set components [$setuptype get Components]
            if {[llength $components] > 1} {
                set newComponents {}
                foreach component $allComponents {
                    if {[lsearch -exact $components $component] > -1} {
                        lappend newComponents $component
                    }
                }
                $setuptype set Components $newComponents
            }
        }

        ## Clear the setup type component tree and rebuild
        ## it so that all of the components are shown in
        ## the correct order.

        set tree $widg(SetupTypeComponentTree)
        $tree clear

        foreach id [Components children recursive] {
            set text   [$id name]
            set parent [$id parent]
            if {$parent eq "Components"} { set parent "root" }

            $tree insert end $parent $id \
                -type checkbutton -open 1 -text $text \
                -variable ::SetupTypeTree::ComponentIncludes($id) \
                -command [list ::SetupTypeTree::SetComponentInclude $tree $id]
        }
    }

    Modified
}

proc ::InstallJammer::Tree::OpenSelectedNode { tree {recursive 0} } {
    foreach node [$tree selection get] {
        $tree opentree $node $recursive
    }
}

proc ::InstallJammer::Tree::CloseSelectedNode { tree {recursive 0} } {
    foreach node [$tree selection get] {
        $tree closetree $node $recursive
    }
}

proc ::InstallJammer::SetupPlatformProperties { id prop } {
    set include [$id platforms]
    set cmd ::InstallJammer::FinishEditPlatformNode
    foreach n [$prop nodes platforms] {
        set varName  [$prop itemcget $n -variable]
        set platform [$prop itemcget $n -data]
        $prop itemconfigure $n -editfinishcommand \
            [list $cmd $prop $id $n $varName]
        if {[lsearch -exact $include $platform] > -1} {
            set $varName Yes
        } else {
            set $varName No
        }
    }
}

proc ::InstallJammer::RefreshComponentTitles { {items {}} } {
    global widg

    if {![llength $items]} {
        foreach installtype [InstallTypes children] {
            eval lappend idlist [$installtype children recursive]
        }
    } else {
        set types  [list pane action actiongroup]
        set idlist [list]
        foreach id $items {
            if {[eval $id is $types]} { lappend idlist $id }
        }
    }

    foreach id $idlist {
        set title [$id title]
        if {[llength [$id conditions]]} { append title "*" }
        $widg([$id setup]) itemconfigure $id -text $title
    }
}
