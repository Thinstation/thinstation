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

namespace eval ::SetupTypeTree {
    variable tree  ""
    variable popup ""
}

proc ::SetupTypeTree::setup { tree } {
    $tree bindText  <Button-1>        "::SetupTypeTree::select 1"
    $tree bindImage <Button-1>        "::SetupTypeTree::select 1"
    $tree bindText  <ButtonRelease-1> "::SetupTypeTree::dorename"
    $tree bindImage <ButtonRelease-1> "::SetupTypeTree::dorename"
    $tree bindText  <Button-3>        "::SetupTypeTree::popup %X %Y"
    $tree bindImage <Button-3>        "::SetupTypeTree::popup %X %Y"

    ::FileTree::Setup $tree
}

proc ::SetupTypeTree::init {} {
    global widg

    variable tree $widg(SetupTypeTree)
    variable pref $widg(SetupTypePref)

    ::SetupTypeTree::Clear

    foreach id [SetupTypes children] {
	set node [::SetupTypeTree::New -id $id]
    }
}

proc ::SetupTypeTree::Clear {} {
    global widg

    variable pref
    variable ComponentIncludes

    if {![string length $pref]} { return }

    $pref selection clear

    eval $pref delete [$pref nodes root]

    set tree $widg(SetupTypeComponentTree)
    eval [list $tree delete] [$tree nodes root]
    unset -nocomplain ComponentIncludes
}

proc ::SetupTypeTree::New { args } {
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
        set id   [::InstallJammer::uuid]
        set text $data(-text)

        SetupType ::$id -name $text -parent SetupTypes

        if {![string length $text]} {
            set new  1
            set text "New Setup Type"
            ::InstallJammer::EditNewNode $pref end root $id \
                -text $text -image [GetImage setuptype16] -fill blue \
                -data setuptype -pagewindow $widg(SetupTypeDetails)
            set text [$pref itemcget $id -text]
            $id configure -name $text
            focus [$pref gettree]
        }

        $id platforms [AllPlatforms]
    } else {
        set text [$id name]
    }

    ::SetupTypeObject initialize $id Name $text

    if {!$new} {
        $pref insert end root $id -text $text -image [GetImage setuptype16] \
            -data setuptype -pagewindow $widg(SetupTypeDetails)
    } else {
        ::SetupTypeTree::select 1 $id
    }

    Modified

    return $id
}

proc ::SetupTypeTree::select { mode node } {
    global conf
    global info
    global widg

    variable tree
    variable pref

    after cancel $conf(renameAfterId)

    variable old [$tree selection get]

    $tree selection set $node
    ::SetupTypeTree::RaiseNode $node
}

proc ::SetupTypeTree::dorename { node } {
    variable old
    variable tree

    if {$node eq $old} {
        ## They're renaming the node.
        set text [$tree itemcget $node -text]
        set cmd  [list ::InstallJammer::Tree::DoRename $tree $node]
        set conf(renameAfterId) [after 800 [list $tree edit $node $text $cmd]]
        return
    }
}

proc ::SetupTypeTree::rename { id newtext } {
    variable tree
    variable ::InstallJammer::active

    $id name $newtext
    $id set Name $newtext

    set active(Name) $newtext
}

proc ::SetupTypeTree::delete {} {
    variable pref

    set ans [::InstallJammer::MessageBox -type yesno \
        -message "Are you sure you want to delete the selected setup types?"]
    if {$ans eq "no"} { return }

    foreach id [$pref selection get] {
        if {[$pref exists $id]} {
            $pref delete $id
            $id destroy
        }
    }
}

proc ::SetupTypeTree::popup { X Y item } {
    variable tree
    variable popup

    focus $tree

    $popup post $X $Y
    if {$::tcl_platform(platform) eq "unix"} { tkwait window $popup }
}

proc ::SetupTypeTree::RaiseNode { node } {
    global widg

    variable pref
    variable ComponentIncludes

    $pref raise $node
    set id $node

    set tree $widg(SetupTypeComponentTree)

    set include [$id get Components]
    foreach node [::InstallJammer::Tree::AllNodes $tree] {
        if {[lsearch -exact $include $node] > -1} {
            set ComponentIncludes($node) 1
        } else {
            set ComponentIncludes($node) 0
        }
    }

    ::InstallJammer::SetActiveComponent $id

    ::InstallJammer::SetupPlatformProperties $id $widg(SetupTypeDetailsProp)
}

proc ::SetupTypeTree::SetComponentInclude { tree node } {
    variable pref
    variable ComponentIncludes

    set setuptype [$pref raise]
    if {![string length $setuptype]} { return }

    set include [list]
    foreach node [::InstallJammer::Tree::AllNodes $tree] {
        if {$ComponentIncludes($node)} { lappend include $node }
    }

    $setuptype set Components $include

    if {$setuptype eq $::InstallJammer::ActiveComponent} {
        set ::InstallJammer::active(Components) $include
    }
}
