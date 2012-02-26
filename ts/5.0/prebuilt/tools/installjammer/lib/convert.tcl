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

proc ConvertTheme {} {
    global conf
    global info

    ::InstallJammer::LoadThemeConfig theme

    ## If the version is the same or higher, we don't need to do anything.
    if {$info(ThemeVersion) >= $theme(Version)} { return 0 }

    set msg    "The theme for this install has been updated.\n"
    append msg "Would you like to restore the install theme to take "
    append msg "advantage of new features?"
    set ans [tk_messageBox -type yesno -title "Theme Updated" -message $msg]

    if {$ans eq "no"} { return 0 }

    set info(ThemeVersion) $theme(Version)
    RestoreTheme -noload

    return 1
}

proc ConvertProject {} {
    global conf
    global info

    variable ::InstallJammer::Properties

    set modified 0

    if {$info(ProjectVersion) eq "0.9.1.0"} {
        if {$conf(cmdline)} { return 1 }

        ## 1.0a1
        ##
        ## SetupFile class was removed in favor of using File.
        ##    This will be handled by the SetupFile proc defined below.
        ##
        ## ModifyButton action was removed in favor of ModifyWidget.
        ##
        ## File Group handling of directories was changed.

        Status "Converting project from 1.0a1..."
        update

        incr modified

        ## Convert ModifyButton actions to ModifyWidget.
        foreach id [itcl::find object -class InstallComponent] {
            if {[$id component] eq "ModifyButton"} {
                $id component ModifyWidget
                set button [$id get Button]
                $id set Widget "$button Button"
            }
        }

        ## Handle File Group changes.  Each directory that is a
        ## direct child of a file group must be removed and all of
        ## their subdirectories moved up a level.
        foreach group [FileGroups children] {
            foreach parent [$group children] {
                if {[$parent is dir]} {
                    ::InstallJammer::RecursiveGetFiles $parent
                    foreach id [$parent children] {
                        $id reparent $group
                    }
                    $parent destroy
                }
            }
        }
        
        set info(ProjectVersion) "0.9.2.0"
    }

    if {$info(ProjectVersion) eq "0.9.2.0"} {
        if {$conf(cmdline)} { return 1 }

        ## 1.0b1
        ##
        ## Multi-language support was added.  We need to update all of
        ## the text in the project.

        Status "Converting project from 1.0b1..."
        update

        incr modified

        set resetText [::InstallJammer::MessageBox \
            -type yesno -title "Converting Project" \
            -message "Your project must be converted to the new version of\
                InstallJammer.\nDo you want to convert all of your text\
                to the new version?\nWithout this change, your project will\
                not support the new multi-language features properly."]

        ## Remove variables that are no longer used.
        unset -nocomplain info(UseVersions)
        unset -nocomplain info(PaneList,install)
        unset -nocomplain info(PaneList,uninstall)

        ## Anything in VirtualTextData needs to be set in
        ## the info array, and then we need to get rid of
        ## the VirtualTextData variable.  Virtual text is
        ## now all stored in message catalogs.
        if {[info exists info(VirtualTextData)]} {
            array set info $info(VirtualTextData)
            unset info(VirtualTextData)
        }

        set map [list]
        lappend map <%FileBeingInstalledText%> <%Status%>
        lappend map <%FileBeingUninstalledText%> <%Status%>

        ## Load the engligh message catalog into an array
        ## and then clear it.  We're going to rebuild it.
        array set msgs [::msgcat::mcgetall en]
        ::msgcat::mcclear en

        ## Walk through all of the InstallComponents and map
        ## their properties.  Some components need to have their
        ## text properties converted to advanced properties.
        foreach id [itcl::find object -class InstallComponent] {
            foreach var [array names Properties $id,*] {
                set Properties($var) [string map $map $Properties($var)]
                if {$resetText} {
                    if {[string match *Button*,subst $var]} {
                        set Properties($var) 1
                    }
                }
            }

            switch -- [$id component] {
                "ExecuteAction" {
                    ## Remove the Execute Action actions that
                    ## refer to Startup Actions.  Startup Actions
                    ## are automatically executed by InstallJammer now.
                    if {[$id get Action] eq "Startup Actions"} {
                        $id destroy
                    }
                }

                "ExecuteScript" {
                    ## Convert the tcl script from a text property
                    ## to a regular property.
                    if {[info exists msgs($id,TclScript)]} {
                        $id set TclScript $msgs($id,TclScript)
                        unset msgs($id,TclScript)
                    }
                }

                "ExecuteExternalProgram" {
                    ## Convert the command line from a text property
                    ## to a regular property.
                    if {[info exists msgs($id,ProgramCommandLine)]} {
                        $id set ProgramCommandLine $msgs($id,ProgramCommandLine)
                        unset msgs($id,ProgramCommandLine)
                    }
                }

                "Exit" {
                    ## The Exit actions that are part of the silent
                    ## installs need to be a Finish exit.
                    if {[string match "Silent*" [$id parent]]} {
                        $id set ExitType Finish
                    }
                }
            }
        }

        ## Walk through all of the conditions and look for ones
        ## that were modified in this release.  We need to change
        ## their text properties to advanced properties.
        foreach id [itcl::find objects -class Condition] {
            switch -- [$id component] {
                "ScriptCondition" {
                    if {[info exists msgs($id,Script)]} {
                        $id set Script $msgs($id,Script)
                        unset msgs($id,Script)
                    }
                }

                "StringEqualCondition" {
                    if {[info exists msgs($id,String1)]} {
                        $id set String1 $msgs($id,String1)
                        unset msgs($id,String1)
                    }

                    if {[info exists msgs($id,String2)]} {
                        $id set String2 $msgs($id,String2)
                        unset msgs($id,String2)
                    }
                }

                "StringMatchCondition" {
                    if {[info exists msgs($id,String)]} {
                        $id set String $msgs($id,String)
                        unset msgs($id,String)
                    }

                    if {[info exists msgs($id,Pattern)]} {
                        $id set Pattern $msgs($id,Pattern)
                        unset msgs($id,Pattern)
                    }
                }
            }
        }

        ## Walk through all of the strings in the english message
        ## catalog and map them all.  Any that we've converted
        ## have been removed from the array, so they won't be in
        ## the new message catalog.
        if {!$resetText} {
            foreach var [array names msgs] {
                ::msgcat::mcset en $var [string map $map $msgs($var)]
            }
        } else {
            ::InstallJammer::LoadMessages
        }

        set info(ProjectVersion) "0.9.3.0"
    }

    if {[package vcompare $info(ProjectVersion) 1.1.0.1] < 0} {
        if {$conf(cmdline)} { return 1 }

        ## 1.1b1
        ##
        ## Added the new command-line options, so we need to setup
        ## the default options for a 1.0 project.

        ## Walk through all of the conditions on our actions and
        ## set their CheckCondition property.  Previously, conditions
        ## on actions were only checked before the action was executed.
        ##
        ## We also want to check panes to see if we need to add our new
        ## Populate actions.  Previously, these panes were auto-populated
        ## by code in the pane itself.  That code has been broken out into
        ## actions instead.

        Status "Converting project to version 1.1b1..."
        update

        incr modified

        foreach id [itcl::find objects -class InstallComponent] {
            if {[$id is action]} {
                foreach cid [$id conditions] {
                    $cid set CheckCondition "Before Action is Executed"
                }
            } elseif {$info(Theme) eq "Modern_Wizard" && [$id ispane]} {
                ## Add the new Populate Components and Populate Setup Types
                ## actions to the correct panes.
                if {[$id component] eq "SetupType"} {
                    ::InstallJammer::AddAction [$id setup] PopulateSetupTypes \
                        -parent $id
                } elseif {[$id component] eq "ChooseComponents"} {
                    ::InstallJammer::AddAction [$id setup] PopulateComponents \
                        -parent $id
                }
            }
        }

        ## We now save files without their full paths, so we want to
        ## alter the names of each file that is not a direct child
        ## of a filegroup.

        foreach file [itcl::find objects -class File] {
            if {![[$file parent] is filegroup]} {
                $file name [file tail [$file name]]
            }
        }

        ## Add the new default command-line options plus the old ones
        ## to keep compatibility.

        ::InstallJammer::AddDefaultCommandLineOptions

        array set ::InstallJammer::InstallCommandLineOptions {
            D { {} Prefix No No {}
                "set the value of an option in the installer"
            }

            S { InstallMode Switch No No "Silent"
                "run the installer in silent mode"
            }

            T { Testing Switch Yes No {}
                "run installer without installing any files"
            }

            Y { InstallMode Switch No No "Default"
                "accept all defaults and run the installer"
            }
        }

        array set ::InstallJammer::UninstallCommandLineOptions {
            S { UninstallMode Switch No No "Silent"
                "run the uninstaller in silent mode"
            }

            Y { UninstallMode Switch No No "Default"
                "accept all defaults and run the uninstaller"
            }
        }

        ## 1.1 added Console installs.  Setup a basic Console install
        ## when converting the project.

        ::NewInstall::AddConsoleInstall

        set info(ProjectVersion) "1.1.0.2"
    }

    if {[package vcompare $info(ProjectVersion) 1.1.0.3] < 0} {
        if {$conf(cmdline)} { return 1 }

        ## 1.1b3

        Status "Converting project to version 1.1b3..."
        update

        ## Walk through and find any Modify Widget actions on
        ## a License pane.  We need to check for their broken
        ## conditions and fix them.
        set str1 {[<%CurrentPane%> get UserMustAcceptLicense]}
        set str2 {<%Property UserMustAcceptLicense%>}
        set str3 {<%Property <%CurrentPane%> UserMustAcceptLicense%>}
        foreach id [itcl::find objects -class InstallComponent] {
            if {$info(Theme) eq "Modern_Wizard" && [$id is action]
                && [$id component] eq "ModifyWidget"
                && [[$id parent] ispane]
                && [[$id parent] component] eq "License"} {

                foreach cid [$id conditions] {
                    if {[$cid component] eq "StringIsCondition"} {
                        set str [$cid get String]
                        if {$str eq $str1 || $str eq $str2} {
                            $cid set String $str3
                            incr modified
                        }
                    }
                }
            }
        }

        set info(ProjectVersion) "1.1.0.3"
    }

    if {[package vcompare $info(ProjectVersion) 1.2.0.3] < 0} {
        ## The VFS format changed for the installkits in the final
        ## 1.2 release.  We need to require a full rebuild.

        incr modified

        set conf(fullBuildRequired) 1

        set info(ProjectVersion) "1.2.0.3"
    }

    if {[package vcompare $info(ProjectVersion) 1.2.5.1] < 0} {
        ## 1.2.5 added the ability to specify the Size of a file
        ## group, but InstallJammer already saves this attribute.
        ## The one saved is auto-generated, and the user never
        ## really sees it, so we want to get rid of it because they
        ## can now actually set it.
        ##
        ## Note that this doesn't actually require any action from
        ## the user, so we don't modify the state of the project.

        foreach id [itcl::find objects -class FileGroup] {
            unset -nocomplain Properties($id,Size)
        }

        set info(ProjectVersion) "1.2.5.1"
    }

    if {$modified && !$conf(cmdline)} {
        ::InstallJammer::BackupProjectFile "<%Project%>-<%ProjectVersion%>.mpi"
    }

    return $modified
}

if {[info commands ::_installComponentClass] eq ""} {
    rename ::InstallComponent ::_installComponentClass
    proc ::InstallComponent {id args} {
        array set _args $args
        unset -nocomplain _args(-command)
        eval ::_installComponentClass $id [array get _args]
    }
}
