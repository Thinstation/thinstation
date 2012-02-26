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

::itcl::class ::InstallJammer::ComponentDetails {
    inherit Object

    constructor { args } {
        eval configure $args

        standard ID         readonly   "ID"
        standard Active     boolean    "Active"  Yes
        standard Alias      shorttext  "Alias"
        standard Comment    text       "Comment"
        standard Data       text       "Data"
    }

    method initialize { id args } {
        variable ::InstallJammer::ComponentObjectMap
        set ComponentObjectMap($id) $this

        foreach {prop val} $args {
            $id set -safe $prop $val
        }

        foreach prop [properties] {
            $id set -safe $prop $propertyopts($prop,value)
        }

        foreach field [lsort $textfields] {
            $id set -safe $field,subst $propertyopts($field,subst)
        }
    }

    method get { prop field varName } {
        upvar 1 $varName var
        if {![info exists propertyopts($prop,$field)]} { return 0 }
        set var $propertyopts($prop,$field)
        return 1
    }

    method standard { prop args } {
        if {[lsearch -exact $standardprops $prop] < 0} {
            lappend standardprops $prop
        }
        eval [list property $prop] $args
    }

    method property { prop type pretty {value ""} {choices ""} } {
        if {[string equal $type "image"]} { image $prop }

        if {[lsearch -exact $properties $prop] < 0} { lappend properties $prop }
        set propertyopts($prop,type)    $type
        set propertyopts($prop,pretty)  $pretty
        set propertyopts($prop,value)   $value
        set propertyopts($prop,choices) $choices
        set propertyopts($prop,help)    ""
    }

    method text { field pretty subst } {
        lappend textfields $field
        set propertyopts($field,subst)  $subst
        set propertyopts($field,pretty) $pretty
    }

    method addproperties { prop id args } {
        array set _args {
            -array        ::InstallJammer::active
            -standard     1
            -advanced     1
            -parentnode   ""
            -properties   {}
            -standardnode standard
            -advancednode advanced
        }
        array set _args $args

        if {[llength $_args(-properties)]} {
            foreach property $_args(-properties) {
                set var  $_args(-array)($property)
                AddProperty $prop end $_args(-parentnode) $id $property $var \
                    -data    $property \
                    -help    $propertyopts($property,help)   \
                    -type    $propertyopts($property,type)   \
                    -pretty  $propertyopts($property,pretty) \
                    -choices $propertyopts($property,choices)
            }
            return
        }

        set standard [standardproperties]
        if {![string is boolean -strict $_args(-standard)]} {
            set standard $_args(-standard)
            set _args(-standard) 1
        }

        if {$_args(-standard)} {
            foreach property $standard {
                set var  $_args(-array)($property)
                AddProperty $prop end $_args(-standardnode) $id $property $var \
                    -data    $property \
                    -help    $propertyopts($property,help)   \
                    -type    $propertyopts($property,type)   \
                    -pretty  $propertyopts($property,pretty) \
                    -choices $propertyopts($property,choices)
            }
        }

        set advanced [properties 0]
        if {![string is boolean -strict $_args(-advanced)]} {
            set advanced $_args(-advanced)
            set _args(-advanced) 1
        }

        if {$_args(-advanced)} {
            if {[lempty $advanced]} { return }

            foreach property $advanced {
                set var  $_args(-array)($property)
                AddProperty $prop end $_args(-advancednode) $id $property $var \
                    -data    $property \
                    -help    $propertyopts($property,help)   \
                    -type    $propertyopts($property,type)   \
                    -pretty  $propertyopts($property,pretty) \
                    -choices $propertyopts($property,choices)
            }
        }
    }

    method addtextfields { prop node id {arrayName ::InstallJammer::active} } {
        set check $prop.editTextFieldSubst
        if {![winfo exists $check]} {
            # CHECKBUTTON $check -padx 0 -pady 0 -bd 0 -command Modified
            CHECKBUTTON $check -command Modified
            DynamicHelp::add $check \
                -text "Do virtual text substitution for this field"
        }

        foreach field [lsort $textfields] {
            set var    ${arrayName}($field)
            set subst  ${arrayName}($field,subst)
            set pretty $propertyopts($field,pretty)

            set start  ::InstallJammer::EditTextFieldNode
            set end    ::InstallJammer::FinishEditTextFieldNode
            set etitle "Edit $pretty"
            $prop insert end $node #auto -text $pretty -variable $var \
                -browsebutton 1 -browseargs [list -style Toolbutton] \
                -browsecommand [list EditTextField $id $field $etitle $var] \
                -editstartcommand  [list $start $prop $id $field $var $subst] \
                -editfinishcommand [list $end $prop $id $field $var $subst]
        }
    }

    method image { image } {
        lappend images $image
    }

    method help { prop {text ""} } {
        if {$text ne ""} {
            set propertyopts($prop,help) $text
        }
        return $propertyopts($prop,help)
    }

    method condition { which cond arguments } {
        lappend conditions($which) [list $cond $arguments]
    }

    method properties { {includeStandard 1} } {
        if {$includeStandard} {
            return [lsort $properties]
        } else {
            set props [list]
            foreach prop [eval lremove [list $properties] $standardprops] {
                if {![string equal $propertyopts($prop,type) "hidden"]} {
                    lappend props $prop
                }
            }
            return [lsort $props]
        }
    }

    method type { property } {
        return $propertyopts($property,type)
    }

    method default { property } {
        return $propertyopts($property,value)
    }

    method pretty { property } {
        return $propertyopts($property,pretty)
    }

    method choices { property } {
        return $propertyopts($property,choices)
    }

    method standardproperties {} {
        set list [list ID]
        if {[lsearch -exact $standardprops Component] > -1} {
            lappend list Component
        }
        return [concat $list [lsort [eval lremove [list $standardprops] $list]]]
    }

    method textfields {} {
        return $textfields
    }

    method images {} {
        return $images
    }

    method conditions { which } {
        if {[info exists conditions($which)]} { return $conditions($which) }
    }

    method component {} {
        return "ClassObject"
    }

    method name   { args } { eval cfgvar name   $args }
    method order  { args } { eval cfgvar order  $args }
    method title  { args } { eval cfgvar title  $args }
    method parent { args } { eval cfgvar parent $args }

    public variable order  0
    public variable title  ""
    public variable parent ""

    public  variable help
    public  variable name          ""
    private variable images        [list]
    public  variable properties    [list]
    private variable textfields    [list]
    public  variable standardprops [list]

    private variable conditions
    public  variable propertyopts
}

::itcl::class ::InstallJammer::Action {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        set ::InstallJammer::components($name) [namespace tail $this]

        set ::InstallJammer::actions($name) [namespace tail $this]
        lappend ::InstallJammer::actiongroups($group) [namespace tail $this]

        standard Component      readonly   "Component"
        standard Conditions     conditions "Conditions"
        standard Include        choice     "Include"       "Always include" \
            $::InstallJammer::PropertyMap(Include)
        standard IgnoreErrors   boolean    "Ignore Errors" "No"
        standard ExecuteAction  choice     "Execute Action" \
            "After Pane is Displayed" \
            $::InstallJammer::PropertyMap(ExecuteAction)
    }

    destructor {
        unset -nocomplain ::InstallJammer::actions($name)
    }

    method includes { args } {
        if {[llength $args]} { return [eval lappend includes $args] }
        
        variable ::InstallJammer::components

        set list $includes
        foreach include $list {
            eval lappend list [$components($include) includes]
        }

        return $list
    }

    method requires { args } {
        if {[llength $args]} { return [eval lappend requires $args] }

        variable ::InstallJammer::components

        set list $requires
        foreach include [includes] {
            eval lappend list [$components($include) requires]
        }

        return $list
    }

    method group { args } {
        variable ::InstallJammer::actiongroups

        if {[llength $args]} {
            set groupName [lindex $args 0]
            set tail [namespace tail $this]

            set actiongroups($group) [lremove $actiongroups($group) $tail]

            set group $groupName
            lappend actiongroups($group) $tail
        }

        return $group
    }

    method action { args } { eval cfgvar name $args }

    public variable group    ""
    public variable includes [list]
    public variable requires [list]
}

::itcl::class ::InstallJammer::Pane {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args
        set ::InstallJammer::panes($name) [namespace tail $this]

        standard Component  readonly   "Component"
        standard Conditions conditions "Conditions"
        standard Include    choice     "Include"    "Always include" \
            $::InstallJammer::PropertyMap(Include)
    }

    destructor {
        unset -nocomplain ::InstallJammer::panes($name)
    }

    method includes { args } {
        if {[llength $args]} { return [eval lappend includes $args] }
        
        variable ::InstallJammer::panes

        set list $includes
        foreach include $list {
            eval lappend list [$panes($include) includes]
        }

        return $list
    }

    method action { action arguments } {
        lappend actions [list $action $arguments]
    }

    method file { file } {
        lappend files $file
    }

    method actions {} {
        return $actions
    }

    method installtypes {} {
        return $installtypes
    }

    method directories {} {
        global conf
        global info
        global preferences

        lappend dirs [InstallDir Theme/$setup]
        if {[string length $preferences(CustomThemeDir)]} {
            set custom $preferences(CustomThemeDir)
            lappend dirs [::file join $custom $info(Theme) $setup]
        }
        lappend dirs [::file join $conf(pwd) Themes $info(Theme) $setup]
    }

    method deffile { args } {
        if {[llength $args]} { return [eval cfgvar deffile $args] }
        foreach dir [directories] {
            set file [::file join $dir $name.pane]
            if {[::file exists $file]} { return $file }
        }
        return $deffile
    }

    method tclfile { args } {
        if {[llength $args]} { return [eval cfgvar tclfile $args] }
        foreach dir [directories] {
            set file [::file join $dir $name.tcl]
            if {[::file exists $file]} { return $file }
        }
        return $tclfile
    }

    method pane    { args } { eval cfgvar name    $args }
    method setup   { args } { eval cfgvar setup   $args }

    public variable setup        ""
    public variable preview      0
    public variable deffile      ""
    public variable tclfile      ""
    public variable includes     [list]
    public variable installtypes [list Standard]

    private variable files   [list]
    private variable actions [list]
    private variable widgets [list]
}

::itcl::class ::InstallJammer::ActionGroup {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        standard Conditions conditions "Conditions"
    }
}

::itcl::class ::InstallJammer::FileGroup {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        standard Name              text   "Name"
        standard Size              text   "Size"
        standard CompressionMethod choice "Compression Method" "" \
            [concat {{}} $::conf(CompressionMethods)]
        standard Destination       installedfile "Destination Directory"
        standard DisplayName short "Display Name"
        standard FileUpdateMethod  filemethod "File Update Method" \
            "Update files with more recent dates"
        standard FollowDirLinks boolean "Follow Directory Links" "Yes"
        help FollowDirLinks "If this property is true, links to\
            directories will be followed and their contents stored in the\
            installer as normal files.  If this is false, the directory will\
            be stored as a symlink to be recreated on the target system"
        standard FollowFileLinks   boolean "Follow File Links" "No"
        help FollowFileLinks "If this property is true, links to files will\
            be followed, and the linked file will be stored as an actual file\
            within the installer.  If it is false, a link will be stored and\
            recreated as a link on the target system"
        standard Version           version "Version"
        standard SaveFiles         nullboolean "Save Files" ""
        help SaveFiles "Setting this property to Yes or No overrides the\
            default Save Only Toplevel Directories project preference.  If\
            the property is false, no files or subdirectories of any directory\
            in the file group will be saved in the project file.  Only\
            directories which are toplevel directories in the file group\
            will be saved"

        standard FileSize          hidden "File Size"
        standard Attributes        hidden "Windows File Attributes"
        standard Permissions       hidden "File Permissions"
    }
}

::itcl::class ::InstallJammer::Component {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        standard Name              text    "Name"
        standard Size              text    "Size"
        standard Checked           boolean "Checked"            "Yes"
        standard FileGroups        hidden  "File Groups"
        standard Selectable        boolean "Selectable"         "Yes"
        standard ShowComponent     boolean "Show Component"     "Yes"
        standard ComponentGroup    text    "Component Group"
        standard RequiredComponent boolean "Required Component" "No"

        text Description "Description"  1
        text DisplayName "Display Name" 1
    }
}

::itcl::class ::InstallJammer::SetupType {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        standard Name          text    "Name"
        standard Components    hidden  "Components"
        standard ShowSetupType boolean "Show Setup Type"     "Yes"

        text Description "Description"  1
        text DisplayName "Display Name" 1
    }
}

::itcl::class ::InstallJammer::File {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        standard CompressionMethod choice "Compression Method" "" \
            [concat {{}} $::conf(CompressionMethods)]
        standard Destination       installedfile "Destination Directory"
        standard FileUpdateMethod  filemethod "File Update Method" \
            "Update files with more recent dates"
        standard Version           version "Version"
        standard Location          location "Location"
        standard TargetFilename    short "Target Filename"
        standard SaveFiles         nullboolean "Save Files"
        help SaveFiles "Setting this property to Yes or No overrides the\
            default Save Only Toplevel Directories project preference.  If\
            the property is false, no files or subdirectories of any directory\
            in the file group will be saved in the project file.  Only\
            directories which are toplevel directories in the file group\
            will be saved"
    }
}

::itcl::class ::InstallJammer::Condition {
    inherit ::InstallJammer::ComponentDetails

    constructor { args } {
        eval configure $args

        standard Component      readonly  "Component"
        standard CheckCondition choice    "Check Condition" \
            "Before Pane is Displayed" $::conf(PaneCheckConditions)

        standard FailureFocus   text "Failure Focus"
        help FailureFocus "A widget to move the focus to after the failure\
                                message has been displayed."

        standard FailureMessage text "Failure Message"
        help FailureMessage "A message to display to the user if this conditon\
                                fails."

        standard Include choice "Include" "Always include" \
            $::InstallJammer::PropertyMap(Include)

        set ::InstallJammer::components($name) [namespace tail $this]

        set ::InstallJammer::conditions($name) [namespace tail $this]
        lappend ::InstallJammer::conditiongroups($group) [namespace tail $this]
    }

    destructor {
        unset -nocomplain ::InstallJammer::conditions($name)
    }

    method group { args } {
        variable ::InstallJammer::conditiongroups

        if {[llength $args]} {
            set groupName [lindex $args 0]
            set tail [namespace tail $this]

            set conditiongroups($group) [lremove $conditiongroups($group) $tail]

            set group $groupName
            lappend conditiongroups($group) $tail
        }

        return $group
    }

    method includes { args } {
        if {[llength $args]} { return [eval lappend includes $args] }
        
        variable ::InstallJammer::components

        set list $includes
        foreach include $list {
            eval lappend list [$components($include) includes]
        }

        return $list
    }

    method condition { args } { eval cfgvar name $args }

    public variable group     ""
    public variable includes  [list]
}

::itcl::class Platform {
    inherit InstallComponent

    constructor { args } {
        eval configure $args
    } {
        eval configure $args
        ::set type platform

        set Active                "NEW"
        set BuildSeparateArchives "No"
        set InstallMode           "Standard"
        set InstallType           "Typical"
        set ProgramName           ""
        set ProgramReadme         "<%InstallDir%>/README.txt"
        set ProgramLicense        "<%InstallDir%>/LICENSE.txt"
        set ProgramFolderName     "<%AppName%>"
        set ProgramExecutable     ""
        set ProgramFolderAllUsers "No"

        if {$name eq "windows"} {
            set Executable   "<%AppName%>-<%Version%>-Setup<%Ext%>"
            set FileDescription "<%AppName%> <%Version%> Setup"
            set InstallDir   "<%PROGRAM_FILES%>/<%AppName%>"
            set WindowsIcon  "Setup Blue Screen.ico"
            set IncludeTWAPI "No"
            set RequireAdministrator "Yes"
            set UseUncompressedBinaries "No"
            set LastRequireAdministrator "Yes"
        } else {
            set Executable "<%AppName%>-<%Version%>-<%Platform%>-Install<%Ext%>"
            set InstallDir "<%Home%>/<%ShortAppName%>"

            set PromptForRoot  "Yes"

            set RequireRoot    "No"
            set RootInstallDir "/usr/local/<%ShortAppName%>"

            set DefaultFilePermission      "0755"
            set DefaultDirectoryPermission "0755"

            set FallBackToConsole "Yes"
        }
    }

    method initialize {} {}

    method object {} {
        return ::PlatformObject
    }
} ; ## ::itcl::class Platform
