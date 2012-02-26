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

proc ::InstallJammer::LoadConditions {} {
    global conf
    global preferences

    if {[string length $preferences(CustomConditionDir)]} {
        set dir $preferences(CustomConditionDir)
        lappend dirs $dir
        eval lappend dirs [glob -nocomplain -type d -dir $dir *]
    }

    set dir [file join $conf(lib) Conditions]
    eval lappend dirs [glob -nocomplain -type d -dir $dir *]

    foreach dir $dirs {
        if {$dir eq $preferences(CustomConditionDir)} {
            set group "Custom Conditions"
        } else {
            set group [file tail $dir]
        }
        set name [::InstallJammer::StringToTitle $group]
        foreach file [glob -nocomplain -directory $dir *.condition] {
            set ::InstallJammer::loadconditions::group     $name
            set ::InstallJammer::loadconditions::condition ""
            catch {
                namespace eval ::InstallJammer::loadconditions [read_file $file]
            }
        }
    }
}

proc ::InstallJammer::loadconditions::Condition { name {title ""} } {
    variable group
    variable condition
    variable ::InstallJammer::conditions

    if {[info exists conditions($name)]} {
        return -code error "Condition $name already exists"
    }

    if {![string length $title]} {
        set title [::InstallJammer::StringToTitle $name]
    }

    set condition [::InstallJammer::Condition ::#auto \
        -title $title -name $name -group $group]
}

proc ::InstallJammer::loadconditions::Property { args } {
    variable condition
    eval $condition property $args
}

proc ::InstallJammer::loadconditions::Text { args } {
    variable condition
    lassign $args name pretty subst
    if {![string length $subst]}  { set subst 1 }
    if {![string length $pretty]} { set pretty $name }
    $condition text $name $pretty $subst
}

proc ::InstallJammer::loadconditions::Help { property text } {
    variable condition
    $condition help $property $text
}

proc ::InstallJammer::loadconditions::Group { groupName } {
    variable condition
    variable group [::InstallJammer::StringToTitle $groupName]
    if {$condition ne ""} { $condition group $group }
}

proc ::InstallJammer::loadconditions::Include { args } {
    variable condition
    eval $condition includes $args
}

proc ::InstallJammer::ConditionsWizard { id } {
    global conf
    global widg
    global preferences

    variable ::InstallJammer::conditiongroups

    variable ::InstallJammer::conditions::top
    variable ::InstallJammer::conditions::prop
    variable ::InstallJammer::conditions::listbox
    variable ::InstallJammer::conditions::afterId ""
    variable ::InstallJammer::conditions::operator
    variable ::InstallJammer::conditions::currentTree $conf(TreeFocus)

    set top [::InstallJammer::TopName .conditionsWizard]

    if {$id eq "active"} { set id $::InstallJammer::ActiveComponent }

    set ::InstallJammer::conditions::id $id

    if {[$id operator] eq "OR"} {
        set operator "Match any of the following"
    } else {
        set operator "Match all of the following"
    }

    if {![winfo exists $top]} {
        StandardDialog $top -title "Conditions for [$id title]" \
            -parent $widg(InstallJammer) -applybutton 0 -cancelbutton 0
        wm protocol $top WM_DELETE_WINDOW [list $top ok]

        bind $top <<DialogEnd>> {
            ::InstallJammer::conditions::CloseWindow
        }

        set frame [$top getframe]

        frame $frame.buttons
        pack  $frame.buttons -anchor w

        WinMenuButton $frame.buttons.new -image [GetImage foldernew16] \
            -menu $frame.buttons.new.menu
        pack $frame.buttons.new -side left
        DynamicHelp::add $frame.buttons.new -text "Add New Condition"

        WinButton $frame.buttons.delete -image [GetImage buttoncancel16] \
            -command ::InstallJammer::conditions::DeleteCondition
        pack $frame.buttons.delete -side left -padx 2
        DynamicHelp::add $frame.buttons.delete -text "Delete Condition"

        set menu [menu $frame.buttons.new.menu]

        $menu add cascade -label "All Conditions" -menu $menu.all
        MENU $menu.all

        set command ::InstallJammer::conditions::AddCondition

        foreach group [lsort [array names conditiongroups]] {
            set m    [menu $menu.[NewNode]]
            set text "[::InstallJammer::StringToTitle $group]   "
            $menu add cascade -label $text -menu $m
            foreach condition $conditiongroups($group) {
                set allconditions([$condition condition]) $condition
                $m add command -label [$condition title] \
                    -command [list $command [$condition condition]]
            }
        }

        foreach condition [lsort [array names allconditions]] {
            $menu.all add command -label [$allconditions($condition) title] \
                -command [list $command $condition]
        }

        ttk::combobox $frame.buttons.match -width 25 -state readonly \
            -textvariable ::InstallJammer::conditions::operator \
            -values {"Match all of the following" "Match any of the following"}
        pack $frame.buttons.match -side left -padx 5
        bind $frame.buttons.match <<ComboboxSelected>> \
            ::InstallJammer::conditions::ChangeConditionOperator

        PANEDWINDOW $frame.pw
        pack $frame.pw -expand 1 -fill both

        ScrolledWindow $frame.sw

        $frame.pw add $frame.sw -width 200 -stretch never

        set listbox $frame.list
        LISTBOX $listbox -padx 0 -dragenabled 1 -dropenabled 1
        $frame.sw setwidget $listbox

        set widg(ConditionsListBox) $listbox

        bind $listbox <FocusIn>  { set ::conf(TreeFocus) %W }
        bind $listbox <FocusOut> { set ::conf(TreeFocus) "" }

        $listbox bindText  <1> ::InstallJammer::conditions::RaiseConditionNode
        $listbox bindImage <1> ::InstallJammer::conditions::RaiseConditionNode

        set canvas [$listbox getcanvas]
        bind $canvas <F2>     ::InstallJammer::conditions::Rename
        bind $canvas <Delete> ::InstallJammer::conditions::DeleteConditions
        bind $canvas <B1-Motion> {
            after cancel $::InstallJammer::conditions::afterId
        }

        set propframe [$frame.pw add]

        set prop [PROPERTIES $propframe.prop]
        pack $prop -expand 1 -fill both

        $prop insert end root standard -text "Standard Properties" -open 1

        $prop insert end root advanced -text "Advanced Properties" -open 1

        $prop insert end root text -text "Text Properties" -open 1
    }

    set conf(TreeFocus) $widg(ConditionsListBox)

    $prop itemconfigure standard -state hidden
    $prop itemconfigure advanced -state hidden
    $prop itemconfigure text     -state hidden

    eval [list $listbox delete] [$listbox items]

    set conditions [$id conditions]
    foreach condition $conditions {
        $listbox insert end $condition -text [$condition title] -data $condition
    }

    if {[llength $conditions]} {
        ::InstallJammer::conditions::RaiseConditionNode [lindex $conditions 0]
    }

    set geometry [::InstallJammer::GetWindowGeometry conditions 600x400]
    $top configure -geometry $geometry

    after 0 [list $top draw]
    return 0
}

proc ::InstallJammer::conditions::Rename {} {
    variable listbox

    set node [$listbox selection get]
    set text [$listbox itemcget $node -text]

    $listbox edit $node $text [list ::InstallJammer::conditions::DoRename $node]
}

proc ::InstallJammer::conditions::DoRename { node newtext } {
    variable listbox
    $listbox itemconfigure $node -text $newtext
    $node title $newtext
    Modified
    return 1
}

proc ::InstallJammer::conditions::SaveConditionProperties {} {
    variable active
    variable ActiveCondition

    if {![info exists ActiveCondition]} { return }

    set id $ActiveCondition

    if {![::InstallJammer::ObjExists $id]} { return }

    set obj [$id object]

    set props [list]
    foreach [list prop value] [array get active] {
        if {$prop ne "ID" && $prop ne "Component"} {
            lappend props $prop $value
        }
    }

    foreach prop [$obj textfields] {
        lappend props $prop,subst $active($prop,subst)
    }

    eval [list ::InstallJammer::SetObjectProperties $id] $props
}

proc ::InstallJammer::conditions::RaiseConditionNode { node } {
    global conf

    variable prop
    variable active
    variable afterId
    variable listbox
    variable ActiveCondition

    set id [$listbox itemcget $node -data] 

    if {[info exists afterId]} { after cancel $afterId }

    if {[info exists ActiveCondition]} {
        SaveConditionProperties

        if {$id == $ActiveCondition} {
            set afterId [after 800 ::InstallJammer::conditions::Rename]
            return
        }
    }

    $listbox selection set $node

    set ActiveCondition $id

    set obj [$id object]

    eval [list $prop delete] [$prop nodes standard] \
        [$prop nodes advanced] [$prop nodes text]

    unset -nocomplain active

    foreach property [$obj properties] {
        set active($property) [::InstallJammer::GetObjectProperty $id $property]
    }

    foreach property [$obj textfields] {
        set text  [::InstallJammer::GetText $id $property -subst 0 -label 1]
        set subst [::InstallJammer::GetObjectProperty $id $property,subst]
        set active($property)       $text
        set active($property,subst) $subst
    }

    set active(ID) $id
    set active(Component) [[$id object] title]

    $prop itemconfigure standard -state normal

    if {![llength [$prop nodes standard]]} {
        $obj addproperties $prop condition -advanced 0 \
            -array ::InstallJammer::conditions::active
    }

    foreach n [$prop nodes standard] {
        if {[$prop itemcget $n -data] eq "CheckCondition"} {
            if {[$::InstallJammer::conditions::id ispane]} {
                $prop itemconfigure $n -values $conf(PaneCheckConditions)
            } else {
                $prop itemconfigure $n -values $conf(ActionCheckConditions)
            }
            break
        }
    }

    if {![llength [$obj properties 0]]} {
        $prop itemconfigure advanced -state hidden
    } else {
        $prop itemconfigure advanced -state normal

        $obj addproperties $prop condition -standard 0 -advanced 1 \
            -array ::InstallJammer::conditions::active
    }

    if {![llength [$obj textfields]]} {
        $prop itemconfigure text -state hidden
    } else {
        $prop itemconfigure text -state normal
        $obj addtextfields $prop text $id ::InstallJammer::conditions::active
    }
}

proc ::InstallJammer::conditions::AddCondition { condition } {
    variable id
    variable listbox

    variable ::InstallJammer::conditions

    set obj $conditions($condition)

    set idx end
    #set sel [$listbox selection get] 
    #if {[string length $sel]} { set idx [$listbox index $sel] }

    set cid [::InstallJammer::AddCondition $condition -parent $id -index $idx]
}

proc ::InstallJammer::conditions::DeleteCondition {} {
    variable id
    variable top
    variable prop
    variable listbox

    set sel [$listbox selection get]

    if {![llength $sel]} { return }

    if {![::InstallJammer::AskYesNo -parent $top \
        -message "Are you sure you want to delete the selected conditions?"]} {
        return
    }

    foreach cid $sel {
        $cid destroy
    }

    eval [list $listbox delete] $sel

    foreach node [$prop nodes root] {
        $prop itemconfigure $node -state hidden
    }

    ::InstallJammer::SetActiveComponentConditions
    ::InstallJammer::RefreshComponentTitles $id

    Modified
}

proc ::InstallJammer::conditions::ChangeConditionOperator {} {
    variable id
    variable operator

    if {$operator eq "Match all of the following"} {
        $id operator "AND"
    } elseif {$operator eq "Match any of the following"} {
        $id operator "OR"
    } else {
        return -code error "bad operator $operator"
    }
}

proc ::InstallJammer::conditions::CloseWindow {} {
    global conf
    global preferences

    variable id
    variable top
    variable listbox

    set preferences(Geometry,conditions) [wm geometry $top]

    ::InstallJammer::conditions::SaveConditionProperties
    unset -nocomplain ::InstallJammer::conditions::ActiveCondition

    $id conditions reorder [$listbox items]

    set conf(TreeFocus) $::InstallJammer::conditions::currentTree
}

proc ::InstallJammer::AddCondition { condition args } {
    global widg

    variable ::InstallJammer::conditions

    if {![info exists conditions($condition)]} {
        ## If we're trying to add an condition that doesn't exist,
        ## it's probably because we no longer support the condition.

        ## We need to destroy the object that references this condition.
        array set _args $args
        if {[info exists _args(-id)]} { $_args(-id) destroy }

        return
    }

    set obj $conditions($condition)

    array set _args {
        -id     ""
        -index  end
        -title  ""
        -parent ""
    }
    set _args(-title) [$obj title]
    array set _args $args

    set cid    $_args(-id)
    set parent $_args(-parent)

    if {$parent eq ""} {
        set parent $::InstallJammer::conditions::id
    }

    if {$cid eq ""} {
        set cid [::InstallJammer::uuid]
        $parent conditions insert $_args(-index) $cid
        ::Condition ::$cid -parent $parent -component $condition \
            -title $_args(-title)

        if {[$parent is action actiongroup]} {
            $cid set CheckCondition "Before Action is Executed"
        }
    }

    $obj initialize $cid

    Modified

    ::InstallJammer::RefreshComponentTitles $parent

    if {[info exists widg(ConditionsListBox)]
        && [winfo viewable $widg(ConditionsListBox)]} {
        $widg(ConditionsListBox) insert end $cid \
                -text [$obj title] -data $cid -fill blue
        ::InstallJammer::SetActiveComponentConditions
    }

    return $cid
}

proc ::InstallJammer::GetActiveCondition {} {
    if {[info exists ::InstallJammer::conditions::ActiveCondition]} {
        return $::InstallJammer::conditions::ActiveCondition
    }
}

proc ::InstallJammer::SetActiveComponentConditions {} {
    variable active

    set id  [::InstallJammer::GetActiveComponent]
    set len [llength [$id conditions]]
    set active(Conditions) "$len condition[expr {$len != 1 ? "s" : ""}]"
}
