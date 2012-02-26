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

proc Help {args} {
    global conf
    global preferences

    ## If we weren't passed a subject, try to get the subject for the current
    ## window.
    if {[lempty $args]} {
	set tab ""
	if {[info exists conf(tab)]} { set tab $conf(tab) }
    	set subject [HelpForWindow $conf(window) $tab]
    } elseif {[llength $args] == 1} {
	set subject $args
    } elseif {[llength $args] == 2} {
	lassign $args window tab
	set subject [HelpForWindow $window $tab]
    }

    if {![ShowHelp $subject]} { return }

    if {[info exists conf(helpIndex)]} {
	set end [expr [llength $conf(links)] - 1]
	## They've backed up somewhere.
	if {$conf(helpIndex) != $end} {
	    set conf(links) \
	    	[lreplace $conf(links) [expr $conf(helpIndex)+1] $end $subject]
	} else {
	    lappend conf(links) $subject
	}
    } else {
	lappend conf(links) $subject
    }
    set conf(helpIndex) [expr [llength $conf(links)] - 1]

    ## Configure the states of the back and next buttons.
    SetBackButton
    SetNextButton
}

proc SetHelp {window args} {
    global help

    if {[llength $args] == 2} {
	lassign $args tab subject
	set help($window,$tab) $subject
    } else {
	set subject [lindex $args 0]
	set help($window) $subject
    }
}

proc HelpForWindow {window {tab ""}} {
    global help
    set var $window
    if {![lempty $tab]} { append var ,$tab }
    if {![info exists help($var)]} { return $var }
    return $help($var)
}

proc ShowHelp {subject} {
    global conf
    global preferences

    set browser $preferences(HelpBrowser)

    if {$conf(windows) && $browser eq "Windows Help"} {
        ::InstallJammer::LaunchWindowsHelp $subject
        return 1
    }

    set file [file join $conf(help) html index.html]

    if {[::InstallJammer::LocalHelpExists]} {
        if {![file exists $file] || [file size $file] == 0} {
            ::InstallJammer::Error -title "No Help Available" \
                -message "There is no help for $subject"
            return 0
        }
    }

    if {$browser eq "Internal Browser"} {
	Window show [::InstallJammer::TopName .help] $file
    } else {
	Status "Launching External Help Browser..." 3000
        #set tail "?href=${subject}.html"
        #set url "file://$file$tail"

        set file [file join $conf(help) html $subject.html]
        set url  "file://$file"
        set tail ""
        if {![::InstallJammer::LocalHelpExists]} {
            set url [file join $conf(HelpURL) [file tail $file]$tail]
        }

	::InstallJammer::LaunchBrowser $url
    }

    return 1
}

proc Window.installjammer.help { file } {
    global conf
    global widg

    set top [::InstallJammer::TopName .help]

    if {[winfo exists $top]} {
	ParseHelpFile $file
	wm deiconify $top
	return
    }

    toplevel     $top
    wm withdraw  $top
    wm protocol  $top WM_DELETE_WINDOW "destroy $top"
    wm transient $top $widg(InstallJammer)
    wm title     $top "InstallJammer Help"
    ::InstallJammer::CenterWindow $top 500 400

    frame $top.top

    WinButton $top.top.back -image [GetImage navback22] \
    	-command "BackLink" -state disabled
    WinButton $top.top.next -image [GetImage navforward22] \
    	-command "NextLink" -state disabled
    WinButton $top.top.refresh -image [GetImage actreload22] \
    	-command "Reload $file"
    WinButton $top.top.home -image [GetImage navhome22] \
    	-command "Help index"
    WinButton $top.top.close -image [GetImage actexit22] \
    	-command "destroy $top"

    DynamicHelp::register $top.top.back balloon "Go back one page"
    DynamicHelp::register $top.top.next balloon "Go forward one page"
    DynamicHelp::register $top.top.refresh balloon "Refresh page"
    DynamicHelp::register $top.top.home balloon "Go to help index"
    DynamicHelp::register $top.top.close balloon "Close"

    ScrolledWindow $top.sw
    set html $top.sw.html
    html $html -width 500 -height 400 -bg #FFFFFF -base $conf(help)/trash \
    	-imagecommand AddHelpImage
    $top.sw setwidget $top.sw.html

    pack $top.top -fill x
    pack [frame $top.top.sp1 -width 5] -side left
    pack $top.top.back -side left
    pack [frame $top.top.sp2 -width 3] -side left
    pack $top.top.next -side left
    pack [frame $top.top.sp3 -width 5] -side left
    pack $top.top.refresh -side left
    pack $top.top.home -side left
    pack $top.top.close -side right

    pack $top.sw -fill both -expand 1

    bind $top <Up>    "$html yview scroll -1 units"
    bind $top <Down>  "$html yview scroll  1 units"
    bind $top <Left>  "$html xview scroll -1 units"
    bind $top <Right> "$html xview scroll  1 units"
    bind $top <Prior> "$html yview scroll -1 pages"
    bind $top <Next>  "$html yview scroll  1 pages"
    bind $top <Home>  "$html yview moveto 0"
    bind $top <End>   "$html yview moveto 1"

    bind $html <Button-1> "VisitLink %x %y"
    bind $html <Motion> {
	if {[lempty [%W href %x %y]]} {
	    %W configure -cursor {}
	    break
	}
    	%W configure -cursor hand1
    }

    BindMouseWheel $top.sw.html

    ParseHelpFile $file

    wm deiconify $top
}

proc ParseHelpFile {file} {
    set top [::InstallJammer::TopName .help]
    set html $top.sw.html
    #$html clear
    #$html parse [ReadHelpData [file join $::conf(help) header.html]]
    $html parse [ReadHelpData $file]
    SetHelpTitle
    $top.top.refresh configure -command "Reload [list $file]"
    update
}

proc ReadHelpData {file} {
    return [subst [read_file $file]]
}

proc VisitLink {x y} {
    global conf

    set top [::InstallJammer::TopName .help]

    set file [lindex [$top.sw.html href $x $y] 0]

    if {[lempty $file]} { return }
    set subject [file root [file tail $file]]
    Help $subject
}

proc SetBackButton {} {
    global conf
    if {![info exists conf(helpIndex)]} { return }

    set top [::InstallJammer::TopName .help]
    set b   $top.top.back

    if {![winfo exists $b]} { return }
    if {$conf(helpIndex) > 0} {
	$b configure -state normal
    } else {
	$b configure -state disabled
    }
}

proc BackLink {} {
    global conf

    incr conf(helpIndex) -1
    ShowHelp [lindex $conf(links) $conf(helpIndex)]

    ## Configure the states of the back and next buttons.
    SetBackButton
    SetNextButton
}

proc SetNextButton {} {
    global conf
    if {![info exists conf(helpIndex)]} { return }

    set top [::InstallJammer::TopName .help]
    set b   $top.top.next

    if {![winfo exists $b]} { return }
    set end [expr [llength $conf(links)] -1 ]

    if {$conf(helpIndex) < $end} {
	$b configure -state normal
    } else {
	$b configure -state disabled
    }
}

proc NextLink {} {
    global conf

    incr conf(helpIndex)
    ShowHelp [lindex $conf(links) $conf(helpIndex)]

    ## Configure the states of the back and next buttons.
    SetBackButton
    SetNextButton
}

proc Reload { file } {
    set top [::InstallJammer::TopName .help]
    set html $top.sw.html
    set y [lindex [$html yview] 0]
    Window show $top $file
    update idletasks
    $html yview moveto $y
}

proc HelpLink {subject text} {
    return "<A HREF=\"$subject.html\">$text</A>"
}

proc Include {subject} {
    set top [::InstallJammer::TopName .help]
    return [ReadHelpData [file join $::conf(help) html $subject.html]]
}

proc SetHelpTitle {} {
    global conf

    return

    set top  [::InstallJammer::TopName .help]
    set html $top.sw.html
    set a [lindex [$html token find title] 0]
    if {[lempty $a]} { return }
    set b [$html token getend $a]

    if {$a && $b} {
	set title [string trim [$html text ascii $a $b]]
    	wm title $top $title
    }
}

proc AddHelpImage {src width height args} {
    global conf

    set file $src
    if {[file pathtype $src] == "relative"} {
	set file [file join $conf(help) html $src]
    }
    return [image create photo [NewNode] -file $file]
}

proc ::InstallJammer::HelpBrowsers {} {
    global conf

    set browsers [list]
    if {[string equal $::tcl_platform(platform) "windows"]} {
        if {[file exists [file join $conf(help) installjammer.chm]]} {
            lappend browsers "Windows Help"
        }
        lappend list {C:\Program Files\Mozilla Firefox\firefox.exe}
        lappend list {C:\Program Files\Opera\opera.exe}
	lappend list {C:\Program Files\mozilla.org\Mozilla\mozilla.exe}
	lappend list {C:\Program Files\Internet Explorer\iexplore.exe}
	foreach browser $list {
	    if {[file exists $browser]
    		&& [lsearch -exact $browsers $browser] < 0} {
		lappend browsers $browser
	    }
	}
    } else {
	if {[info exists ::env(HELP_BROWSER)]} {
	    lappend browsers $::env(HELP_BROWSER)
	}

	if {[info exists ::env(BROWSER)]
	    && [lsearch -exact $browsers $::env(BROWSER)] < 0} {
	    lappend browsers $::env(BROWSER)
	}

	set list [list]
    	switch -- [::InstallJammer::GetDesktopEnvironment] {
	    "KDE" {
		lappend list konqueror
	    }

	    "Gnome" {
		lappend list galeon
	    }
	}
	lappend list firefox konqueror mozilla opera galeon

	foreach browser $list {
	    set path [auto_execok $browser]
	    if {[string length $path]
    		&& [lsearch -exact $browsers $path] < 0} {
		lappend browsers $path
	    }
	}
    }

    return $browsers
}

proc ::InstallJammer::AboutInstallJammer {} {
    global conf
    global widg

    set top [::InstallJammer::TopName .about]

    ::Dialog $top -title "About InstallJammer" -spacing 0 \
        -parent $widg(InstallJammer) -default 0

    $top add -text "OK" -width 12 -default active

    text $top.text -width 45 -height 8 -relief flat \
        -background [$top cget -background]
    pack $top.text -expand 1 -fill both

    $top.text tag configure center -justify center
    $top.text tag configure bold -font TkCaptionFont

    $top.text tag configure link -foreground blue -underline 1
    $top.text tag bind link <Enter> [list %W configure -cursor hand2]
    $top.text tag bind link <Leave> [list %W configure -cursor ""]
    $top.text tag bind link <1> {
        ::InstallJammer::LaunchBrowser http://www.installjammer.com/
    }

    $top.text tag configure email -foreground blue -underline 1
    $top.text tag bind email <Enter> [list %W configure -cursor hand2]
    $top.text tag bind email <Leave> [list %W configure -cursor ""]
    $top.text tag bind email <1> {
        exec $::env(COMSPEC) /c start mailto:damon@installjammer.com
    }

    $top.text insert end "InstallJammer Multiplatform Installer\n" bold
    $top.text insert end "http://www.installjammer.com/" link "\n\n"
    $top.text insert end "by Damon Courtney\n<"
    $top.text insert end "damon@installjammer.com" email ">\n\n"
    $top.text insert end "Version $conf(Version) "
    $top.text insert end "(Build $conf(BuildVersion))"

    $top.text tag add center 1.0 end
    $top.text configure -state disabled

    $top draw

    destroy $top
}

proc ::InstallJammer::LaunchWindowsHelp { subject } {
    global conf
    Status "Launching Windows Help..." 3000
    set help [file join $conf(help) InstallJammer.chm]
    exec $::env(COMSPEC) /c start /B hh ${help}::/$subject.html &
}

proc ::InstallJammer::LaunchBrowser { url } {
    global conf
    global preferences

    Status "Launching External Web Browser..." 3000

    set browser $preferences(HelpBrowser)

    if {$browser eq "" || $browser eq "Windows Help"} {
	if {$conf(windows)} {
            if {[string match "file://*" $url]} {
                set url [string range $url 7 end]
                set url file://[file attributes $url -short]
            }
            exec [file normalize $::env(COMSPEC)] /c start $url &
            return
        } elseif {$conf(osx)} {
            set browser open
        } else {
	    set browser xdg-open
        }
    }

    exec $browser $url &
}

proc ::InstallJammer::LocalHelpExists {} {
    global conf
    if {[file exists [file join $conf(help) html]]} { return 1 }
    if {[file exists [file join $conf(help) installjammer.chm]]} { return 1 }
    return 0
}

proc ::InstallJammer::SetHelp { topic } {
    global conf

    switch -- $topic {
        "<default>" {
            set conf(LastHelpTopic) $conf(HelpTopic)
            set conf(HelpTopic) $conf(DefaultHelpTopic)
        }

        "<last>" {
            set conf(HelpTopic) $conf(LastHelpTopic)
        }

        default {
            set conf(LastHelpTopic) $conf(HelpTopic)
            set conf(HelpTopic) $topic
        }
    }
}

proc ::InstallJammer::DownloadVersionInfo { {popup 0} } {
    global conf

    package require http

    set url "$conf(HomePage)/installjammer.info"

    http::config -proxyhost "" -proxyport ""
    if {[GetPref UseProxyServer]} {
        set host [GetPref ProxyHost]
        set port [GetPref ProxyPort]
        http::config -proxyhost $host -proxyport $port
    }

    set command [list ::InstallJammer::ParseVersionInfo $popup]

    if {[catch { ::http::geturl $url -command $command }] && $popup} {
        ::InstallJammer::MessageBox -title "No New Version" -message \
            "No new version of InstallJammer is available at this time."
    }
}

proc ::InstallJammer::ParseVersionInfo { popup token } {
    global conf

    variable versionInfo

    if {[::http::status $token] eq "ok"} {
        set data [::http::data $token]
        ::InstallJammer::ReadProperties $data versionInfo
    }

    ::http::cleanup $token

    set ver $conf(InstallJammerVersion)
    if {[info exists versionInfo(Version)]
        && [package vcompare $ver $versionInfo(Version)] < 0} {
        set ans [::InstallJammer::MessageBox -type yesno \
            -title "New Version Available" -message "There is a new version\
                of InstallJammer available.\nWould you like to download and\
                install it?"]

        if {$ans eq "yes"} {
            ::InstallJammer::DownloadNewVersion
        }
    } elseif {$popup} {
        ::InstallJammer::MessageBox -title "No New Version" -message \
            "No new version of InstallJammer is available at this time."
    }
}

proc ::InstallJammer::DownloadNewVersion {} {

}
