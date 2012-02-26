proc ::InstallJammer::EditGetSelectedItems {} {
    global conf
    global widg

    set tree $conf(TreeFocus)
    if {$tree eq ""} { return }

    set items [list]

    if {$tree eq $widg(FileGroupTree)} {

    } elseif {$tree eq $widg(ComponentTree)} {

    } elseif {$tree eq $widg(SetupTypeTree)} {

    } elseif {$tree eq $widg(InstallTree) || $tree eq $widg(UninstallTree)} {
        foreach node [$tree selection get] {
            if {![::InstallJammer::Tree::IsInstallType $tree $node]} {
                lappend items $node
            }
        }
    } elseif {[info exists widg(ConditionsListBox)]
                && $tree eq $widg(ConditionsListBox)} {
        set items [$tree selection get]
    }

    return $items
}

proc ::InstallJammer::EditGetSetup {} {
    global conf
    global widg

    set tree $conf(TreeFocus)
    if {$tree eq $widg(InstallTree)} { return "Install" }
    if {$tree eq $widg(UninstallTree)} { return "Uninstall" }
}

proc ::InstallJammer::EditGetTree {} {
    global conf
    global widg

    set tree $conf(TreeFocus)

    if {$tree eq $widg(FileGroupTree)
        || $tree eq $widg(ComponentTree)
        || $tree eq $widg(SetupTypeTree)
        || $tree eq $widg(InstallTree)
        || $tree eq $widg(UninstallTree)
        || ([info exists widg(ConditionsListBox)]
                && $tree eq $widg(ConditionsListBox))} {
        if {[winfo viewable $tree]} { return $tree }
    }
}

proc ::InstallJammer::EditCut {} {
    if {$::edit::widget ne ""} {
        #return [::edit::cut $::edit::widget]
        return
    }

    set tree [::InstallJammer::EditGetTree]

    if {$tree ne ""} {
        ::InstallJammer::EditCopy
        ::InstallJammer::Tree::Delete $tree 0
    }
}

proc ::InstallJammer::EditCopy {} {
    global conf

    if {$::edit::widget ne ""} {
        #return [::edit::copy $::edit::widget]
        return
    }

    set tree [::InstallJammer::EditGetTree]

    if {$tree ne ""} {
        set list [list ##IJCV1##]
        foreach item [::InstallJammer::EditGetSelectedItems] {
            lappend list [::InstallJammer::DumpObject $item]
        }
        clipboard clear
        clipboard append $list
    }
}

proc ::InstallJammer::EditPaste {} {
    global conf

    if {$::edit::widget ne ""} {
        #return [::edit::paste $::edit::widget]
        return
    }

    set tree [::InstallJammer::EditGetTree]

    if {$tree ne ""} {
        set setup [::InstallJammer::EditGetSetup]

        if {[catch {clipboard get} list]} { return }
        if {[lindex $list 0] ne "##IJCV1##"} { return }
        foreach list [lrange $list 1 end] {
            ::InstallJammer::CreateComponentFromDump $setup $list
        }
    }
}

proc ::InstallJammer::EditDelete {} {
    if {$::edit::widget ne ""} {
        #return [::edit::delete $::edit::widget]
        return
    }

    set tree [::InstallJammer::EditGetTree]

    if {$tree ne ""} {
        ::InstallJammer::Tree::Delete $tree 0
    }
}

proc ::InstallJammer::EditSelectAll {} {
    set widget $::edit::widget
    if {$widget eq ""} { set widget [focus] }
    return [::edit::selectall $widget]
}
