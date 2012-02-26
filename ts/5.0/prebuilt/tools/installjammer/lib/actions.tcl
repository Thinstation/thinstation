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

proc ::InstallJammer::LoadActions {} {
    global conf
    global preferences

    if {[string length $preferences(CustomActionDir)]} {
        set dir $preferences(CustomActionDir)
        lappend dirs $dir
        eval lappend dirs [glob -nocomplain -type d -dir $dir *]

    }

    set dir [file join $conf(lib) Actions]
    eval lappend dirs [glob -nocomplain -type d -dir $dir *]

    foreach dir $dirs {
        if {$dir eq $preferences(CustomActionDir)} {
            set group "Custom Actions"
        } else {
            set group [file tail $dir]
        }
        set name [::InstallJammer::StringToTitle $group]
        foreach file [glob -nocomplain -directory $dir *.action] {
            set ::InstallJammer::loadactions::group  $name
            set ::InstallJammer::loadactions::action ""

            catch {
                namespace eval ::InstallJammer::loadactions [read_file $file]
            }
        }
    }
}

proc ::InstallJammer::GetActions {} {
    variable actions
    set list [list]
    foreach action [lsort [array names actions]] {
        lappend list $actions($action)
    }
    return $list
}

proc ::InstallJammer::GetActionNames {} {
    set names [list]
    foreach action [::InstallJammer::GetActions] {
        lappend names [$action action]
    }
    return $names
}

proc ::InstallJammer::ActionList {} {
    variable ::InstallJammer::aliasmap

    foreach id [array names aliasmap] {
        if {[$id is action actiongroup]} {
            lappend list $aliasmap($id)
        }
    }

    return [lsort -unique $list]
}

proc ::InstallJammer::GetActionList { setup {activeOnly 0} } {
    set actions [list]
    foreach id [GetActionComponentList $setup $activeOnly] {
        set action [$id component]
        eval lappend actions $action [[$id object] includes]
    }

    return [lsort -unique $actions]
}

proc ::InstallJammer::GetActionComponentList { setup {activeOnly 0} } {
    set list [list]
    foreach id [GetComponentList $setup $activeOnly] {
        if {[$id is action]} { lappend list $id }
    }
    return $list
}

proc ::InstallJammer::GetRequiredPackages { {activeOnly 0} } {
    set list [list]
    foreach id [GetActionComponentList "" $activeOnly] {
        eval lappend list [[$id object] requires]
    }

    return [lsort -unique $list]
}

proc ::InstallJammer::AddAction { setup action args } {
    global widg

    variable ::InstallJammer::actions

    if {![info exists actions($action)]} {
        ## If we're trying to add an action that doesn't exist,
        ## it's probably because we no longer support the action.

        ## We need to destroy the object that references this action.
        array set _args $args
        if {[info exists _args(-id)]} { $_args(-id) destroy }

        return
    }

    set obj    $actions($action)
    set pref   $widg($setup)
    set sel    [lindex [$pref selection get] end]
    set index  end
    set parent [::InstallJammer::Tree::GetActionParent $pref $sel]

    set data(-id)     ""
    set data(-title)  [$obj title]
    set data(-parent) $parent
    array set data $args

    set id     $data(-id)
    set parent [::InstallJammer::ID $data(-parent)]

    if {$parent eq ""} {
        ::InstallJammer::Error -message "You cannot add an action here."
        return
    }

    set new 0
    if {$id eq ""} {
        set new 1

        if {$sel ne ""} {
            if {[$sel is action]} { set index [$pref index $sel] }
        }

	set id  [::InstallJammer::uuid]
        InstallComponent ::$id -parent $parent -index $index -setup $setup \
            -component $action -type action -title $data(-title)
    }

    $obj initialize $id

    if {$new} {
        set proc ::InstallJammer::actions::Insert.$action
        if {[::InstallJammer::CommandExists $proc]} { $proc $id }
    }

    if {[$pref exists $parent]} {
        $pref insert $index $parent $id \
            -text $data(-title) -data action -image [GetImage appwinprops16] \
            -createcommand [list ::InstallJammer::CreateActionFrame $id] \
            -fill [expr {$new ? "#0000FF" : "#000000"}]
    }

    Modified

    return $id
}

proc ::InstallJammer::CreateActionFrame { id } {
    global widg
    
    variable actions

    set setup  [$id setup]
    set action [$id component]

    if {$action eq "AddWidget"} {
        return [::InstallJammer::CreateAddWidgetActionFrame $id]
    }

    set obj  $actions($action)
    set pref $widg($setup)

    set frame [$pref getframe $id]

    if {[winfo exists $frame.sw]} { return }

    ScrolledWindow $frame.sw -scrollbar vertical
    pack $frame.sw -expand 1 -fill both

    set prop [PROPERTIES $frame.sw.p]
    $frame.sw setwidget $frame.sw.p

    $prop insert end root standard -text "Standard Properties" -open 1

    if {[llength [$obj properties 0]]} {
        $prop insert end root advanced -text "Advanced Properties" -open 0
    }

    $obj addproperties $prop $id

    if {[llength [$obj textfields]]} {
        $prop insert end root text -text "Text Properties"
        $obj addtextfields $prop text $id
    }
}

proc ::InstallJammer::CreateAddWidgetActionFrame { id } {
    global widg
    
    variable actions

    set setup  [$id setup]
    set action [$id component]

    set obj  $actions($action)
    set pref $widg($setup)

    set frame [$pref getframe $id]

    if {[winfo exists $frame.sw]} { return }

    ScrolledWindow $frame.sw -scrollbar vertical
    pack $frame.sw -expand 1 -fill both

    set prop [PROPERTIES $frame.sw.p]
    $frame.sw setwidget $frame.sw.p

    $prop insert end root standard -text "Standard Properties" -open 1
    $obj addproperties $prop $id -advanced 0

    set appearance {Background Foreground Height LabelJustify LabelSide
                    LabelWidth Type Width X Y}
    $prop insert end root appearance -text "Widget Properties" -open 0
    $obj addproperties $prop $id -properties $appearance -parentnode appearance

    $prop insert end root advanced -text "Advanced Properties" -open 0
    foreach property [$obj properties 0] {
        if {[lsearch -exact $appearance $property] > -1} { continue }
        $obj addproperties $prop $id -properties $property -parentnode advanced
    }

    $prop insert end root text -text "Text Properties"
    $obj addtextfields $prop text $id

    BUTTON $frame.preview -text "Preview Pane" -width 18 \
        -command [list ::InstallJammer::PreviewWindow $id]
    pack $frame.preview -side bottom -anchor se -pady 2

    ::InstallJammer::ConfigureAddWidgetFrame $id [$id get Type]
}

proc ::InstallJammer::ConfigureAddWidgetFrame { id {type ""} } {
    global widg
    
    variable actions

    set setup  [$id setup]
    set action [$id component]

    set obj  $actions($action)
    set pref $widg($setup)

    set frame [$pref getframe $id]
    set prop  $frame.sw.p

    if {![winfo exists $frame.sw]} { return }

    array set props {
        "button"         {Action}
        "browse entry"   {Action BrowseType FileTypes ValidateEntryOn
                          Value VirtualText}
        "checkbutton"    {Action Checked OffValue OnValue VirtualText}
        "combobox"       {Action Editable ValidateEntryOn Value Values
                          VirtualText}
        "entry"          {Action ValidateEntryOn Value VirtualText}
        "label"          {}
        "label frame"    {}
        "password entry" {Action ValidateEntryOn Value VirtualText}
        "radiobutton"    {Action Checked Value VirtualText}
        "text"           {Value VirtualText}
    }

    if {$type eq ""} { set type $::InstallJammer::active(Type) }
    set properties $props($type)

    if {![llength $properties]} {
        $prop itemconfigure advanced -state hidden
    } else {
        $prop itemconfigure advanced -state normal
        foreach node [$prop nodes advanced] {
            set type [$prop itemcget $node -data]
            if {[lsearch -exact $properties $type] < 0} {
                $prop itemconfigure $node -state hidden
            } else {
                $prop itemconfigure $node -state normal
            }
        }
    }
}

proc ::InstallJammer::AddActionGroup { setup args } {
    global widg

    set pref $widg($setup)

    array set data {
        -id     ""
        -edit   1
        -title  "New Action Group"
    }
    set data(-parent) "ActionGroups$setup"
    array set data $args

    set id     $data(-id)
    set parent $data(-parent)

    set new 0
    if {![string length $id]} {
        set new 1

	set id [::InstallJammer::uuid]
        InstallComponent ::$id -parent $parent \
            -setup $setup -type actiongroup -active 1
    }

    ::ActionGroupObject initialize $id

    if {$data(-edit)} {
        $pref open $data(-parent)
        set cmd [list ::InstallJammer::EditNewNode $pref]
    } else {
        set cmd [list $pref insert]
    }

    set open $new
    if {[info exists data(-open)]} { set open $data(-open) }

    eval $cmd [list end $parent $id -open $open \
        -text $data(-title) -data actiongroup \
        -image [GetImage appwindow_list16] \
        -createcommand [list ::InstallJammer::CreateActionGroupFrame $id]]

    set title [$pref itemcget $id -text]

    $id title $title

    Modified

    return $id
}

proc ::InstallJammer::CreateActionGroupFrame { id } {
    global widg
    
    variable actions

    set setup  [$id setup]
    set action [$id component]

    set pref $widg($setup)

    set frame [$pref getframe $id]

    if {[winfo exists $frame.sw]} { return }

    ScrolledWindow $frame.sw -scrollbar vertical
    pack $frame.sw -expand 1 -fill both

    set prop [PROPERTIES $frame.sw.p]
    $frame.sw setwidget $frame.sw.p

    set obj [$id object]

    $prop insert end root standard -text "Standard Properties" -open 1
    $obj addproperties $prop $id
}

proc ::InstallJammer::FindActionGroup { tree text } {
    foreach node [$tree nodes root] {
        set d [$tree itemcget $node -data]
        if {![string equal $d "actiongroup"]} { continue }
        set t [$tree itemcget $node -text]
        if {[string equal $t $text]} { return $node }
    }
}

proc ::InstallJammer::loadactions::Action { name {title ""} } {
    variable group
    variable action
    variable ::InstallJammer::actions

    if {[info exists actions($name)]} {
        return -code error "Action $name already exists"
    }

    if {$title eq ""} {
        set title [::InstallJammer::StringToTitle $name]
    }

    set action [::InstallJammer::Action ::#auto -title $title \
        -name $name -group $group]
}

proc ::InstallJammer::loadactions::Property { args } {
    variable action
    eval $action property $args
}

proc ::InstallJammer::loadactions::Text { args } {
    variable action
    lassign $args name pretty subst
    if {![string length $subst]}  { set subst 1 }
    if {![string length $pretty]} { set pretty $name }
    $action text $name $pretty $subst
}

proc ::InstallJammer::loadactions::Help { property text } {
    variable action
    $action help $property $text
}

proc ::InstallJammer::loadactions::Condition { name args } {
    variable action
    $action condition $action $name $args
}

proc ::InstallJammer::loadactions::Include { args } {
    variable action
    eval $action includes $args
}

proc ::InstallJammer::loadactions::Require { args } {
    variable action
    eval $action requires $args
}

proc ::InstallJammer::loadactions::Group { groupName } {
    variable action

    variable group [::InstallJammer::StringToTitle $groupName]

    if {$action ne ""} { $action group $group }
}
